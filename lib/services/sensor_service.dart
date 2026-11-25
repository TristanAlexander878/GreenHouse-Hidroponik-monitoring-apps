import '../models/sensor_reading.dart';

/// Kontrak bersama untuk semua sumber data sensor.
///
/// Dashboard cuma ngomong sama interface ini, jadi sumber datanya bisa
/// diganti (mis. FakeSensorService di test) tanpa ngedit UI.
abstract class SensorService {
  /// Data sensor terbaru. `null` artinya node-nya ada tapi belum ada
  /// nilai yang dikirim device.
  Stream<SensorReading?> get readingsStream;

  /// Deretan data terlama -> terbaru buat grafik.
  Stream<List<SensorReading>> get historyStream;

  /// Paksa ambil ulang data terbaru dari database.
  Future<void> refresh();
}
