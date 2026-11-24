class AppFormatters {
  AppFormatters._();

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String formatDurationMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
  }

  static String formatExamCountdown(DateTime examDate) {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final examMidnight = DateTime(examDate.year, examDate.month, examDate.day);
    final days = examMidnight.difference(todayMidnight).inDays;
    if (days <= 0) return 'Exam Day Today!';
    if (days == 1) return 'Exam Tomorrow!';
    return '$days days until Exam';
  }
}
