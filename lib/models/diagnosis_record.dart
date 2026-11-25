import 'diagnosis_result.dart';

/// Satu catatan hasil diagnosa yang disimpan ke riwayat.
class DiagnosisRecord {
  final String id;
  final DateTime createdAt;
  final DiagnosisResult result;

  const DiagnosisRecord({
    required this.id,
    required this.createdAt,
    required this.result,
  });

  factory DiagnosisRecord.fromResult(
    DiagnosisResult result, {
    DateTime? createdAt,
  }) {
    final when = createdAt ?? DateTime.now();
    return DiagnosisRecord(
      id: '${when.microsecondsSinceEpoch}',
      createdAt: when,
      result: result,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'result': result.toJson(),
    };
  }

  factory DiagnosisRecord.fromJson(Map<String, dynamic> json) {
    final rawResult = json['result'];
    final resultMap = rawResult is Map
        ? rawResult.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};

    return DiagnosisRecord(
      id: json['id']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      result: DiagnosisResult.fromJson(resultMap),
    );
  }
}
