import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hidroponik_apps/models/sensor_reading.dart';
import 'package:hidroponik_apps/screens/dashboard_screen.dart';
import 'package:hidroponik_apps/services/sensor_service.dart';

class _FakeSensorService implements SensorService {
  final StreamController<SensorReading?> _readings =
      StreamController<SensorReading?>.broadcast();
  final StreamController<List<SensorReading>> _history =
      StreamController<List<SensorReading>>.broadcast();

  int refreshCount = 0;

  @override
  Stream<SensorReading?> get readingsStream => _readings.stream;

  @override
  Stream<List<SensorReading>> get historyStream => _history.stream;

  @override
  Future<void> refresh() async => refreshCount++;

  void emit(SensorReading? reading, [List<SensorReading> history = const []]) {
    _readings.add(reading);
    _history.add(history);
  }

  Future<void> dispose() async {
    await _readings.close();
    await _history.close();
  }
}

Widget _wrap(SensorService service) => MaterialApp(
  home: DashboardScreen(sensorService: service, greenhouseName: 'Greenhouse 1'),
);

void main() {
  test('SensorReading.tryParse estimasi TDS dari kolom ec (ppm)', () {
    final reading = SensorReading.tryParse({
      'ph': 6.2,
      'ec': 1.5,
      'suhu_ruangan': 24,
      'kelembapan': 70,
    });

    expect(reading, isNotNull);
    expect(reading!.ph, 6.2);
    expect(reading.tds, 1.5 * SensorReading.ecToTdsFactor);
    expect(reading.roomTemp, 24);
    expect(reading.humidity, 70);
  });

  test('SensorReading.tryParse pakai kolom tds ppm langsung', () {
    final reading = SensorReading.tryParse({'tds': 820});

    expect(reading, isNotNull);
    expect(reading!.tds, 820);
  });

  test('SensorReading.tryParse masih baca kolom suhu lama', () {
    final reading = SensorReading.tryParse({'suhu': 24});

    expect(reading, isNotNull);
    expect(reading!.roomTemp, 24);
  });

  test('SensorReading.tryParse return null kalau node kosong', () {
    expect(SensorReading.tryParse(null), isNull);
    expect(SensorReading.tryParse(<String, Object?>{}), isNull);
    expect(SensorReading.tryParse('bukan map'), isNull);
  });

  test('status sensor pakai batas nilai yang benar', () {
    SensorReading make({
      double ph = 6.0,
      double temp = 23,
      double humidity = 65,
      double tds = 750,
    }) => SensorReading(
      ph: ph,
      roomTemp: temp,
      humidity: humidity,
      tds: tds,
      timestamp: DateTime(2026),
    );

    expect(make().overallStatus, SensorStatus.normal);
    expect(make(ph: 5.4).phStatus, SensorStatus.critical);
    expect(make(ph: 5.7).phStatus, SensorStatus.warning);
    expect(make(temp: 9).roomTempStatus, SensorStatus.critical);
    expect(make(temp: 20).roomTempStatus, SensorStatus.warning);
    expect(make(temp: 33).roomTempStatus, SensorStatus.warning);
    expect(make(humidity: 30).humidityStatus, SensorStatus.critical);
    expect(make(humidity: 55).humidityStatus, SensorStatus.warning);
    expect(make(tds: 950).tdsStatus, SensorStatus.warning);
    expect(make(tds: 450).tdsStatus, SensorStatus.critical);
    expect(make(ph: 5.4).overallStatus, SensorStatus.critical);
  });

  test('resiko jamur naik saat kelembapan ruangan tinggi', () {
    SensorReading make({double temp = 25, double humidity = 65}) =>
        SensorReading(
          ph: 6.0,
          roomTemp: temp,
          humidity: humidity,
          tds: 750,
          timestamp: DateTime(2026),
        );

    expect(make(temp: 24).fungusRisk, FungusRisk.low);
    expect(make(temp: 25).fungusRisk, FungusRisk.medium);
    expect(make(humidity: 72).fungusRisk, FungusRisk.medium);
    expect(make(humidity: 85).fungusRisk, FungusRisk.high);
    expect(make(humidity: 92).fungusRisk, FungusRisk.high);

    expect(make(humidity: 85).overallStatus, SensorStatus.critical);
    expect(make(humidity: 72).overallStatus, SensorStatus.warning);
  });

  testWidgets('dashboard nampilin status menghubungkan saat belum ada data', (
    tester,
  ) async {
    final service = _FakeSensorService();
    addTearDown(service.dispose);

    await tester.pumpWidget(_wrap(service));

    expect(find.text('Greenhouse 1'), findsOneWidget);
    expect(find.text('Menghubungkan ke Server...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dashboard nampilin data asli dari service', (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final service = _FakeSensorService();
    addTearDown(service.dispose);

    await tester.pumpWidget(_wrap(service));

    final reading = SensorReading(
      ph: 6.1,
      roomTemp: 23.4,
      humidity: 68,
      tds: 750,
      timestamp: DateTime(2026, 1, 1, 10, 30, 15),
    );
    service.emit(reading, [reading, reading]);
    await tester.pump();

    expect(find.text('Semua kondisi dalam rentang normal'), findsOneWidget);
    expect(find.text('pH Larutan'), findsOneWidget);
    expect(find.text('Suhu Ruangan'), findsOneWidget);
    expect(find.text('Kelembapan Ruangan'), findsOneWidget);
    expect(find.text('TDS Larutan'), findsOneWidget);
    expect(find.text('6.1'), findsOneWidget);
    expect(find.text('23.4'), findsOneWidget);
    expect(find.text('750'), findsOneWidget);
    expect(find.text('Terakhir Diperbarui: 10:30:15'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dashboard nampilin peringatan kalau nilai di luar rentang', (
    tester,
  ) async {
    final service = _FakeSensorService();
    addTearDown(service.dispose);

    await tester.pumpWidget(_wrap(service));

    service.emit(
      SensorReading(
        ph: 5.2,
        roomTemp: 36,
        humidity: 92,
        tds: 1250,
        timestamp: DateTime(2026),
      ),
      [],
    );
    await tester.pump();

    expect(find.text('Kondisi butuh perhatian segera'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dashboard nampilin node kosong bukan data karangan', (
    tester,
  ) async {
    final service = _FakeSensorService();
    addTearDown(service.dispose);

    await tester.pumpWidget(_wrap(service));

    service.emit(null);
    await tester.pump();

    expect(find.text('Belum ada data sensor'), findsOneWidget);
    expect(find.text('pH Larutan'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tombol refresh manggil service.refresh', (tester) async {
    final service = _FakeSensorService();
    addTearDown(service.dispose);

    await tester.pumpWidget(_wrap(service));

    service.emit(
      SensorReading(
        ph: 6.0,
        roomTemp: 23,
        humidity: 68,
        tds: 750,
        timestamp: DateTime(2026),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();

    expect(service.refreshCount, 1);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dashboard aman di layar sempit tanpa overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final service = _FakeSensorService();
    addTearDown(service.dispose);

    await tester.pumpWidget(_wrap(service));

    final reading = SensorReading(
      ph: 6.1,
      roomTemp: 33.4,
      humidity: 72.5,
      tds: 1225,
      timestamp: DateTime(2026),
    );
    service.emit(reading, [reading, reading]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.takeException(), isNull);
    expect(find.text('Kondisi butuh perhatian segera'), findsOneWidget);
    expect(find.text('Kelembapan Ruangan'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dashboard aman di Pixel 6 Pro tanpa overflow', (tester) async {
    // Pixel 6 Pro: 1440 x 3120 fisik, DPR 3.5 -> ~411 x 891 logical.
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.5;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final service = _FakeSensorService();
    addTearDown(service.dispose);

    await tester.pumpWidget(_wrap(service));

    final reading = SensorReading(
      ph: 6.1,
      roomTemp: 33.4,
      humidity: 72.5,
      tds: 1234,
      timestamp: DateTime(2026),
    );
    service.emit(reading, [reading, reading]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.takeException(), isNull);
    expect(find.text('TDS Larutan'), findsOneWidget);
    expect(find.text('1234'), findsOneWidget);
    expect(find.text('ppm'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
