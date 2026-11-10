import 'package:hive_flutter/hive_flutter.dart';

/// Offline Cache Service powered by Hive.
/// Persists real student profiles, notebooks, uploaded document text, quizzes,
/// flashcards, study plans, and study analytics locally.
class OfflineCacheService {
  static const String flashcardsBox = 'offline_flashcards';
  static const String studyPlanBox = 'offline_study_plan';
  static const String notebooksBox = 'offline_notebooks';
  static const String quizzesBox = 'offline_quizzes';
  static const String notesBox = 'offline_notes';
  static const String userProfileBox = 'user_profile';
  static const String analyticsBox = 'analytics_data';

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
    await Hive.openBox(analyticsBox);
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
      'email': email.trim().isEmpty ? 'student@trueme.app' : email.trim(),
      'subjects': subjects ?? current['subjects'] ?? <String>[],
      'learningStyle': learningStyle ?? current['learningStyle'] ?? 'Visual & Practice',
      'targetExamDate': (targetExamDate ??
              DateTime.tryParse(current['targetExamDate']?.toString() ?? '') ??
              DateTime.now().add(const Duration(days: 30)))
          .toIso8601String(),
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
      'email': 'student@trueme.app',
      'subjects': <String>[],
      'learningStyle': 'Visual & Practice',
      'targetExamDate': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
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
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return 'Student';
  }

  static String getUserEmail() {
    final profile = getUserProfile();
    return (profile['email'] as String?) ?? 'student@trueme.app';
  }

  static List<String> getUserSubjects() {
    final profile = getUserProfile();
    final subs = profile['subjects'];
    if (subs is List) return subs.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    return <String>[];
  }

  static DateTime getTargetExamDate() {
    final profile = getUserProfile();
    final d = profile['targetExamDate'] as String?;
    if (d != null) {
      final parsed = DateTime.tryParse(d);
      if (parsed != null) return parsed;
    }
    return DateTime.now().add(const Duration(days: 30));
  }

  static Future<void> saveTargetExamDate(DateTime date) async {
    final profile = getUserProfile();
    await saveUserProfile(
      name: profile['name'] ?? 'Student',
      email: profile['email'] ?? 'student@trueme.app',
      subjects: (profile['subjects'] as List?)?.cast<String>(),
      learningStyle: profile['learningStyle'],
      targetExamDate: date,
    );
  }

  static Future<void> saveDriveStatus(bool connected, {String? email}) async {
    final box = Hive.box(userProfileBox);
    await box.put('drive_connected', connected);
    if (email != null) {
      await box.put('drive_email', email);
    }
  }

  static bool isDriveConnected() {
    try {
      return Hive.box(userProfileBox).get('drive_connected') == true;
    } catch (_) {
      return false;
    }
  }

  static String? getDriveEmail() {
    try {
      return Hive.box(userProfileBox).get('drive_email') as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveThemeMode(String mode) async {
    final box = Hive.box(userProfileBox);
    await box.put('theme_mode', mode);
  }

  static String getThemeMode() {
    try {
      return (Hive.box(userProfileBox).get('theme_mode') as String?) ?? 'Light';
    } catch (_) {
      return 'Light';
    }
  }

  static Future<void> logout() async {
    final box = Hive.box(userProfileBox);
    final profile = getUserProfile();
    profile['isLoggedIn'] = false;
    await box.put('current_user', profile);
  }

  // ---------------------------------------------------------------------------
  // NOTEBOOK & DOCUMENT CACHING
  // ---------------------------------------------------------------------------
  static Future<void> cacheNotebook(String notebookId, Map<String, dynamic> notebookMap) async {
    final box = Hive.box(notebooksBox);
    await box.put(notebookId, notebookMap);
  }

  static Map<String, dynamic>? getCachedNotebook(String notebookId) {
    final box = Hive.box(notebooksBox);
    final data = box.get(notebookId);
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  static Future<void> deleteNotebook(String notebookId) async {
    final box = Hive.box(notebooksBox);
    await box.delete(notebookId);
  }

  static Future<void> renameNotebook(String notebookId, String newTitle) async {
    final box = Hive.box(notebooksBox);
    final nb = getCachedNotebook(notebookId);
    if (nb != null && newTitle.trim().isNotEmpty) {
      nb['title'] = newTitle.trim();
      nb['subject'] = newTitle.trim();
      nb['lastModified'] = DateTime.now().toIso8601String();
      await box.put(notebookId, nb);
    }
  }

  static Future<Map<String, dynamic>> createNotebook({
    required String title,
    required String subject,
    List<String>? tags,
    int? colorValue,
  }) async {
    final box = Hive.box(notebooksBox);
    // Avoid duplicates with the same title
    final existing = getAllCachedNotebooks().where(
      (n) => (n['title'] as String? ?? '').toLowerCase() == title.trim().toLowerCase(),
    );
    if (existing.isNotEmpty) {
      return existing.first;
    }

    final id = 'nb_${DateTime.now().millisecondsSinceEpoch}_${title.hashCode.abs()}';
    final nb = {
      'id': id,
      'userId': 'current_user',
      'title': title.trim(),
      'subject': subject.trim(),
      'colorValue': colorValue ?? 0xFF2563EB,
      'tags': tags ?? [subject],
      'fileRefs': <String>[],
      'documents': <Map<String, dynamic>>[],
      'createdAt': DateTime.now().toIso8601String(),
      'lastModified': DateTime.now().toIso8601String(),
    };
    await box.put(id, nb);

    // Ensure subject is also in user subjects list
    final currentSubs = getUserSubjects();
    if (!currentSubs.any((s) => s.toLowerCase() == subject.trim().toLowerCase())) {
      currentSubs.add(subject.trim());
      final prof = getUserProfile();
      await saveUserProfile(
        name: prof['name'] ?? 'Student',
        email: prof['email'] ?? 'student@trueme.app',
        subjects: currentSubs,
      );
    }
    return nb;
  }

  static Future<void> addDocumentToNotebook(String notebookId, Map<String, dynamic> doc) async {
    final box = Hive.box(notebooksBox);
    final nb = getCachedNotebook(notebookId);
    if (nb != null) {
      final rawDocs = nb['documents'] as List? ?? [];
      final docs = rawDocs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final docMap = Map<String, dynamic>.from(doc);
      docMap['id'] ??= 'doc_${DateTime.now().millisecondsSinceEpoch}';
      docMap['createdAt'] ??= DateTime.now().toIso8601String();
      docs.add(docMap);

      final refs = List<String>.from(nb['fileRefs'] ?? []);
      final fName = docMap['fileName'] as String? ?? '';
      if (fName.isNotEmpty && !refs.contains(fName)) refs.add(fName);

      nb['documents'] = docs;
      nb['fileRefs'] = refs;
      nb['lastModified'] = DateTime.now().toIso8601String();
      await box.put(notebookId, nb);
    }
  }

  static Future<void> removeDocumentFromNotebook(String notebookId, String docId) async {
    final box = Hive.box(notebooksBox);
    final nb = getCachedNotebook(notebookId);
    if (nb != null) {
      final rawDocs = nb['documents'] as List? ?? [];
      final docs = rawDocs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      docs.removeWhere((d) => d['id'] == docId);
      nb['documents'] = docs;
      nb['fileRefs'] = docs.map((d) => (d['fileName'] as String? ?? '')).where((s) => s.isNotEmpty).toList();
      nb['lastModified'] = DateTime.now().toIso8601String();
      await box.put(notebookId, nb);
    }
  }

  static List<Map<String, dynamic>> getNotebookDocuments(String notebookId, {String? section}) {
    final nb = getCachedNotebook(notebookId);
    if (nb == null) return [];
    final rawDocs = nb['documents'] as List? ?? [];
    final docs = rawDocs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (section != null) {
      return docs.where((d) => (d['section'] as String? ?? 'Notes') == section).toList();
    }
    return docs;
  }

  static String getNotebookCombinedText(String notebookId, {int maxChars = 24000}) {
    final buffer = StringBuffer();
    final docs = getNotebookDocuments(notebookId);
    for (final d in docs) {
      final name = d['fileName'] ?? 'Source';
      final section = d['section'] ?? 'Notes';
      final content = (d['content'] as String? ?? '').trim();
      if (content.isNotEmpty) {
        buffer.writeln('--- [$section: $name] ---');
        buffer.writeln(content);
        buffer.writeln();
      }
    }

    // Also include notes linked to this notebook
    final notes = getAllCachedNotes().where((n) => n['notebookId'] == notebookId);
    for (final n in notes) {
      final title = n['title'] ?? 'Note';
      final content = (n['content'] as String? ?? '').trim();
      if (content.isNotEmpty) {
        buffer.writeln('--- [Note: $title] ---');
        buffer.writeln(content);
        buffer.writeln();
      }
    }

    final result = buffer.toString();
    if (result.length > maxChars) {
      return result.substring(0, maxChars);
    }
    return result;
  }

  static List<Map<String, dynamic>> getAllCachedNotebooks() {
    final box = Hive.box(notebooksBox);
    return box.values
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // DAILY STUDY PLAN CACHING
  // ---------------------------------------------------------------------------
  static String dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

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

  static Future<void> deleteDeck(String deckId) async {
    final box = Hive.box(flashcardsBox);
    await box.delete(deckId);
  }

  static List<Map<String, dynamic>> getAllCachedDecks() {
    final box = Hive.box(flashcardsBox);
    return box.values
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // QUIZ CACHING & RESULTS ANALYTICS
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

  static Future<void> saveQuizAttempt({
    required String id,
    required String subject,
    required String topic,
    required int score,
    required int total,
    required List<String> missedTopics,
  }) async {
    final box = Hive.box(analyticsBox);
    final raw = box.get('quiz_attempts') as List? ?? [];
    final attempts = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    attempts.insert(0, {
      'id': id,
      'subject': subject,
      'topic': topic.isNotEmpty ? topic : subject,
      'score': score,
      'total': total,
      'percentage': total > 0 ? ((score / total) * 100).round() : 0,
      'missedTopics': missedTopics,
      'timestamp': DateTime.now().toIso8601String(),
    });

    if (attempts.length > 50) attempts.removeRange(50, attempts.length);
    await box.put('quiz_attempts', attempts);

    await logStudySession(
      activity: 'quiz',
      subject: subject,
      title: topic.isNotEmpty ? '$topic quiz' : '$subject quiz',
      subtitle: 'Score: $score/$total',
      minutes: (total * 1.5).round().clamp(3, 45),
    );
  }

  static List<Map<String, dynamic>> getQuizAttempts() {
    try {
      final box = Hive.box(analyticsBox);
      final raw = box.get('quiz_attempts') as List? ?? [];
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static List<Map<String, dynamic>> getWeakTopics() {
    final attempts = getQuizAttempts();
    if (attempts.isEmpty) return [];

    final Map<String, List<int>> topicScores = {};
    for (final a in attempts) {
      final topic = (a['topic'] as String? ?? a['subject'] as String? ?? 'General').trim();
      final pct = (a['percentage'] as num?)?.toInt() ?? 0;
      topicScores.putIfAbsent(topic, () => []).add(pct);
    }

    final List<Map<String, dynamic>> weak = [];
    topicScores.forEach((topic, scores) {
      final avg = (scores.reduce((a, b) => a + b) / scores.length).round();
      if (avg < 80) {
        weak.add({'topic': topic, 'score': avg});
      }
    });

    weak.sort((a, b) => (a['score'] as int).compareTo(b['score'] as int));
    return weak.take(4).toList();
  }

  // ---------------------------------------------------------------------------
  // STUDY ACTIVITY, STREAK & RECENT SESSIONS
  // ---------------------------------------------------------------------------
  static Future<void> logStudySession({
    required String activity, // 'quiz', 'flashcards', 'voice', 'task'
    required String subject,
    required String title,
    String? subtitle,
    required int minutes,
  }) async {
    final box = Hive.box(analyticsBox);
    final todayStr = dateKey(DateTime.now());

    // 1. Add minutes to today's log
    final rawDaily = box.get('daily_minutes') as Map? ?? {};
    final daily = Map<String, int>.from(
      rawDaily.map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
    );
    daily[todayStr] = (daily[todayStr] ?? 0) + minutes;
    await box.put('daily_minutes', daily);

    // 2. Add to recent practice sessions (unless it's just a task checkbox)
    if (activity != 'task') {
      final rawRecent = box.get('recent_sessions') as List? ?? [];
      final recent = rawRecent.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      recent.insert(0, {
        'activity': activity,
        'subject': subject,
        'title': title,
        'subtitle': subtitle ?? '$minutes min',
        'timestamp': DateTime.now().toIso8601String(),
      });
      if (recent.length > 20) recent.removeRange(20, recent.length);
      await box.put('recent_sessions', recent);
    }
  }

  /// Returns Mon..Sun minutes for the current week.
  static List<int> getWeeklyStudyMinutes() {
    try {
      final box = Hive.box(analyticsBox);
      final rawDaily = box.get('daily_minutes') as Map? ?? {};
      final now = DateTime.now();
      // Monday = 1, Sunday = 7
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final List<int> week = [];
      for (int i = 0; i < 7; i++) {
        final d = monday.add(Duration(days: i));
        final key = dateKey(d);
        final val = rawDaily[key];
        week.add(val is num ? val.toInt() : 0);
      }
      return week;
    } catch (_) {
      return [0, 0, 0, 0, 0, 0, 0];
    }
  }

  static int getTotalWeeklyMinutes() {
    return getWeeklyStudyMinutes().fold<int>(0, (sum, m) => sum + m);
  }

  static int getCurrentStreak() {
    try {
      final box = Hive.box(analyticsBox);
      final rawDaily = box.get('daily_minutes') as Map? ?? {};
      if (rawDaily.isEmpty) return 0;

      int streak = 0;
      DateTime checkDay = DateTime.now();
      // If nothing logged today yet, check starting from yesterday
      if ((rawDaily[dateKey(checkDay)] as num? ?? 0) == 0) {
        checkDay = checkDay.subtract(const Duration(days: 1));
      }

      while (true) {
        final key = dateKey(checkDay);
        final mins = (rawDaily[key] as num? ?? 0).toInt();
        if (mins > 0) {
          streak++;
          checkDay = checkDay.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
      return streak;
    } catch (_) {
      return 0;
    }
  }

  static List<Map<String, dynamic>> getRecentPracticeSessions() {
    try {
      final box = Hive.box(analyticsBox);
      final raw = box.get('recent_sessions') as List? ?? [];
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
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
    await Hive.box(analyticsBox).clear();
  }
}
