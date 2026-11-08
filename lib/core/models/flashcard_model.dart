class FlashcardModel {
  final String id;
  final String front;
  final String back;
  final String? imageUrl;
  final double easeFactor; // SM-2 parameter (default 2.5)
  final int interval; // Interval in days
  final int repetitions; // Consecutive successful repetitions
  final DateTime nextReviewDate;
  final DateTime? lastReviewDate;

  const FlashcardModel({
    required this.id,
    required this.front,
    required this.back,
    this.imageUrl,
    this.easeFactor = 2.5,
    this.interval = 1,
    this.repetitions = 0,
    required this.nextReviewDate,
    this.lastReviewDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'front': front,
      'back': back,
      'imageUrl': imageUrl,
      'easeFactor': easeFactor,
      'interval': interval,
      'repetitions': repetitions,
      'nextReviewDate': nextReviewDate.toIso8601String(),
      'lastReviewDate': lastReviewDate?.toIso8601String(),
    };
  }

  factory FlashcardModel.fromMap(Map<String, dynamic> map, String id) {
    return FlashcardModel(
      id: id,
      front: map['front'] as String? ?? '',
      back: map['back'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      easeFactor: (map['easeFactor'] as num?)?.toDouble() ?? 2.5,
      interval: (map['interval'] as num?)?.toInt() ?? 1,
      repetitions: (map['repetitions'] as num?)?.toInt() ?? 0,
      nextReviewDate: map['nextReviewDate'] != null
          ? DateTime.tryParse(map['nextReviewDate']) ?? DateTime.now()
          : DateTime.now(),
      lastReviewDate: map['lastReviewDate'] != null
          ? DateTime.tryParse(map['lastReviewDate'])
          : null,
    );
  }

  FlashcardModel copyWith({
    String? front,
    String? back,
    String? imageUrl,
    double? easeFactor,
    int? interval,
    int? repetitions,
    DateTime? nextReviewDate,
    DateTime? lastReviewDate,
  }) {
    return FlashcardModel(
      id: id,
      front: front ?? this.front,
      back: back ?? this.back,
      imageUrl: imageUrl ?? this.imageUrl,
      easeFactor: easeFactor ?? this.easeFactor,
      interval: interval ?? this.interval,
      repetitions: repetitions ?? this.repetitions,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      lastReviewDate: lastReviewDate ?? this.lastReviewDate,
    );
  }
}

class FlashcardDeckModel {
  final String id;
  final String notebookId;
  final String subject;
  final String topic;
  final List<FlashcardModel> cards;
  final DateTime createdAt;

  const FlashcardDeckModel({
    required this.id,
    required this.notebookId,
    required this.subject,
    required this.topic,
    this.cards = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'notebookId': notebookId,
      'subject': subject,
      'topic': topic,
      'cards': cards.map((c) => c.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FlashcardDeckModel.fromMap(Map<String, dynamic> map, String docId) {
    final rawCards = map['cards'] as List<dynamic>? ?? [];
    return FlashcardDeckModel(
      id: docId,
      notebookId: map['notebookId'] as String? ?? '',
      subject: map['subject'] as String? ?? '',
      topic: map['topic'] as String? ?? '',
      cards: rawCards
          .map((c) => FlashcardModel.fromMap(
                Map<String, dynamic>.from(c as Map),
                c['id'] as String? ?? 'card_${DateTime.now().microsecondsSinceEpoch}',
              ))
          .toList(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
