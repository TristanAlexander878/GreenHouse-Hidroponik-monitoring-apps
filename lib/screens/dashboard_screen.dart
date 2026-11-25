import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/sensor_reading.dart';
import '../services/connection_status.dart';
import '../services/disease_diagnosis_service.dart';
import '../services/sensor_service.dart';
import '../theme/app_theme.dart';
import '../widgets/sensor_card.dart';
import 'diagnosis_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  final SensorService sensorService;
  final DiseaseDiagnosisService? diagnosisService;
  final String greenhouseName;

  const DashboardScreen({
    super.key,
    required this.sensorService,
    this.diagnosisService,
    this.greenhouseName = 'Greenhouse 1',
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _green = Color(0xFF2E7D4F);
  static const _red = Color(0xFFE05252);
  static const _orange = Color(0xFFE0A852);

  late Stream<SensorReading?> _readingsStream;
  late Stream<List<SensorReading>> _historyStream;

  bool _refreshing = false;
  String _chartMetric = 'ph';
  int _analysisWindow = 0;

  @override
  void initState() {
    super.initState();
    _readingsStream = widget.sensorService.readingsStream;
    _historyStream = widget.sensorService.historyStream;
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await widget.sensorService.refresh();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Color _statusColor(SensorStatus status) {
    switch (status) {
      case SensorStatus.critical:
        return _red;
      case SensorStatus.warning:
        return _orange;
      case SensorStatus.normal:
        return const Color(0xFF4CAF7D);
    }
  }

  String _statusMessage(SensorStatus status) {
    switch (status) {
      case SensorStatus.critical:
        return 'Kondisi butuh perhatian segera';
      case SensorStatus.warning:
        return 'Beberapa nilai mulai keluar rentang ideal';
      case SensorStatus.normal:
        return 'Semua kondisi dalam rentang normal';
    }
  }

  double _metricValue(SensorReading reading) {
    switch (_chartMetric) {
      case 'suhu_ruangan':
        return reading.roomTemp;
      case 'kelembapan':
        return reading.humidity;
      case 'tds':
        return reading.tds;
      default:
        return reading.ph;
    }
  }

  String _fungusRiskLabel(FungusRisk risk) {
    switch (risk) {
      case FungusRisk.high:
        return 'Tinggi';
      case FungusRisk.medium:
        return 'Sedang';
      case FungusRisk.low:
        return 'Rendah';
    }
  }

  String _fungusRiskMessage(FungusRisk risk) {
    switch (risk) {
      case FungusRisk.high:
        return 'Kelembapan dan suhu ruangan tinggi. Kurangi kelembapan dan '
            'tingkatkan sirkulasi udara.';
      case FungusRisk.medium:
        return 'Kelembapan ruangan mulai tinggi. Pantau sirkulasi udara.';
      case FungusRisk.low:
        return 'Kelembapan dan suhu ruangan mendukung pertumbuhan sehat.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  DiagnosisScreen(diagnosisService: widget.diagnosisService),
            ),
          );
        },
        backgroundColor: _green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.camera_alt_outlined, size: 20),
        label: const Text('Diagnosa'),
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<SensorReading?>(
          stream: _readingsStream,
          builder: (context, snapshot) {
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  toolbarHeight: 76,
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  automaticallyImplyLeading: false,
                  flexibleSpace: _HeaderBar(
                    refreshing: _refreshing,
                    onRefresh: _refreshing ? null : _refresh,
                    onSettings: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SettingsScreen(
                            sensorService: widget.sensorService,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      _buildBody(snapshot, textTheme),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildBody(
    AsyncSnapshot<SensorReading?> snapshot,
    TextTheme textTheme,
  ) {
    if (snapshot.hasError) {
      return _buildStatusBody(
        textTheme,
        color: _red,
        icon: Icons.error_outline,
        title: 'Gagal mengambil data sensor',
        message: ConnectionStatus.statusMessage.value ??
            snapshot.error.toString(),
        showRetry: true,
      );
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
      return _buildStatusBody(
        textTheme,
        color: _green,
        icon: Icons.cloud_sync_outlined,
        title: 'Menghubungkan ke Server...',
        message: ConnectionStatus.statusMessage.value ??
            'Sedang mengambil data sensor live dari Firebase.',
        showSpinner: true,
      );
    }

    final reading = snapshot.data;
    if (reading == null) {
      return _buildStatusBody(
        textTheme,
        color: _orange,
        icon: Icons.sensors_off,
        title: 'Belum ada data sensor',
        message: ConnectionStatus.statusMessage.value ??
            'Node Hydroponik di database masih kosong.',
        showRetry: true,
      );
    }

    return _buildConnectedBody(reading, textTheme);
  }

  List<Widget> _buildStatusBody(
    TextTheme textTheme, {
    required Color color,
    required IconData icon,
    required String title,
    required String message,
    bool showSpinner = false,
    bool showRetry = false,
  }) {
    return [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.16),
              color.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      if (showSpinner)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: CircularProgressIndicator(color: Color(0xFF2E7D4F)),
          ),
        ),
      if (showRetry)
        Center(
          child: TextButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Coba lagi'),
            style: TextButton.styleFrom(foregroundColor: color),
          ),
        ),
    ];
  }

  Widget _buildSensorGrid(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 360 ? 1 : 2;
        final rows = <Widget>[];

        for (var start = 0; start < cards.length; start += columns) {
          final end = start + columns < cards.length
              ? start + columns
              : cards.length;
          final rowCards = cards.sublist(start, end);

          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < rowCards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: rowCards[i]),
                  ],
                ],
              ),
            ),
          );

          if (end < cards.length) rows.add(const SizedBox(height: 12));
        }

        return Column(children: rows);
      },
    );
  }

  List<Widget> _buildConnectedBody(SensorReading reading, TextTheme textTheme) {
    final globalStatus = reading.overallStatus;
    final statusColor = _statusColor(globalStatus);

    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: statusColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _statusMessage(globalStatus),
                style: textTheme.bodyMedium?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _buildSensorGrid([
        SensorCard(
          label: 'pH Larutan',
          value: reading.ph,
          unit: '',
          icon: Icons.science_outlined,
          status: reading.phStatus,
          decimals: 1,
        ),
        SensorCard(
          label: 'Suhu Ruangan',
          value: reading.roomTemp,
          unit: '°C',
          icon: Icons.thermostat_outlined,
          status: reading.roomTempStatus,
          decimals: 1,
        ),
        SensorCard(
          label: 'Kelembapan Ruangan',
          value: reading.humidity,
          unit: '%',
          icon: Icons.water_drop_outlined,
          status: reading.humidityStatus,
          decimals: 1,
        ),
        SensorCard(
          label: 'TDS Larutan',
          value: reading.tds,
          unit: 'ppm',
          icon: Icons.water_outlined,
          status: reading.tdsStatus,
          decimals: 0,
        ),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _statusColor(reading.fungusRiskStatus).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _statusColor(reading.fungusRiskStatus)
                .withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.coronavirus_outlined,
              color: _statusColor(reading.fungusRiskStatus),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resiko Jamur: ${_fungusRiskLabel(reading.fungusRisk)}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: _statusColor(reading.fungusRiskStatus),
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _fungusRiskMessage(reading.fungusRisk),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Text(
        'Histori Data Grafik (Live)',
        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _metricChip('ph', 'pH'),
          _metricChip('suhu_ruangan', 'Suhu'),
          _metricChip('kelembapan', 'Lembap'),
          _metricChip('tds', 'TDS'),
        ],
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 200,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.outline, width: 1),
          ),
          child: StreamBuilder<List<SensorReading>>(
            stream: _historyStream,
            builder: (context, historySnapshot) {
              if (historySnapshot.hasError) {
                return const Center(child: Text('Gagal memuat grafik'));
              }

              final list = historySnapshot.data ?? const <SensorReading>[];
              if (list.isEmpty) {
                return const Center(child: Text('Menyusun titik data grafik...'));
              }
              if (list.length < 2) {
                return const Center(
                  child: Text('Menunggu data berikutnya dari database...'),
                );
              }

              final spots = <FlSpot>[
                for (var i = 0; i < list.length; i++)
                  FlSpot(i.toDouble(), _metricValue(list[i])),
              ];

              return LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          return LineTooltipItem(
                            spot.y.toStringAsFixed(
                              _chartMetric == 'tds' ? 0 : 1,
                            ),
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: _green,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 28),
      ..._buildAnalysisSection(textTheme),
      const SizedBox(height: 24),
      Center(
        child: Text(
          'Terakhir Diperbarui: '
          '${DateFormat('HH:mm:ss').format(reading.timestamp)}',
          style: textTheme.bodySmall?.copyWith(color: Colors.black38),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(height: 96),
    ];
  }

  String _metricLabel(String metric) {
    switch (metric) {
      case 'suhu_ruangan':
        return 'Suhu Ruangan';
      case 'kelembapan':
        return 'Kelembapan';
      case 'tds':
        return 'TDS Larutan';
      default:
        return 'pH Larutan';
    }
  }

  String _metricUnit(String metric) {
    switch (metric) {
      case 'suhu_ruangan':
        return '°C';
      case 'kelembapan':
        return '%';
      case 'tds':
        return 'ppm';
      default:
        return '';
    }
  }

  int _metricDecimals(String metric) => metric == 'tds' ? 0 : 1;

  List<Widget> _buildAnalysisSection(TextTheme textTheme) {
    return [
      Row(
        children: [
          const Icon(Icons.insights_outlined, size: 20, color: _green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mode Grafik',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Analisis',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _green,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        'Ringkasan statistik dan tren dari data yang sudah masuk.',
        style: textTheme.bodySmall?.copyWith(color: Colors.black45),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _windowChip(0, 'Semua'),
          _windowChip(10, '10 Terakhir'),
          _windowChip(30, '30 Terakhir'),
        ],
      ),
      const SizedBox(height: 12),
      StreamBuilder<List<SensorReading>>(
        stream: _historyStream,
        builder: (context, snapshot) {
          final all = snapshot.data ?? const <SensorReading>[];
          final list = _analysisWindow == 0 || all.length <= _analysisWindow
              ? all
              : all.sublist(all.length - _analysisWindow);

          if (list.isEmpty) {
            return _analysisPlaceholder(textTheme);
          }

          final values = [for (final reading in list) _metricValue(reading)];
          final lowest = values.reduce((a, b) => a < b ? a : b);
          final highest = values.reduce((a, b) => a > b ? a : b);
          final average = values.reduce((a, b) => a + b) / values.length;
          final decimals = _metricDecimals(_chartMetric);
          final unit = _metricUnit(_chartMetric);
          final rising = values.length >= 2 && values.last >= values.first;
          final delta = values.length >= 2
              ? (values.last - values.first).abs()
              : 0.0;

          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _statTile(
                      'Terendah',
                      lowest,
                      unit,
                      decimals,
                      AppColors.success,
                      Icons.south_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statTile(
                      'Rata-rata',
                      average,
                      unit,
                      decimals,
                      _green,
                      Icons.drag_handle_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statTile(
                      'Tertinggi',
                      highest,
                      unit,
                      decimals,
                      _orange,
                      Icons.north_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (rising ? _green : _orange).withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        rising
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        color: rising ? _green : _orange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rising ? 'Tren meningkat' : 'Tren menurun',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_metricLabel(_chartMetric)} '
                            '${rising ? 'naik' : 'turun'} '
                            '${delta.toStringAsFixed(decimals)} $unit '
                            'dari ${list.length} data.',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.black45,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ];
  }

  Widget _windowChip(int value, String label) {
    final selected = _analysisWindow == value;
    return GestureDetector(
      onTap: () => setState(() => _analysisWindow = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _green : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _green : Colors.black12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _statTile(
    String label,
    double value,
    String unit,
    int decimals,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value.toStringAsFixed(decimals),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 2),
                  Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _analysisPlaceholder(TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.query_stats_outlined,
            color: Colors.black26,
            size: 30,
          ),
          const SizedBox(height: 8),
          Text(
            'Menunggu data untuk dianalisis...',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String metric, String label) {
    final selected = _chartMetric == metric;
    return GestureDetector(
      onTap: () => setState(() => _chartMetric = metric),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _green : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _green : Colors.black12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  final bool refreshing;
  final VoidCallback? onRefresh;
  final VoidCallback onSettings;

  const _HeaderBar({
    required this.refreshing,
    required this.onRefresh,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Stack(
      fit: StackFit.expand,
      children: [
        const _HeaderBackground(),
        Padding(
          padding: EdgeInsets.only(
            top: topInset + 8,
            left: 16,
            right: 16,
            bottom: 12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: const Icon(
                  Icons.eco_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Monitoring Hidroponik',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _HeaderActionButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh',
                loading: refreshing,
                onPressed: onRefresh,
              ),
              const SizedBox(width: 10),
              _HeaderActionButton(
                icon: Icons.settings_outlined,
                tooltip: 'Pengaturan',
                onPressed: onSettings,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderBackground extends StatelessWidget {
  const _HeaderBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF34A66A), Color(0xFF1B4332)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -30,
            child: _circle(120, 0.10),
          ),
          Positioned(
            right: 40,
            bottom: -50,
            child: _circle(150, 0.06),
          ),
          Positioned(
            left: -30,
            bottom: -40,
            child: _circle(90, 0.05),
          ),
          // Lengkungan warna background body supaya header terasa menyambung
          // dengan konten di bawahnya, bukan dua blok terpisah.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 20,
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool loading;

  const _HeaderActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
