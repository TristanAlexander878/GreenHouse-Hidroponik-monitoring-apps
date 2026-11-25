import 'package:flutter/material.dart';

import '../models/daily_task.dart';
import '../services/diagnosis_store.dart';
import '../theme/app_theme.dart';

const _green = Color(0xFF2E7D4F);
const _amber = Color(0xFFD99A2B);

class DailyTaskScreen extends StatefulWidget {
  const DailyTaskScreen({super.key});

  @override
  State<DailyTaskScreen> createState() => _DailyTaskScreenState();
}

class _DailyTaskScreenState extends State<DailyTaskScreen> {
  @override
  void initState() {
    super.initState();
    DiagnosisStore.instance.refreshForToday();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tugas Harian'),
      ),
      body: AnimatedBuilder(
        animation: DiagnosisStore.instance,
        builder: (context, _) {
          final tasks = DiagnosisStore.instance.todayTasks;
          final done = tasks.where((task) => task.done).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _ProgressHeader(
                total: tasks.length,
                done: done,
                date: DateTime.now(),
              ),
              const SizedBox(height: 20),
              if (tasks.isEmpty)
                const _EmptyTasks()
              else ...[
                Row(
                  children: [
                    const Text(
                      'Hari Ini',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${tasks.length} tugas',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final task in tasks) ...[
                  _TaskTile(
                    task: task,
                    onToggle: () =>
                        DiagnosisStore.instance.toggleTask(task.id),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int total;
  final int done;
  final DateTime date;

  const _ProgressHeader({
    required this.total,
    required this.done,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : done / total;
    final percent = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF34A66A), Color(0xFF1B4332)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B4332).withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(date),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Rencana Perawatan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 58,
                height: 58,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return SizedBox(
                          width: 58,
                          height: 58,
                          child: CircularProgressIndicator(
                            value: value,
                            strokeWidth: 6,
                            strokeCap: StrokeCap.round,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.2,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                    Text(
                      '$percent%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            total == 0
                ? 'Belum ada tugas untuk hari ini.'
                : '$done dari $total tugas selesai',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime value) {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${days[value.weekday - 1]}, ${value.day} '
        '${months[value.month - 1]} ${value.year}';
  }
}

class _TaskTile extends StatelessWidget {
  final DailyTask task;
  final VoidCallback onToggle;

  const _TaskTile({required this.task, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isTreatment = task.category == TaskCategory.treatment;
    final accent = isTreatment ? _green : _amber;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: task.done ? const Color(0xFFF3F6F3) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: task.done
                  ? AppColors.outline
                  : accent.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26,
                height: 26,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: task.done ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: task.done ? accent : accent.withValues(alpha: 0.5),
                    width: 1.8,
                  ),
                ),
                child: task.done
                    ? const Icon(Icons.check, size: 17, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: task.done
                            ? AppColors.onSurfaceVariant
                            : AppColors.onSurface,
                        decoration: task.done
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isTreatment ? 'Penanganan' : 'Pencegahan',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            task.sourceDisease,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
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
              Icons.task_alt_rounded,
              size: 44,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Belum ada tugas',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tugas harian otomatis dibuat dari langkah penanganan dan '
            'pencegahan yang diberikan AI setelah kamu mendiagnosa tanaman.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
