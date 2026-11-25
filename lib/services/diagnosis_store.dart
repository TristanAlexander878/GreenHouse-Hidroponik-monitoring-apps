import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_task.dart';
import '../models/diagnosis_record.dart';
import '../models/diagnosis_result.dart';

/// Penyimpanan riwayat diagnosa dan tugas harian.
///
/// Data disimpan lokal lewat [SharedPreferences] supaya tetap ada setelah
/// aplikasi ditutup. Semua layar mendengarkan instance yang sama sehingga
/// riwayat dan tugas langsung ter-update tanpa perlu refresh manual.
class DiagnosisStore extends ChangeNotifier {
  DiagnosisStore._();

  static final DiagnosisStore instance = DiagnosisStore._();

  static const String _historyKey = 'diagnosis_history_v1';
  static const String _tasksKey = 'daily_tasks_v1';

  final List<DiagnosisRecord> _history = [];
  final List<DailyTask> _tasks = [];

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Riwayat terbaru di urutan paling atas.
  List<DiagnosisRecord> get history => List.unmodifiable(_history);

  List<DailyTask> get allTasks => List.unmodifiable(_tasks);

  List<DailyTask> tasksFor(DateTime day) {
    final key = DailyTask.dateKeyOf(day);
    final list = _tasks.where((task) => task.dateKey == key).toList();
    list.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      if (a.category != b.category) {
        return a.category == TaskCategory.treatment ? -1 : 1;
      }
      return 0;
    });
    return list;
  }

  List<DailyTask> get todayTasks => tasksFor(DateTime.now());

  int get todayDoneCount => todayTasks.where((task) => task.done).length;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      final historyRaw = prefs.getString(_historyKey);
      if (historyRaw != null && historyRaw.isNotEmpty) {
        final decoded = jsonDecode(historyRaw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              _history.add(
                DiagnosisRecord.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              );
            }
          }
        }
      }

      final tasksRaw = prefs.getString(_tasksKey);
      if (tasksRaw != null && tasksRaw.isNotEmpty) {
        final decoded = jsonDecode(tasksRaw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              _tasks.add(
                DailyTask.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              );
            }
          }
        }
      }
    } catch (error) {
      debugPrint('DiagnosisStore: gagal memuat data lokal: $error');
    }

    _loaded = true;
    await _ensureTodayPreventionTasks();
    notifyListeners();
  }

  /// Simpan hasil diagnosa baru lalu buat tugas harian dari solusi AI.
  Future<DiagnosisRecord> addDiagnosis(DiagnosisResult result) async {
    final record = DiagnosisRecord.fromResult(result);
    _history.insert(0, record);
    _tasks.addAll(_buildTasks(record, DateTime.now(), includeTreatment: true));
    notifyListeners();
    await _persist();
    return record;
  }

  Future<void> toggleTask(String id) async {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index == -1) return;
    _tasks[index].done = !_tasks[index].done;
    notifyListeners();
    await _persist();
  }

  Future<void> deleteRecord(String id) async {
    _history.removeWhere((record) => record.id == id);
    _tasks.removeWhere((task) => task.recordId == id);
    notifyListeners();
    await _persist();
  }

  Future<void> clearAll() async {
    _history.clear();
    _tasks.clear();
    notifyListeners();
    await _persist();
  }

  /// Pastikan tugas pencegahan untuk hari ini sudah dibuat. Dipanggil saat
  /// aplikasi dibuka dan saat layar tugas ditampilkan (mis. lewat tengah malam).
  Future<void> refreshForToday() async {
    await _ensureTodayPreventionTasks();
    notifyListeners();
  }

  List<DailyTask> _buildTasks(
    DiagnosisRecord record,
    DateTime day, {
    required bool includeTreatment,
  }) {
    final tasks = <DailyTask>[];
    final key = DailyTask.dateKeyOf(day);

    if (includeTreatment) {
      for (var i = 0; i < record.result.treatment.length; i++) {
        tasks.add(
          DailyTask(
            id: '${record.id}-treat-$i-$key',
            recordId: record.id,
            title: record.result.treatment[i],
            detail: 'Langkah penanganan untuk ${record.result.diseaseName}',
            sourceDisease: record.result.diseaseName,
            category: TaskCategory.treatment,
            repeatDaily: false,
            date: day,
          ),
        );
      }
    }

    for (var i = 0; i < record.result.prevention.length; i++) {
      tasks.add(
        DailyTask(
          id: '${record.id}-prev-$i-$key',
          recordId: record.id,
          title: record.result.prevention[i],
          detail: 'Pencegahan rutin untuk ${record.result.diseaseName}',
          sourceDisease: record.result.diseaseName,
          category: TaskCategory.prevention,
          repeatDaily: true,
          date: day,
        ),
      );
    }

    return tasks;
  }

  Future<void> _ensureTodayPreventionTasks() async {
    final today = DateTime.now();
    final key = DailyTask.dateKeyOf(today);
    var changed = false;

    for (final record in _history) {
      for (var i = 0; i < record.result.prevention.length; i++) {
        final id = '${record.id}-prev-$i-$key';
        if (_tasks.any((task) => task.id == id)) continue;
        _tasks.add(
          DailyTask(
            id: id,
            recordId: record.id,
            title: record.result.prevention[i],
            detail: 'Pencegahan rutin untuk ${record.result.diseaseName}',
            sourceDisease: record.result.diseaseName,
            category: TaskCategory.prevention,
            repeatDaily: true,
            date: today,
          ),
        );
        changed = true;
      }
    }

    if (changed) await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _historyKey,
        jsonEncode(_history.map((record) => record.toJson()).toList()),
      );
      await prefs.setString(
        _tasksKey,
        jsonEncode(_tasks.map((task) => task.toJson()).toList()),
      );
    } catch (error) {
      debugPrint('DiagnosisStore: gagal menyimpan data lokal: $error');
    }
  }
}
