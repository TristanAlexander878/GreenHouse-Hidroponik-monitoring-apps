import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

import '../firebase_options.dart';
import '../models/sensor_reading.dart';
import 'connection_status.dart';
import 'sensor_service.dart';

/// Baca data sensor live dari Firebase Realtime Database (node `hydroponik`).
///
/// Skema database (nilai bacaan bisa langsung di bawah node, atau
/// dikelompokkan per device):
/// ```
/// hydroponik/
///   <device>/
///     ph            (number)
///     tds           (number, ppm)  -- estimasi padatan terlarut
///     temperature   (number)
/// ```
///
/// Kolom `ec` (mS/cm) lama masih dibaca sebagai cadangan dan dikonversi
/// ke TDS ppm (lihat [SensorReading.tryParse]).
class FirebaseSensorService implements SensorService {
  FirebaseSensorService({DatabaseReference? databaseRef})
    : _injectedRef = databaseRef;

  static const String _fallbackUrl =
      'https://green-house-application-demo-2-default-rtdb'
      '.asia-southeast1.firebasedatabase.app';

  static const int _maxHistory = 60;
  static const Duration _retryDelay = Duration(seconds: 5);

  final DatabaseReference? _injectedRef;
  final List<SensorReading> _history = [];

  DatabaseReference? _resolvedRef;
  bool _refFailed = false;

  StreamController<SensorReading?>? _controller;
  StreamSubscription<DatabaseEvent>? _subscription;
  Timer? _retryTimer;

  SensorReading? _latest;
  bool _hasLatest = false;

  @override
  Stream<SensorReading?> get readingsStream {
    _controller ??= StreamController<SensorReading?>.broadcast();
    _ensureListening();

    // Firebase bisa mengirim nilai pertama sebelum StreamBuilder sempat
    // subscribe. Karena controller-nya broadcast, event itu hilang. Replay
    // nilai terakhir ke setiap listener baru supaya data langsung tampil
    // tanpa harus refresh manual.
    return Stream<SensorReading?>.multi((multi) {
      if (_hasLatest) multi.add(_latest);
      final sub = _controller!.stream.listen(
        multi.add,
        onError: multi.addError,
        onDone: multi.close,
      );
      multi.onCancel = sub.cancel;
    });
  }

  @override
  Stream<List<SensorReading>> get historyStream =>
      readingsStream.map((_) => List<SensorReading>.unmodifiable(_history));

  @override
  Future<void> refresh() async {
    await _cancelSubscription();
    _ensureListening();
  }

  Future<void> dispose() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    await _cancelSubscription();
    await _controller?.close();
    _controller = null;
  }

  /// Resolve reference-nya ditunda biar app tetap jalan walau
  /// `Firebase.initializeApp` gagal (mis. platform belum didukung).
  DatabaseReference? _resolveRef() {
    if (_resolvedRef != null) return _resolvedRef;
    if (_injectedRef != null) return _resolvedRef = _injectedRef;

    try {
      final url =
          DefaultFirebaseOptions.currentPlatform.databaseURL ?? _fallbackUrl;
      _resolvedRef = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: url,
      ).ref('hydroponik');
    } catch (error) {
      _refFailed = true;
      ConnectionStatus.disconnected(
        'Firebase belum terkonfigurasi di platform ini: $error',
      );
      return null;
    }
    return _resolvedRef;
  }

  void _ensureListening() {
    if (_subscription != null) return;

    final ref = _resolveRef();
    if (ref == null) {
      if (_refFailed) _scheduleRetry();
      return;
    }

    _log('subscribe ke node hydroponik');
    _subscription = ref.onValue.listen(
      _onEvent,
      onError: _onError,
      onDone: _onDone,
    );
  }

  void _onDone() {
    _log('stream done, jadwal retry');
    // Stream dari platform selesai tanpa error (mis. saat app di-background).
    // Bikin subscription null biar bisa disambung ulang otomatis.
    _subscription = null;
    ConnectionStatus.disconnected(
      'Koneksi data terputus, menyambung ulang ke database...',
    );
    _scheduleRetry();
  }

  Future<void> _cancelSubscription() async {
    final sub = _subscription;
    _subscription = null;
    if (sub != null) {
      try {
        await sub.cancel();
      } catch (_) {
        // Listener sudah mati, aman diabaikan.
      }
    }
  }

  void _onEvent(DatabaseEvent event) {
    _log('event masuk: ${event.snapshot.value}');
    final reading = SensorReading.tryParse(event.snapshot.value);

    if (reading == null) {
      _latest = null;
      _hasLatest = true;
      ConnectionStatus.disconnected(
        'Node hydroponik belum berisi data. Pastikan device sudah mengirim '
        'data ke database.',
      );
      _controller?.add(null);
      return;
    }

    _latest = reading;
    _hasLatest = true;
    _history.add(reading);
    if (_history.length > _maxHistory) {
      _history.removeAt(0);
    }

    ConnectionStatus.connected();
    _controller?.add(reading);
  }

  void _onError(Object error, StackTrace stackTrace) {
    _log('error: $error');
    ConnectionStatus.disconnected(_messageFor(error));

    final controller = _controller;
    if (controller != null && !controller.isClosed) {
      controller.addError(error, stackTrace);
    }

    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_retryTimer != null) return;
    _retryTimer = Timer(_retryDelay, () {
      _retryTimer = null;
      _retryNow();
    });
  }

  Future<void> _retryNow() async {
    await _cancelSubscription();
    _ensureListening();
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[SensorService] $message');
  }

  String _messageFor(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Akses database ditolak. Cek aturan keamanan Realtime '
              'Database.';
        case 'network-error':
          return 'Jaringan bermasalah, gagal menghubungi database.';
        case 'client-unauthorized':
        case 'unauthorized':
          return 'Kredensial Firebase tidak valid di perangkat ini.';
        case 'disconnected':
          return 'Koneksi ke database terputus.';
        default:
          return 'Gagal membaca database: ${error.message ?? error.code}';
      }
    }
    return 'Gagal menghubungi database: $error';
  }

}
