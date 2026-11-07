class StudySessionModel {
  final String id;
  final String userId;
  final String subject;
  final String topic;
  final String sessionType; // flashcard, quiz, chat, voice_tutor, explainer
  final int durationMinutes;
  final double? score;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const StudySessionModel({
    required this.id,
    required this.userId,
    required this.subject,
    required this.topic,
    required this.sessionType,
    required this.durationMinutes,
    this.score,
    this.metadata = const {},
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'subject': subject,
      'topic': topic,
      'session_type': sessionType,
      'duration_min': durationMinutes,
      'score': score,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory StudySessionModel.fromMap(Map<String, dynamic> map) {
    return StudySessionModel(
      id: map['id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      subject: map['subject'] as String? ?? '',
      topic: map['topic'] as String? ?? '',
      sessionType: map['session_type'] as String? ?? 'general',
      durationMinutes: (map['duration_min'] as num?)?.toInt() ?? 0,
      score: (map['score'] as num?)?.toDouble(),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? const {}),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
