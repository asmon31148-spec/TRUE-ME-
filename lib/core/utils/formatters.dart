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
    final diff = examDate.difference(DateTime.now()).inDays;
    if (diff <= 0) return 'Exam Day Today!';
    if (diff == 1) return 'Exam Tomorrow!';
    return '$diff days until Exam';
  }
}
