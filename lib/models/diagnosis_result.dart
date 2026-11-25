/// Hasil diagnosa penyakit tanaman dari foto.
///
/// Field-nya sengaja dibuat sederhana supaya mudah ditampilkan di UI dan
/// gampang diganti sumbernya (Gemini, model lokal, atau backend sendiri).
class DiagnosisResult {
  final String plantName;
  final String diseaseName;
  final bool isHealthy;
  final int confidence;
  final String summary;
  final List<String> symptoms;
  final List<String> causes;
  final List<String> treatment;
  final List<String> prevention;

  const DiagnosisResult({
    required this.plantName,
    required this.diseaseName,
    required this.isHealthy,
    required this.confidence,
    required this.summary,
    required this.symptoms,
    required this.causes,
    required this.treatment,
    required this.prevention,
  });

  /// Parse JSON dari model. Dibuat toleran: kalau ada field yang hilang atau
  /// tipenya beda (mis. confidence dikirim 0.87 atau "87%"), tetap kebaca.
  factory DiagnosisResult.fromJson(Map<String, dynamic> json) {
    final disease = _asString(json['diseaseName']);
    final healthyFlag = _asBool(json['isHealthy']);

    return DiagnosisResult(
      plantName: _asString(json['plantName'], fallback: 'Tanaman'),
      diseaseName: disease.isEmpty ? 'Tidak dapat dianalisa' : disease,
      isHealthy:
          healthyFlag ||
          disease.toLowerCase().contains('sehat') ||
          disease.toLowerCase().contains('healthy'),
      confidence: _asConfidence(json['confidence']),
      summary: _asString(json['summary']),
      symptoms: _asStringList(json['symptoms']),
      causes: _asStringList(json['causes']),
      treatment: _asStringList(json['treatment']),
      prevention: _asStringList(json['prevention']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plantName': plantName,
      'diseaseName': diseaseName,
      'isHealthy': isHealthy,
      'confidence': confidence,
      'summary': summary,
      'symptoms': symptoms,
      'causes': causes,
      'treatment': treatment,
      'prevention': prevention,
    };
  }

  static String _asString(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static bool _asBool(Object? value) {
    if (value is bool) return value;
    final text = value?.toString().toLowerCase().trim();
    return text == 'true' || text == 'ya' || text == 'yes';
  }

  static int _asConfidence(Object? value) {
    final raw = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString().replaceAll('%', '').trim() ?? '');
    if (raw == null) return 0;

    // Model kadang ngasih skala 0-1, kadang 0-100. Samakan ke persen.
    final percent = raw <= 1 ? raw * 100 : raw;
    return percent.round().clamp(0, 100);
  }

  static List<String> _asStringList(Object? value) {
    if (value is List) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? const [] : [text];
  }
}
