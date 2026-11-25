import 'package:flutter/material.dart';

import '../services/connection_status.dart';
import '../services/sensor_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  final SensorService? sensorService;

  const SettingsScreen({super.key, this.sensorService});

  Future<void> _syncNow(BuildContext context) async {
    final service = sensorService;
    if (service == null) return;

    await service.refresh();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              ConnectionStatus.isConnected.value
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ConnectionStatus.isConnected.value
                    ? 'Data terbaru berhasil diambil dari database.'
                    : ConnectionStatus.statusMessage.value ??
                          'Belum bisa mengambil data dari database.',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: ConnectionStatus.isConnected.value
            ? const Color(0xFF4CAF7D)
            : const Color(0xFFE05252),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Koneksi Database',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: AppColors.outline, width: 1),
              ),
              child: ValueListenableBuilder<String?>(
                valueListenable: ConnectionStatus.statusMessage,
                builder: (context, message, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: ConnectionStatus.isConnected,
                    builder: (context, connected, _) {
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: connected
                                ? const Color(0xFF4CAF7D).withValues(alpha: 0.12)
                                : const Color(0xFFE05252).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            connected ? Icons.sensors : Icons.sensors_off,
                            color: connected
                                ? const Color(0xFF4CAF7D)
                                : const Color(0xFFE05252),
                            size: 22,
                          ),
                        ),
                        title: Text(
                          connected ? 'Sensor Terhubung' : 'Sensor Terputus',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          connected
                              ? 'Data live sedang masuk dari Realtime Database'
                              : (message ?? 'Tidak ada koneksi ke database'),
                          style: const TextStyle(fontSize: 12.5),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (sensorService != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _syncNow(context),
                  icon: const Icon(Icons.sync, size: 20),
                  label: const Text('Ambil Data Terbaru Sekarang'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D4F),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Tentang',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: AppColors.outline, width: 1),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.info_outline,
                      color: Color(0xFF2E7D4F),
                    ),
                    title: const Text('Versi Aplikasi'),
                    trailing: const Text('1.0.0'),
                  ),
                  Divider(height: 1, color: AppColors.outline),
                  ListTile(
                    leading: const Icon(
                      Icons.eco_outlined,
                      color: Color(0xFF2E7D4F),
                    ),
                    title: const Text('Greenhouse Monitoring'),
                    subtitle: const Text(
                      'AIoT-based hydroponic monitoring system',
                    ),
                  ),
                  Divider(height: 1, color: AppColors.outline),
                  ListTile(
                    leading: const Icon(
                      Icons.storage_outlined,
                      color: Color(0xFF2E7D4F),
                    ),
                    title: const Text('Sumber Data'),
                    subtitle: const Text(
                      'Firebase Realtime Database',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
