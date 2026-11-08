import 'package:hive_flutter/hive_flutter.dart';

/// Offline Cache Service powered by Hive.
/// Allows students to review flashcards, take quizzes, view daily study plans,
/// and edit notes seamlessly even without Wi-Fi / cellular connectivity.
class OfflineCacheService {
  static const String flashcardsBox = 'offline_flashcards';
  static const String studyPlanBox = 'offline_study_plan';
  static const String notebooksBox = 'offline_notebooks';
  static const String quizzesBox = 'offline_quizzes';
  static const String notesBox = 'offline_notes';
  static const String userProfileBox = 'user_profile';

  static bool _isInitialized = false;

  /// Initializes Hive storage boxes for offline study.
  static Future<void> initialize() async {
    if (_isInitialized) return;
    await Hive.initFlutter();
    await Hive.openBox(flashcardsBox);
    await Hive.openBox(studyPlanBox);
    await Hive.openBox(notebooksBox);
    await Hive.openBox(quizzesBox);
    await Hive.openBox(notesBox);
    await Hive.openBox(userProfileBox);
    _isInitialized = true;
  }

  // ---------------------------------------------------------------------------
  // USER PROFILE & AUTH CACHING
  // ---------------------------------------------------------------------------
  static Future<void> saveUserProfile({
    required String name,
    required String email,
    List<String>? subjects,
    String? learningStyle,
    DateTime? targetExamDate,
    bool isLoggedIn = true,
    bool hasCompletedOnboarding = true,
  }) async {
    final box = Hive.box(userProfileBox);
    final current = getUserProfile();
    final updated = {
      ...current,
      'name': name.trim().isEmpty ? 'Student' : name.trim(),
      'email': email.trim().isEmpty ? 'student@trueme.ai' : email.trim(),
      'subjects': subjects ?? current['subjects'] ?? ['Computer Science', 'Calculus'],
      'learningStyle': learningStyle ?? current['learningStyle'] ?? 'Visual (Diagrams & Videos)',
      'targetExamDate': (targetExamDate ?? DateTime.now().add(const Duration(days: 45))).toIso8601String(),
      'isLoggedIn': isLoggedIn,
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await box.put('current_user', updated);
  }

  static Map<String, dynamic> getUserProfile() {
    try {
      final box = Hive.box(userProfileBox);
      final data = box.get('current_user');
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    return {
      'name': 'Student',
      'email': 'student@trueme.ai',
      'subjects': <String>['Computer Science', 'Calculus', 'Physics'],
      'learningStyle': 'Visual (Diagrams & Videos)',
      'targetExamDate': DateTime.now().add(const Duration(days: 45)).toIso8601String(),
      'isLoggedIn': false,
      'hasCompletedOnboarding': false,
    };
  }

  static bool hasCompletedOnboarding() {
    try {
      final box = Hive.box(userProfileBox);
      final data = box.get('current_user');
      if (data is Map && data['hasCompletedOnboarding'] == true) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  static bool isLoggedIn() {
    try {
      final box = Hive.box(userProfileBox);
      final data = box.get('current_user');
      if (data is Map && data['isLoggedIn'] == true) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  static String getUserName() {
    final profile = getUserProfile();
    final name = (profile['name'] as String?)?.trim();
    if (name != null && name.isNotEmpty && name != 'Alex') {
      return name;
    }
    return 'Student';
  }

  static String getUserEmail() {
    final profile = getUserProfile();
    return (profile['email'] as String?) ?? 'student@trueme.ai';
  }

  static List<String> getUserSubjects() {
    final profile = getUserProfile();
    final subs = profile['subjects'];
    if (subs is List) return subs.map((e) => e.toString()).toList();
    return ['Computer Science', 'Calculus', 'Physics'];
  }

  static DateTime getTargetExamDate() {
    final profile = getUserProfile();
    final d = profile['targetExamDate'] as String?;
    if (d != null) {
      final parsed = DateTime.tryParse(d);
      if (parsed != null) return parsed;
    }
    return DateTime.now().add(const Duration(days: 45));
  }

  static Future<void> logout() async {
    final box = Hive.box(userProfileBox);
    final profile = getUserProfile();
    profile['isLoggedIn'] = false;
    await box.put('current_user', profile);
  }

  // ---------------------------------------------------------------------------
  // DAILY STUDY PLAN CACHING
  // ---------------------------------------------------------------------------
  static Future<void> cacheStudyPlan(String date, Map<String, dynamic> planMap) async {
    final box = Hive.box(studyPlanBox);
    await box.put(date, planMap);
  }

  static Map<String, dynamic>? getCachedStudyPlan(String date) {
    final box = Hive.box(studyPlanBox);
    final data = box.get(date);
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  // ---------------------------------------------------------------------------
  // FLASHCARD DECK CACHING
  // ---------------------------------------------------------------------------
  static Future<void> cacheDeck(String deckId, Map<String, dynamic> deckMap) async {
    final box = Hive.box(flashcardsBox);
    await box.put(deckId, deckMap);
  }

  static Map<String, dynamic>? getCachedDeck(String deckId) {
    final box = Hive.box(flashcardsBox);
    final data = box.get(deckId);
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  static List<Map<String, dynamic>> getAllCachedDecks() {
    final box = Hive.box(flashcardsBox);
    return box.values
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // QUIZ CACHING
  // ---------------------------------------------------------------------------
  static Future<void> cacheQuiz(String quizId, Map<String, dynamic> quizMap) async {
    final box = Hive.box(quizzesBox);
    await box.put(quizId, quizMap);
  }

  static Map<String, dynamic>? getCachedQuiz(String quizId) {
    final box = Hive.box(quizzesBox);
    final data = box.get(quizId);
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  // ---------------------------------------------------------------------------
  // NOTE & DOCUMENT CACHING
  // ---------------------------------------------------------------------------
  static Future<void> cacheNote(String noteId, Map<String, dynamic> noteMap) async {
    final box = Hive.box(notesBox);
    await box.put(noteId, noteMap);
  }

  static Map<String, dynamic>? getCachedNote(String noteId) {
    final box = Hive.box(notesBox);
    final data = box.get(noteId);
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  static List<Map<String, dynamic>> getAllCachedNotes() {
    final box = Hive.box(notesBox);
    return box.values
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // CACHE MAINTENANCE
  // ---------------------------------------------------------------------------
  static Future<void> clearAllCache() async {
    await Hive.box(flashcardsBox).clear();
    await Hive.box(studyPlanBox).clear();
    await Hive.box(notebooksBox).clear();
    await Hive.box(quizzesBox).clear();
    await Hive.box(notesBox).clear();
  }
}
