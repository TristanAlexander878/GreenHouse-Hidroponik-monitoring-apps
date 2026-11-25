import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Dilempar kalau kuota diagnosa user masih terkunci (cooldown belum lewat).
class DiagnosisQuotaExceededException implements Exception {
  final String message;

  const DiagnosisQuotaExceededException(this.message);

  @override
  String toString() => message;
}

/// Dilempar kalau pengecekan kuota gagal karena masalah infrastruktur
/// (Firebase belum siap, auth gagal, dsb). Pesannya sudah ramah untuk UI.
class DiagnosisQuotaException implements Exception {
  final String message;

  const DiagnosisQuotaException(this.message);

  @override
  String toString() => message;
}

/// Pembatas (rate limit) jumlah diagnosa per user.
///
/// Alur:
/// 1. Ambil kebijakan dari Firebase Remote Config key `diagnosis_limit_policy`
///    (JSON, mis. `{"cooldown_days": 7}`).
/// 2. Baca Firestore `user_usage/{userId}.last_diagnosis_date`.
/// 3. Kalau selisih hari dari sekarang belum melewati `cooldown_days`, tolak.
/// 4. Kalau lolos, setelah diagnosa sukses panggil [lock] untuk mengisi
///    `last_diagnosis_date` dengan `FieldValue.serverTimestamp()`.
class DiagnosisQuotaService {
  static const String policyKey = 'diagnosis_limit_policy';
  static const int defaultCooldownDays = 7;

  static const String _collection = 'user_usage';
  static const String _lastDiagnosisField = 'last_diagnosis_date';

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseRemoteConfig? _remoteConfigOverride;
  final String? _userIdOverride;

  String? _cachedUserId;

  DiagnosisQuotaService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseRemoteConfig? remoteConfig,
    String? userId,
  }) : _authOverride = auth,
       _firestoreOverride = firestore,
       _remoteConfigOverride = remoteConfig,
       _userIdOverride = userId;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  /// userId user saat ini. Login anonim otomatis kalau belum ada sesi.
  Future<String> _resolveUserId() async {
    final override = _userIdOverride?.trim();
    if (override != null && override.isNotEmpty) return override;
    if (_cachedUserId != null) return _cachedUserId!;

    try {
      final current = _auth.currentUser;
      if (current != null) return _cachedUserId = current.uid;

      final credential = await _auth.signInAnonymously();
      final user = credential.user;
      if (user == null) {
        throw const DiagnosisQuotaException(
          'Tidak bisa memulai sesi pengguna. Coba lagi.',
        );
      }
      return _cachedUserId = user.uid;
    } on DiagnosisQuotaException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      _log('auth gagal: ${error.code} ${error.message}');
      throw const DiagnosisQuotaException(
        'Gagal memverifikasi sesi pengguna. Pastikan login anonim aktif '
        'di Firebase Authentication.',
      );
    } catch (error) {
      _log('auth error: $error');
      throw const DiagnosisQuotaException(
        'Gagal menghubungi layanan pengguna. Cek koneksi internet.',
      );
    }
  }

  /// Ambil `cooldown_days` dari Remote Config. Selalu fallback ke default.
  Future<int> _resolveCooldownDays() async {
    try {
      final remoteConfig =
          _remoteConfigOverride ?? FirebaseRemoteConfig.instance;
      await remoteConfig.setDefaults({
        policyKey: jsonEncode({'cooldown_days': defaultCooldownDays}),
      });
      await remoteConfig.fetchAndActivate();

      final raw = remoteConfig.getString(policyKey);
      if (raw.trim().isEmpty) return defaultCooldownDays;

      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['cooldown_days'] is num) {
        final days = (decoded['cooldown_days'] as num).toInt();
        return days > 0 ? days : defaultCooldownDays;
      }
      _log('policy tidak memuat cooldown_days, pakai default');
    } catch (error) {
      _log('Remote Config gagal, pakai cooldown default: $error');
    }
    return defaultCooldownDays;
  }

  /// Cek kuota. Kalau masih terkunci, lempar [DiagnosisQuotaExceededException].
  /// Kembalikan jumlah hari cooldown kalau user boleh diagnosa.
  Future<int> enforce({DateTime? now}) async {
    final userId = await _resolveUserId();
    final cooldownDays = await _resolveCooldownDays();

    late final DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await _firestore.collection(_collection).doc(userId).get();
    } catch (error) {
      _log('baca user_usage gagal: $error');
      throw const DiagnosisQuotaException(
        'Gagal memeriksa kuota diagnosa. Cek koneksi internet lalu coba lagi.',
      );
    }

    final last = doc.data()?[_lastDiagnosisField];
    if (last is Timestamp) {
      final reference = now ?? DateTime.now();
      final elapsedDays = reference.difference(last.toDate()).inDays;
      if (elapsedDays < cooldownDays) {
        final remaining = cooldownDays - elapsedDays;
        throw DiagnosisQuotaExceededException(
          'Kuota diagnosa minggu ini sudah habis. '
          'Coba lagi dalam $remaining hari.',
        );
      }
    }

    return cooldownDays;
  }

  /// Kunci kuota setelah diagnosa sukses.
  Future<void> lock() async {
    final userId = await _resolveUserId();
    try {
      await _firestore.collection(_collection).doc(userId).set({
        _lastDiagnosisField: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      _log('update user_usage gagal: $error');
      throw const DiagnosisQuotaException(
        'Hasil diagnosa didapat, tapi gagal menyimpan kuota. '
        'Cek koneksi internet.',
      );
    }
  }

  void _log(String message) {
    developer.log(message, name: 'DiagnosisQuota');
  }
}
