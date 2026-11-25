enum SensorStatus { normal, warning, critical }

enum FungusRisk { low, medium, high }

class SensorReading {
  final double ph;
  final double roomTemp;
  final double humidity;

  /// Total Dissolved Solids (TDS) dalam satuan ppm — estimasi padatan
  /// terlarut larutan nutrisi.
  ///
  /// Dipakai langsung kalau device mengirim kolom `tds`/`tds_ppm`/`ppm`.
  /// Kalau cuma tersedia `ec` (mS/cm), nilainya diestimasi dengan faktor
  /// [ecToTdsFactor] (`ppm = ec x 500`), pendekatan umum untuk larutan
  /// nutrisi hidroponik.
  final double tds;

  final DateTime timestamp;

  /// Faktor estimasi EC (mS/cm) -> TDS (ppm).
  static const double ecToTdsFactor = 500;

  SensorReading({
    required this.ph,
    required this.roomTemp,
    required this.humidity,
    required this.tds,
    required this.timestamp,
  });

  /// Baca satu node `hydroponik` dari Realtime Database.
  ///
  /// Nama kolom yang didukung: `ph`, `tds`/`tds_ppm`/`ppm`, `suhu_ruangan`/
  /// `temperature`/`roomTemp`, dan `kelembapan`/`humidity`. Kolom `ec`
  /// (mS/cm) masih didukung dan otomatis diestimasi jadi TDS ppm.
  /// `timestamp` berupa epoch ms.
  ///
  /// Node bisa berisi nilai langsung, atau dikelompokkan per device
  /// (mis. `hydroponik/<device>/...`). Kalau dikelompokkan, dipakai
  /// pembacaan dengan timestamp terbaru.
  ///
  /// Return `null` kalau node-nya kosong / bukan map / nggak ada satu pun
  /// nilai sensor yang valid, biar UI bisa nampilin "belum ada data"
  /// daripada ngarang angka.
  static SensorReading? tryParse(Object? raw) {
    if (raw is! Map) return null;

    final direct = _fromMap(raw);
    if (direct != null) return direct;

    SensorReading? best;
    for (final value in raw.values) {
      if (value is! Map) continue;
      final reading = _fromMap(value);
      if (reading == null) continue;
      if (best == null || reading.timestamp.isAfter(best.timestamp)) {
        best = reading;
      }
    }
    return best;
  }

  static SensorReading? _fromMap(Map raw) {
    final keys = <String, Object?>{
      for (final entry in raw.entries)
        _normalizeKey(entry.key.toString()): entry.value,
    };

    final ph = _asDouble(_pick(keys, ['ph']));
    final tdsDirect = _asDouble(
      _pick(keys, ['tds', 'tds_ppm', 'ppm', 'dissolved_solids']),
    );
    final ec = _asDouble(_pick(keys, ['ec']));
    final tds = tdsDirect ?? (ec == null ? null : ec * ecToTdsFactor);
    final temp = _asDouble(
      _pick(keys, ['suhu_ruangan', 'roomTemp', 'suhu', 'temperature']),
    );
    final humidity = _asDouble(
      _pick(keys, ['kelembapan_ruangan', 'kelembapan', 'humidity']),
    );

    if (ph == null && tds == null && temp == null && humidity == null) {
      return null;
    }

    final ts = _asDouble(_pick(keys, ['timestamp']));
    return SensorReading(
      ph: ph ?? 0,
      roomTemp: temp ?? 0,
      humidity: humidity ?? 0,
      tds: tds ?? 0,
      timestamp: ts != null
          ? DateTime.fromMillisecondsSinceEpoch(ts.round())
          : DateTime.now(),
    );
  }

  /// Samakan nama kolom yang beda spasi/underscore/huruf besar,
  /// mis. `kelembapan ruangan`, `kelembapan_ruangan`, `kelembapanRuangan`.
  static String _normalizeKey(String key) =>
      key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static Object? _pick(Map<String, Object?> keys, List<String> aliases) {
    for (final alias in aliases) {
      final value = keys[_normalizeKey(alias)];
      if (value != null) return value;
    }
    return null;
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  SensorStatus get phStatus {
    if (ph < 5.5 || ph > 6.5) return SensorStatus.critical;
    if (ph < 5.8 || ph > 6.2) return SensorStatus.warning;
    return SensorStatus.normal;
  }

  /// Melon/cantaloupe: ideal 21-32 °C, di bawah 10 °C pertumbuhan
  /// terhambat (kritis).
  SensorStatus get roomTempStatus {
    if (roomTemp < 10 || roomTemp > 35) return SensorStatus.critical;
    if (roomTemp < 21 || roomTemp > 32) return SensorStatus.warning;
    return SensorStatus.normal;
  }

  /// Target kelembapan 60-70 RH. Di bawah 45 RH terlalu kering,
  /// di atas 80 RH memicu penyakit jamur.
  SensorStatus get humidityStatus {
    if (humidity < 45 || humidity > 80) return SensorStatus.critical;
    if (humidity < 60 || humidity > 70) return SensorStatus.warning;
    return SensorStatus.normal;
  }

  /// TDS ideal untuk melon 600-900 ppm. Di bawah 500 ppm atau di atas
  /// 1000 ppm sudah masuk zona kritis.
  SensorStatus get tdsStatus {
    if (tds < 500 || tds > 1000) return SensorStatus.critical;
    if (tds < 600 || tds > 900) return SensorStatus.warning;
    return SensorStatus.normal;
  }

  /// Resiko jamur adalah gabungan kelembapan dan suhu ruangan.
  ///
  /// Kelembapan tinggi saja sudah bikin waspada (kuning), tapi jamur
  /// benar-benar cepat berkembang saat lembap DAN hangat, jadi kombinasinya
  /// yang menaikkan status ke merah.
  FungusRisk get fungusRisk {
    final humidityScore = humidity >= 80
        ? 2
        : humidity >= 70
        ? 1
        : 0;
    final tempScore = roomTemp >= 30
        ? 2
        : roomTemp >= 25
        ? 1
        : 0;

    final score = humidityScore + tempScore;
    if (score >= 3) return FungusRisk.high;
    if (score >= 1) return FungusRisk.medium;
    return FungusRisk.low;
  }

  SensorStatus get fungusRiskStatus {
    switch (fungusRisk) {
      case FungusRisk.high:
        return SensorStatus.critical;
      case FungusRisk.medium:
        return SensorStatus.warning;
      case FungusRisk.low:
        return SensorStatus.normal;
    }
  }

  SensorStatus get overallStatus {
    final statuses = [
      phStatus,
      roomTempStatus,
      humidityStatus,
      tdsStatus,
      fungusRiskStatus,
    ];
    if (statuses.contains(SensorStatus.critical)) return SensorStatus.critical;
    if (statuses.contains(SensorStatus.warning)) return SensorStatus.warning;
    return SensorStatus.normal;
  }
}
