import 'package:flutter/material.dart';

import '../services/diagnosis_store.dart';
import '../services/disease_diagnosis_service.dart';
import '../services/sensor_service.dart';
import '../theme/app_theme.dart';
import 'daily_task_screen.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';

/// Shell utama dengan navigasi geser (swipe) kiri/kanan antar halaman:
/// Monitoring, Riwayat Diagnosa, dan Tugas Harian.
class HomeShellScreen extends StatefulWidget {
  final SensorService sensorService;
  final DiseaseDiagnosisService? diagnosisService;
  final String greenhouseName;

  const HomeShellScreen({
    super.key,
    required this.sensorService,
    this.diagnosisService,
    this.greenhouseName = 'Greenhouse 1',
  });

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  final PageController _pageController = PageController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    DiagnosisStore.instance.load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index == _index) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _index = index),
        children: [
          DashboardScreen(
            sensorService: widget.sensorService,
            diagnosisService: widget.diagnosisService,
            greenhouseName: widget.greenhouseName,
          ),
          const HistoryScreen(),
          const DailyTaskScreen(),
        ],
      ),
      bottomNavigationBar: _SwipeNavBar(
        index: _index,
        onTap: _goTo,
      ),
    );
  }
}

class _SwipeNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const _SwipeNavBar({required this.index, required this.onTap});

  static const _items = [
    _NavItem(icon: Icons.monitor_heart_outlined, activeIcon: Icons.monitor_heart, label: 'Monitoring'),
    _NavItem(icon: Icons.history_outlined, activeIcon: Icons.history, label: 'Riwayat'),
    _NavItem(icon: Icons.checklist_outlined, activeIcon: Icons.checklist, label: 'Tugas'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.outline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _NavButton(
                  item: _items[i],
                  selected: index == i,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? item.activeIcon : item.icon,
              size: 22,
              color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
