import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/diagnosis_result.dart';
import '../secrets.dart';

/// Kontrak mesin diagnosa. UI cuma kenal interface ini, jadi nanti bisa
/// diganti model lokal (TFLite) atau backend sendiri tanpa ubah screen.
abstract class DiseaseDiagnosisService {
  /// Apakah service sudah punya kredensial/model yang dibutuhkan.
  bool get isConfigured;

  /// Analisa foto tanaman dan kembalikan hasil diagnosa.
  Future<DiagnosisResult> diagnose(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  });
}

/// Error yang pesannya sudah ramah untuk ditampilkan ke pengguna.
class DiseaseDiagnosisException implements Exception {
  final String message;

  const DiseaseDiagnosisException(this.message);

  @override
  String toString() => message;
}

/// Diagnosa foto pakai Gemini API (vision).
///
/// API key diambil dari `lib/secrets.dart` (file lokal yang di-ignore git).
/// Bisa juga ditimpa lewat compile-time define:
/// ```
/// flutter run --dart-define=GEMINI_API_KEY=isi_api_key_kamu
/// ```
/// Model bisa diganti lewat `--dart-define=GEMINI_MODEL=nama-model`.
class GeminiDiseaseDiagnosisService implements DiseaseDiagnosisService {
  static const String _envApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: geminiApiKey,
  );
  static const String _envModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: geminiModel,
  );

  static const String _host =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static const Duration _timeout = Duration(seconds: 60);

  /// Status yang biasanya cuma sementara (server sibuk / rate limit).
  static const Set<int> _retryableStatuses = {429, 500, 502, 503, 504};
  static const int _maxAttempts = 3;

  final String? _apiKeyOverride;
  final String? _modelOverride;

  GeminiDiseaseDiagnosisService({String? apiKey, String? model})
    : _apiKeyOverride = apiKey,
      _modelOverride = model;

  String get _apiKey => (_apiKeyOverride ?? _envApiKey).trim();
  String get _model {
    final model = (_modelOverride ?? _envModel).trim();
    return model.isEmpty ? 'gemini-3.5-flash' : model;
  }

  @override
  bool get isConfigured => _apiKey.isNotEmpty;

  @override
  Future<DiagnosisResult> diagnose(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    if (!isConfigured) {
      throw const DiseaseDiagnosisException(
        'API key Gemini belum diset. Jalankan aplikasi dengan '
        '--dart-define=GEMINI_API_KEY=API_KEY_KAMU.',
      );
    }
    if (imageBytes.isEmpty) {
      throw const DiseaseDiagnosisException(
        'Fotonya kosong, coba ambil ulang.',
      );
    }

    final uri = Uri.parse('$_host/$_model:generateContent')
        .replace(queryParameters: {'key': _apiKey});

    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': _systemInstruction},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': _userPrompt},
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Encode(imageBytes),
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 4096,
        'responseMimeType': 'application/json',
        'responseSchema': _responseSchema,
      },
    });

    late final http.Response response;
    var attempt = 0;

    while (true) {
      attempt++;
      try {
        response = await http
            .post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(_timeout);
      } on TimeoutException {
        throw const DiseaseDiagnosisException(
          'Permintaan ke Gemini timeout. Cek koneksi internet lalu coba lagi.',
        );
      } on http.ClientException catch (error) {
        throw DiseaseDiagnosisException(
          'Gagal terhubung ke Gemini. Cek koneksi internet. (${error.message})',
        );
      } catch (error) {
        throw DiseaseDiagnosisException('Gagal menghubungi Gemini: $error');
      }

      if (response.statusCode == 200) break;

      final canRetry =
          _retryableStatuses.contains(response.statusCode) &&
          attempt < _maxAttempts;
      if (!canRetry) break;

      _log(
        'Gemini HTTP ${response.statusCode} (model $_model), '
        'percobaan $attempt gagal. Coba lagi...',
      );
      await Future<void>.delayed(Duration(seconds: 2 * attempt));
    }

    if (response.statusCode != 200) {
      _log(
        'Gemini gagal setelah $attempt percobaan: '
        'HTTP ${response.statusCode} ${response.body}',
      );
      throw DiseaseDiagnosisException(
        _errorMessage(response, attempts: attempt),
      );
    }

    return _parseResponse(response.body);
  }

  DiagnosisResult _parseResponse(String body) {
    late final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const DiseaseDiagnosisException(
        'Balasan Gemini tidak bisa dibaca. Coba lagi.',
      );
    }

    if (decoded is! Map) {
      throw const DiseaseDiagnosisException(
        'Balasan Gemini tidak sesuai format. Coba lagi.',
      );
    }

    final blockReason = _blockReason(decoded);
    if (blockReason != null) {
      throw DiseaseDiagnosisException(
        'Foto ditolak oleh Gemini ($blockReason). Coba foto lain.',
      );
    }

    final text = _extractText(decoded);
    if (text == null || text.trim().isEmpty) {
      throw const DiseaseDiagnosisException(
        'Gemini tidak mengembalikan hasil diagnosa. Coba foto lain.',
      );
    }

    late final Object? parsed;
    try {
      parsed = jsonDecode(_stripCodeFence(text));
    } on FormatException {
      throw const DiseaseDiagnosisException(
        'Hasil diagnosa tidak bisa dibaca. Coba lagi.',
      );
    }

    if (parsed is! Map) {
      throw const DiseaseDiagnosisException(
        'Hasil diagnosa tidak sesuai format. Coba lagi.',
      );
    }

    return DiagnosisResult.fromJson(
      parsed.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  String? _extractText(Map<dynamic, dynamic> decoded) {
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;

    final content = candidates.first is Map
        ? (candidates.first as Map)['content']
        : null;
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List) return null;

    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is! Map) continue;
      // Bagian "thought" dari model thinking bukan jawaban final.
      if (part['thought'] == true) continue;
      final text = part['text'];
      if (text is String && text.isNotEmpty) buffer.write(text);
    }

    final result = buffer.toString();
    return result.isEmpty ? null : result;
  }

  String? _blockReason(Map<dynamic, dynamic> decoded) {
    final feedback = decoded['promptFeedback'];
    if (feedback is! Map) return null;
    final reason = feedback['blockReason'];
    return reason is String && reason.isNotEmpty ? reason : null;
  }

  String _errorMessage(http.Response response, {int attempts = 1}) {
    String? detail;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] is String) {
          detail = error['message'] as String;
        }
      }
    } on FormatException {
      // Body bukan JSON, nanti pakai pesan default.
    }

    final tried = attempts > 1 ? ' Setelah dicoba $attempts kali.' : '';

    switch (response.statusCode) {
      case 400:
        return 'API key Gemini tidak valid atau permintaan ditolak. '
                '${detail ?? ''}'
            .trim();
      case 403:
        return 'Akses ke Gemini ditolak. Pastikan API key aktif dan '
                'Gemini API sudah diaktifkan. ${detail ?? ''}'
            .trim();
      case 404:
        return 'Model "$_model" tidak ditemukan. Set GEMINI_MODEL ke model '
                'yang tersedia. ${detail ?? ''}'
            .trim();
      case 429:
        return 'Kuota Gemini habis atau terlalu banyak permintaan.'
                '$tried Tunggu sebentar lalu coba lagi. ${detail ?? ''}'
            .trim();
      case 500:
      case 502:
      case 503:
      case 504:
        return 'Server Gemini sedang sibuk (HTTP ${response.statusCode}).'
                '$tried Ini bukan masalah API key, coba lagi beberapa saat. '
                '${detail ?? ''}'
            .trim();
      default:
        return 'Gemini mengembalikan error ${response.statusCode}. '
                '${detail ?? ''}'
            .trim();
    }
  }

  void _log(String message) {
    developer.log(message, name: 'GeminiDiagnosis');
  }

  String _stripCodeFence(String text) {
    var value = text.trim();
    if (!value.startsWith('```')) return value;

    value = value.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
    if (value.endsWith('```')) {
      value = value.substring(0, value.length - 3);
    }
    return value.trim();
  }

  static const String _systemInstruction =
      'Anda adalah ahli patologi tanaman dan hortikultura hidroponik. '
      'Tugas Anda menganalisa foto tanaman untuk mendeteksi penyakit, hama, '
      'defisiensi nutrisi, atau kondisi lingkungan yang bermasalah. '
      'Jawab selalu dalam Bahasa Indonesia yang sederhana dan praktis. '
      'Jangan mengarang nama penyakit. Jika foto tidak jelas atau bukan '
      'tanaman, katakan tidak dapat dianalisa dengan jujur.';

  static const String _userPrompt =
      'Analisa foto tanaman berikut. Tentukan nama tanaman (jika bisa '
      'dikenali), kondisi sehat/bermasalah, kemungkinan penyakit atau masalah '
      'yang terlihat, tingkat keyakinan (0-100), gejala yang tampak, penyebab '
      'yang mungkin, langkah penanganan, dan cara pencegahan.\n\n'
      'Panduan field JSON:\n'
      '- plantName: nama tanaman, mis. "Selada" atau "Tidak diketahui".\n'
      '- diseaseName: nama penyakit/masalah, mis. "Busuk Daun", '
      '"Defisiensi Nitrogen", atau "Tanaman Sehat".\n'
      '- isHealthy: true kalau tanaman terlihat sehat.\n'
      '- confidence: angka 0-100.\n'
      '- summary: ringkasan 1-2 kalimat.\n'
      '- symptoms: daftar gejala yang terlihat di foto.\n'
      '- causes: daftar kemungkinan penyebab.\n'
      '- treatment: daftar langkah penanganan yang bisa dilakukan.\n'
      '- prevention: daftar cara pencegahan.\n\n'
      'Kalau ada beberapa kemungkinan, urutkan dari yang paling mungkin dan '
      'sebutkan di summary bahwa hasil ini perkiraan.';

  static const Map<String, Object?> _responseSchema = {
    'type': 'OBJECT',
    'properties': {
      'plantName': {'type': 'STRING'},
      'diseaseName': {'type': 'STRING'},
      'isHealthy': {'type': 'BOOLEAN'},
      'confidence': {
        'type': 'INTEGER',
        'description': 'Tingkat keyakinan dalam persen, 0-100.',
      },
      'summary': {'type': 'STRING'},
      'symptoms': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
      'causes': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
      'treatment': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
      'prevention': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
    },
    'required': [
      'plantName',
      'diseaseName',
      'isHealthy',
      'confidence',
      'summary',
      'symptoms',
      'causes',
      'treatment',
      'prevention',
    ],
  };
}
