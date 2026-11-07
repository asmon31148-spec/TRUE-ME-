class StudySessionPlanItem {
  final String id;
  final String subject;
  final String topic;
  final String activityType; // flashcards, quiz, chat, reading, explainer
  final int targetMinutes;
  final bool isCompleted;

  const StudySessionPlanItem({
    required this.id,
    required this.subject,
    required this.topic,
    required this.activityType,
    required this.targetMinutes,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject': subject,
      'topic': topic,
      'activityType': activityType,
      'targetMinutes': targetMinutes,
      'isCompleted': isCompleted,
    };
  }

  factory StudySessionPlanItem.fromMap(Map<String, dynamic> map) {
    return StudySessionPlanItem(
      id: map['id'] as String? ?? '',
      subject: map['subject'] as String? ?? '',
      topic: map['topic'] as String? ?? '',
      activityType: map['activityType'] as String? ?? 'reading',
      targetMinutes: (map['targetMinutes'] as num?)?.toInt() ?? 25,
      isCompleted: map['isCompleted'] as bool? ?? false,
    );
  }

  StudySessionPlanItem copyWith({bool? isCompleted}) {
    return StudySessionPlanItem(
      id: id,
      subject: subject,
      topic: topic,
      activityType: activityType,
      targetMinutes: targetMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class DailyStudyPlanModel {
  final String date; // YYYY-MM-DD
  final String userId;
  final List<StudySessionPlanItem> sessions;
  final int totalTargetMinutes;
  final String motivationalMessage;
  final bool completed;
  final DateTime createdAt;

  const DailyStudyPlanModel({
    required this.date,
    required this.userId,
    required this.sessions,
    required this.totalTargetMinutes,
    required this.motivationalMessage,
    this.completed = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'userId': userId,
      'sessions': sessions.map((s) => s.toMap()).toList(),
      'totalTargetMinutes': totalTargetMinutes,
      'motivationalMessage': motivationalMessage,
      'completed': completed,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DailyStudyPlanModel.fromMap(Map<String, dynamic> map, String date) {
    final rawSessions = map['sessions'] as List<dynamic>? ?? [];
    return DailyStudyPlanModel(
      date: date,
      userId: map['userId'] as String? ?? '',
      sessions: rawSessions
          .map((s) => StudySessionPlanItem.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
      totalTargetMinutes: (map['totalTargetMinutes'] as num?)?.toInt() ?? 60,
      motivationalMessage: map['motivationalMessage'] as String? ?? 'Ready to conquer today?',
      completed: map['completed'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
