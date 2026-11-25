import 'package:flutter_test/flutter_test.dart';

import 'package:hidroponik_apps/models/diagnosis_result.dart';

void main() {
  test('DiagnosisResult.fromJson baca field lengkap', () {
    final result = DiagnosisResult.fromJson({
      'plantName': 'Selada',
      'diseaseName': 'Busuk Daun',
      'isHealthy': false,
      'confidence': 87,
      'summary': 'Daun tampak busuk di bagian tepi.',
      'symptoms': ['Tepi daun coklat', 'Daun lembek'],
      'causes': ['Kelembapan terlalu tinggi'],
      'treatment': ['Kurangi kelembapan', 'Pangkas daun sakit'],
      'prevention': ['Jaga sirkulasi udara'],
    });

    expect(result.plantName, 'Selada');
    expect(result.diseaseName, 'Busuk Daun');
    expect(result.isHealthy, isFalse);
    expect(result.confidence, 87);
    expect(result.symptoms, hasLength(2));
    expect(result.treatment.first, 'Kurangi kelembapan');
  });

  test('confidence skala 0-1 dinormalisasi jadi persen', () {
    final result = DiagnosisResult.fromJson({
      'diseaseName': 'Tanaman Sehat',
      'confidence': 0.92,
    });

    expect(result.confidence, 92);
    expect(result.isHealthy, isTrue);
  });

  test('confidence string dengan persen tetap kebaca', () {
    final result = DiagnosisResult.fromJson({
      'diseaseName': 'Defisiensi Nitrogen',
      'confidence': '75%',
    });

    expect(result.confidence, 75);
  });

  test('field yang hilang tidak bikin crash', () {
    final result = DiagnosisResult.fromJson({});

    expect(result.diseaseName, 'Tidak dapat dianalisa');
    expect(result.plantName, 'Tanaman');
    expect(result.confidence, 0);
    expect(result.symptoms, isEmpty);
    expect(result.prevention, isEmpty);
  });
}
