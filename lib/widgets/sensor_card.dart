import 'package:flutter/material.dart';

import '../models/sensor_reading.dart';

class SensorCard extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final IconData icon;
  final SensorStatus status;
  final int decimals;

  const SensorCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.status,
    this.decimals = 1,
  });

  Color get _statusColor {
    switch (status) {
      case SensorStatus.critical:
        return const Color(0xFFE05252);
      case SensorStatus.warning:
        return const Color(0xFFE0A852);
      case SensorStatus.normal:
        return const Color(0xFF4CAF7D);
    }
  }

  String get _statusLabel {
    switch (status) {
      case SensorStatus.critical:
        return 'Kritis';
      case SensorStatus.warning:
        return 'Perhatian';
      case SensorStatus.normal:
        return 'Normal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, color.withValues(alpha: 0.06)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _statusLabel,
                        maxLines: 1,
                        style: textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: value, end: value),
                    duration: const Duration(milliseconds: 500),
                    builder: (context, animatedValue, _) {
                      return Text(
                        animatedValue.toStringAsFixed(decimals),
                        maxLines: 1,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                          letterSpacing: -0.5,
                        ),
                      );
                    },
                  ),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      maxLines: 1,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
