import 'package:flutter/material.dart';

import '../models/diagnosis_result.dart';

class DiagnosisResultCard extends StatelessWidget {
  final DiagnosisResult result;

  const DiagnosisResultCard({super.key, required this.result});

  static const _green = Color(0xFF2F6B4F);
  static const _red = Color(0xFFE05252);
  static const _amber = Color(0xFFD99A2B);

  bool get _isUncertain =>
      result.confidence == 0 ||
      result.diseaseName.toLowerCase().contains('tidak dapat');

  Color get _accent {
    if (result.isHealthy) return _green;
    if (_isUncertain) return _amber;
    return _red;
  }

  IconData get _headerIcon {
    if (result.isHealthy) return Icons.verified_outlined;
    if (_isUncertain) return Icons.help_outline;
    return Icons.warning_amber_rounded;
  }

  String get _statusLabel {
    if (result.isHealthy) return 'SEHAT';
    if (_isUncertain) return 'BELUM YAKIN';
    return 'PERLU PERHATIAN';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = _accent;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.15),
                Colors.white,
                Colors.white,
              ],
              stops: const [0, 0.35, 1],
            ),
            border: Border.all(
              color: accent.withValues(alpha: 0.22),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(_headerIcon, color: accent, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StatusPill(label: _statusLabel, color: accent),
                          const SizedBox(height: 7),
                          Text(
                            result.plantName,
                            style: textTheme.labelMedium?.copyWith(
                              color: Colors.black45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            result.diseaseName,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1F2A24),
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _ConfidenceGauge(
                      confidence: result.confidence,
                      color: accent,
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: accent.withValues(alpha: 0.12)),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (result.summary.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.format_quote_rounded,
                              size: 18,
                              color: accent.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                result.summary,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (result.symptoms.isNotEmpty)
                      _Section(
                        title: 'Gejala yang Terlihat',
                        icon: Icons.visibility_outlined,
                        items: result.symptoms,
                      ),
                    if (result.causes.isNotEmpty)
                      _Section(
                        title: 'Kemungkinan Penyebab',
                        icon: Icons.help_outline,
                        items: result.causes,
                      ),
                    if (result.treatment.isNotEmpty)
                      _Section(
                        title: 'Langkah Penanganan',
                        icon: Icons.healing_outlined,
                        items: result.treatment,
                        numbered: true,
                      ),
                    if (result.prevention.isNotEmpty)
                      _Section(
                        title: 'Pencegahan',
                        icon: Icons.shield_outlined,
                        items: result.prevention,
                      ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F4F1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.black45,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Hasil ini perkiraan AI, bukan diagnosis pasti. '
                              'Konsultasikan ke ahli jika gejala berlanjut.',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color: Colors.black45,
                              ),
                            ),
                          ),
                        ],
                      ),
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

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceGauge extends StatelessWidget {
  final int confidence;
  final Color color;

  const _ConfidenceGauge({required this.confidence, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 68,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: confidence / 100),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return SizedBox(
                width: 68,
                height: 68,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 6.5,
                  strokeCap: StrokeCap.round,
                  backgroundColor: color.withValues(alpha: 0.14),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              );
            },
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$confidence%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.1,
                ),
              ),
              const Text(
                'yakin',
                style: TextStyle(fontSize: 9, color: Colors.black38),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final bool numbered;

  const _Section({
    required this.title,
    required this.icon,
    required this.items,
    this.numbered = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: DiagnosisResultCard._green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  icon,
                  size: 15,
                  color: DiagnosisResultCard._green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: DiagnosisResultCard._green,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: DiagnosisResultCard._green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${items.length}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: DiagnosisResultCard._green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == items.length - 1 ? 0 : 8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (numbered)
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        color: DiagnosisResultCard._green.withValues(
                          alpha: 0.12,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: DiagnosisResultCard._green,
                          ),
                        ),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(top: 1, left: 4),
                      child: Text(
                        '\u2022',
                        style: TextStyle(fontSize: 14, color: Colors.black45),
                      ),
                    ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      items[i],
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
