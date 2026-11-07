class NotebookModel {
  final String id;
  final String userId;
  final String title;
  final String subject;
  final int colorValue;
  final List<String> tags;
  final List<String> fileRefs;
  final DateTime createdAt;
  final DateTime lastModified;

  const NotebookModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.subject,
    this.colorValue = 0xFF6366F1,
    this.tags = const [],
    this.fileRefs = const [],
    required this.createdAt,
    required this.lastModified,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'subject': subject,
      'colorValue': colorValue,
      'tags': tags,
      'fileRefs': fileRefs,
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
    };
  }

  factory NotebookModel.fromMap(Map<String, dynamic> map, String docId) {
    return NotebookModel(
      id: docId,
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? 'Untitled Notebook',
      subject: map['subject'] as String? ?? 'General',
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF6366F1,
      tags: List<String>.from(map['tags'] ?? const []),
      fileRefs: List<String>.from(map['fileRefs'] ?? const []),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      lastModified: map['lastModified'] != null
          ? DateTime.tryParse(map['lastModified']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  NotebookModel copyWith({
    String? title,
    String? subject,
    int? colorValue,
    List<String>? tags,
    List<String>? fileRefs,
    DateTime? lastModified,
  }) {
    return NotebookModel(
      id: id,
      userId: userId,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      colorValue: colorValue ?? this.colorValue,
      tags: tags ?? this.tags,
      fileRefs: fileRefs ?? this.fileRefs,
      createdAt: createdAt,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}
