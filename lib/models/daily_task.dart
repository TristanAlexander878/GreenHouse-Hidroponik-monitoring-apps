/// Jenis tugas harian yang diturunkan dari hasil diagnosa AI.
enum TaskCategory { treatment, prevention }

/// Satu tugas harian. Tugas penanganan dibuat sekali saat diagnosa, sedangkan
/// tugas pencegahan diulang setiap hari selama riwayat masih ada.
class DailyTask {
  final String id;
  final String recordId;
  final String title;
  final String detail;
  final String sourceDisease;
  final TaskCategory category;
  final bool repeatDaily;
  final DateTime date;
  bool done;

  DailyTask({
    required this.id,
    required this.recordId,
    required this.title,
    required this.detail,
    required this.sourceDisease,
    required this.category,
    required this.repeatDaily,
    required this.date,
    this.done = false,
  });

  String get dateKey => dateKeyOf(date);

  static String dateKeyOf(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recordId': recordId,
      'title': title,
      'detail': detail,
      'sourceDisease': sourceDisease,
      'category': category.name,
      'repeatDaily': repeatDaily,
      'date': date.toIso8601String(),
      'done': done,
    };
  }

  factory DailyTask.fromJson(Map<String, dynamic> json) {
    final categoryName = json['category']?.toString();
    return DailyTask(
      id: json['id']?.toString() ?? '',
      recordId: json['recordId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      detail: json['detail']?.toString() ?? '',
      sourceDisease: json['sourceDisease']?.toString() ?? '',
      category: categoryName == TaskCategory.prevention.name
          ? TaskCategory.prevention
          : TaskCategory.treatment,
      repeatDaily: json['repeatDaily'] == true,
      date:
          DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      done: json['done'] == true,
    );
  }
}
