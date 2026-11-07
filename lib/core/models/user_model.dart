class UserModel {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String? learningStyle; // visual, auditory, kinesthetic, reading
  final String? studyGoal;
  final DateTime? examDate;
  final List<String> subjects;
  final String preferredStudyTime; // morning, afternoon, evening, night
  final DateTime createdAt;
  final DateTime lastActive;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.learningStyle,
    this.studyGoal,
    this.examDate,
    this.subjects = const [],
    this.preferredStudyTime = 'morning',
    required this.createdAt,
    required this.lastActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatarUrl': avatarUrl,
      'learningStyle': learningStyle,
      'studyGoal': studyGoal,
      'examDate': examDate?.toIso8601String(),
      'subjects': subjects,
      'preferredStudyTime': preferredStudyTime,
      'createdAt': createdAt.toIso8601String(),
      'lastActive': lastActive.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserModel(
      id: docId,
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? '',
      avatarUrl: map['avatarUrl'] as String?,
      learningStyle: map['learningStyle'] as String?,
      studyGoal: map['studyGoal'] as String?,
      examDate: map['examDate'] != null ? DateTime.tryParse(map['examDate']) : null,
      subjects: List<String>.from(map['subjects'] ?? const []),
      preferredStudyTime: map['preferredStudyTime'] as String? ?? 'morning',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      lastActive: map['lastActive'] != null
          ? DateTime.tryParse(map['lastActive']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  UserModel copyWith({
    String? name,
    String? avatarUrl,
    String? learningStyle,
    String? studyGoal,
    DateTime? examDate,
    List<String>? subjects,
    String? preferredStudyTime,
    DateTime? lastActive,
  }) {
    return UserModel(
      id: id,
      email: email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      learningStyle: learningStyle ?? this.learningStyle,
      studyGoal: studyGoal ?? this.studyGoal,
      examDate: examDate ?? this.examDate,
      subjects: subjects ?? this.subjects,
      preferredStudyTime: preferredStudyTime ?? this.preferredStudyTime,
      createdAt: createdAt,
      lastActive: lastActive ?? this.lastActive,
    );
  }
}
