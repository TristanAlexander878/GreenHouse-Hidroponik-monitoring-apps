import 'package:flutter/material.dart';

import '../models/diagnosis_record.dart';
import '../services/diagnosis_store.dart';
import '../theme/app_theme.dart';
import '../widgets/diagnosis_result_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static const _green = Color(0xFF2E7D4F);
  static const _red = Color(0xFFE05252);
  static const _amber = Color(0xFFD99A2B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Riwayat Diagnosa'),
        actions: [
          AnimatedBuilder(
            animation: DiagnosisStore.instance,
            builder: (context, _) {
              final count = DiagnosisStore.instance.history.length;
              if (count == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count catatan',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: DiagnosisStore.instance,
        builder: (context, _) {
          final history = DiagnosisStore.instance.history;
          if (history.isEmpty) {
            return const _EmptyHistory();
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            itemCount: history.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final record = history[index];
              return Dismissible(
                key: ValueKey(record.id),
                direction: DismissDirection.endToStart,
                background: _deleteBackground(),
                confirmDismiss: (_) => _confirmDelete(context, record),
                onDismissed: (_) {
                  DiagnosisStore.instance.deleteRecord(record.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Catatan diagnosa dihapus.'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                },
                child: _HistoryCard(
                  record: record,
                  onTap: () => _openDetail(context, record),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _deleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        color: _red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Icon(Icons.delete_outline, color: _red),
    );
  }

  Future<bool> _confirmDelete(
    BuildContext context,
    DiagnosisRecord record,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus catatan?'),
        content: Text(
          'Riwayat "${record.result.diseaseName}" dan tugas terkait akan '
          'dihapus permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _openDetail(BuildContext context, DiagnosisRecord record) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.96,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.event_note_outlined,
                              size: 16,
                              color: AppColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatDate(record.createdAt),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DiagnosisResultCard(result: record.result),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Color accentFor(DiagnosisRecord record) {
    if (record.result.isHealthy) return _green;
    if (record.result.confidence == 0 ||
        record.result.diseaseName.toLowerCase().contains('tidak dapat')) {
      return _amber;
    }
    return _red;
  }

  static String _formatDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.day} ${months[value.month - 1]} ${value.year} • '
        '$hour:$minute';
  }
}

class _HistoryCard extends StatelessWidget {
  final DiagnosisRecord record;
  final VoidCallback onTap;

  const _HistoryCard({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final result = record.result;
    final accent = HistoryScreen.accentFor(record);
    final statusLabel = result.isHealthy
        ? 'SEHAT'
        : result.confidence == 0
        ? 'BELUM YAKIN'
        : 'PERLU PERHATIAN';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(alpha: 0.22),
                        accent.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    result.isHealthy
                        ? Icons.verified_outlined
                        : Icons.coronavirus_outlined,
                    color: accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: accent,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${result.confidence}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        result.diseaseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${result.plantName} • ${HistoryScreen._formatDate(record.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.onSurfaceVariant,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.18),
                    AppColors.primary.withValues(alpha: 0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_toggle_off_rounded,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Belum ada riwayat',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hasil diagnosa tanaman melon akan otomatis tersimpan di sini '
              'setelah kamu menganalisa foto.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
