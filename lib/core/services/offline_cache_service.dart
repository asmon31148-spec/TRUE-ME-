import 'package:hive_flutter/hive_flutter.dart';
import 'supabase_service.dart';

/// Offline-first Persistence & Cloud Sync Service powered by Hive + Supabase.
/// All writes happen instantly to Hive and synchronize asynchronously to Supabase.
class OfflineCacheService {
  static const String flashcardsBox = 'offline_flashcards';
  static const String studyPlanBox = 'offline_study_plan';
  static const String notebooksBox = 'offline_notebooks';
  static const String quizzesBox = 'offline_quizzes';
  static const String notesBox = 'offline_notes';
  static const String userProfileBox = 'user_profile';
  static const String analyticsBox = 'analytics_data';

  static bool _isInitialized = false;

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
  // USER PROFILE, ID & AUTH CACHING
  // ---------------------------------------------------------------------------
  static String getUserId() {
    final authUid = SupabaseService.instance.authUserId;
    if (authUid != null && authUid.isNotEmpty) return authUid;

    final profile = getUserProfile();
    final savedId = profile['userId'] as String?;
    if (savedId != null && savedId.isNotEmpty) return savedId;

    final email = (profile['email'] as String? ?? 'guest@trueme.app').toLowerCase().trim();
    return 'usr_${email.hashCode.abs()}';
  }

  static Future<void> saveUserProfile({
    String? userId,
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
    final resolvedEmail = email.trim().isEmpty ? 'student@trueme.app' : email.trim();
    final resolvedUserId = userId ??
        SupabaseService.instance.authUserId ??
        (current['userId'] as String?) ??
        'usr_${resolvedEmail.toLowerCase().hashCode.abs()}';

    final resolvedDeadline = targetExamDate ??
        DateTime.tryParse(current['targetExamDate']?.toString() ?? '') ??
        DateTime.now().add(const Duration(days: 30));

    final existingSetupDate = DateTime.tryParse(current['examSetupDate']?.toString() ?? '');
    final setupDate = (targetExamDate != null || existingSetupDate == null)
        ? DateTime.now()
        : existingSetupDate;

    final resolvedSubjects = subjects ??
        (current['subjects'] is List
            ? List<String>.from((current['subjects'] as List).map((e) => e.toString()))
            : <String>[]);
    final resolvedName = name.trim().isEmpty ? 'Student' : name.trim();
    final resolvedStyle = learningStyle ?? (current['learningStyle'] as String?) ?? 'Visual & Practice';

    final updated = {
      ...current,
      'userId': resolvedUserId,
      'name': resolvedName,
      'email': resolvedEmail,
      'subjects': resolvedSubjects,
      'learningStyle': resolvedStyle,
      'targetExamDate': resolvedDeadline.toIso8601String(),
      'examSetupDate': setupDate.toIso8601String(),
      'isLoggedIn': isLoggedIn,
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await box.put('current_user', updated);

    // Sync to Supabase asynchronously
    SupabaseService.instance.upsertProfile(
      userId: resolvedUserId,
      name: resolvedName,
      email: resolvedEmail,
      subjects: resolvedSubjects,
      learningStyle: resolvedStyle,
      targetExamDate: resolvedDeadline,
      setupStartedAt: setupDate,
    );
  }

  static Map<String, dynamic> getUserProfile() {
    try {
      final box = Hive.box(userProfileBox);
      final data = box.get('current_user');
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    return {
      'userId': 'usr_guest',
      'name': 'Student',
      'email': 'student@trueme.app',
      'subjects': <String>[],
      'learningStyle': 'Visual & Practice',
      'targetExamDate': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'examSetupDate': DateTime.now().toIso8601String(),
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

  static DateTime getExamSetupDate() {
    final profile = getUserProfile();
    final d = profile['examSetupDate'] as String?;
    if (d != null) {
      final parsed = DateTime.tryParse(d);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
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
    await SupabaseService.instance.signOut();
    final box = Hive.box(userProfileBox);
    final profile = getUserProfile();
    profile['isLoggedIn'] = false;
    await box.put('current_user', profile);
  }

  // ---------------------------------------------------------------------------
  // CLOUD SYNC (SUPABASE -> HIVE)
  // ---------------------------------------------------------------------------
  static Future<void> syncFromCloud() async {
    if (!SupabaseService.instance.isReady) return;
    final userId = getUserId();
    final sb = SupabaseService.instance;

    try {
      // 1. Pull Profile
      final remoteProfile = await sb.fetchProfile(userId);
      if (remoteProfile != null) {
        final box = Hive.box(userProfileBox);
        final current = getUserProfile();
        final merged = {
          ...current,
          'userId': userId,
          if ((remoteProfile['name'] as String? ?? '').isNotEmpty) 'name': remoteProfile['name'],
          if ((remoteProfile['email'] as String? ?? '').isNotEmpty) 'email': remoteProfile['email'],
          if (remoteProfile['subjects'] is List && (remoteProfile['subjects'] as List).isNotEmpty)
            'subjects': List<String>.from(remoteProfile['subjects'] as List),
          if (remoteProfile['target_exam_date'] != null)
            'targetExamDate': remoteProfile['target_exam_date'],
          if (remoteProfile['setup_started_at'] != null)
            'examSetupDate': remoteProfile['setup_started_at'],
        };
        await box.put('current_user', merged);
      }

      // 2. Pull Notebooks
      final remoteNotebooks = await sb.fetchNotebooks(userId);
      if (remoteNotebooks.isNotEmpty) {
        final nbBox = Hive.box(notebooksBox);
        for (final rn in remoteNotebooks) {
          final id = rn['id'] as String?;
          if (id == null) continue;
          final docs = (rn['documents'] as List? ?? [])
              .map((d) => Map<String, dynamic>.from(d as Map))
              .toList();
          await nbBox.put(id, {
            'id': id,
            'userId': userId,
            'title': rn['title'],
            'subject': rn['subject'],
            'documents': docs,
            'fileRefs': docs.map((d) => d['fileName']?.toString() ?? '').where((s) => s.isNotEmpty).toList(),
            'createdAt': rn['created_at'] ?? DateTime.now().toIso8601String(),
            'lastModified': rn['updated_at'] ?? DateTime.now().toIso8601String(),
          });
        }
      }

      // 3. Pull Upcoming 7 Days of Study Tasks
      final now = DateTime.now();
      for (int offset = 0; offset < 7; offset++) {
        final dKey = dateKey(now.add(Duration(days: offset)));
        final remoteTasks = await sb.fetchStudyTasksForDate(userId: userId, planDate: dKey);
        if (remoteTasks != null && remoteTasks.isNotEmpty) {
          await Hive.box(studyPlanBox).put(dKey, {
            'sessions': remoteTasks,
            'updatedAt': DateTime.now().toIso8601String(),
          });
        }
      }

      // 4. Pull & Merge Quiz Attempts (preserving unsynced local attempts)
      final remoteQuizzes = await sb.fetchQuizAttempts(userId);
      if (remoteQuizzes.isNotEmpty) {
        final aBox = Hive.box(analyticsBox);
        final localRaw = aBox.get('quiz_attempts') as List? ?? [];
        final Map<String, Map<String, dynamic>> mergedById = {};
        for (final item in localRaw) {
          final m = Map<String, dynamic>.from(item as Map);
          final id = m['id']?.toString();
          if (id != null && id.isNotEmpty) mergedById[id] = m;
        }
        for (final q in remoteQuizzes) {
          final id = q['id']?.toString();
          if (id == null || id.isEmpty) continue;
          mergedById[id] = {
            'id': id,
            'subject': q['subject'],
            'topic': q['topic'],
            'score': q['score'],
            'total': q['total'],
            'percentage': q['percentage'],
            'missedTopics': List<String>.from(q['missed_topics'] ?? []),
            'timestamp': q['created_at'] ?? DateTime.now().toIso8601String(),
          };
        }
        final mergedList = mergedById.values.toList()
          ..sort((a, b) => (b['timestamp']?.toString() ?? '').compareTo(a['timestamp']?.toString() ?? ''));
        if (mergedList.length > 50) mergedList.removeRange(50, mergedList.length);
        await aBox.put('quiz_attempts', mergedList);
      }

      // 4b. Pull Flashcard Decks
      final remoteDecks = await sb.fetchFlashcardDecks(userId);
      if (remoteDecks.isNotEmpty) {
        final fBox = Hive.box(flashcardsBox);
        for (final rd in remoteDecks) {
          final id = rd['id']?.toString();
          if (id == null || id.isEmpty) continue;
          final cards = (rd['cards'] as List? ?? [])
              .map((c) => Map<String, dynamic>.from(c as Map))
              .toList();
          await fBox.put(id, {
            'id': id,
            'notebookId': rd['notebook_id'] ?? '',
            'subject': rd['subject'] ?? 'General',
            'topic': rd['topic'] ?? 'Flashcards',
            'cards': cards,
            'createdAt': rd['created_at'] ?? DateTime.now().toIso8601String(),
          });
        }
      }

      // 5. Pull Study Sessions for streak & weekly time if local is empty
      final remoteSessions = await sb.fetchStudySessions(userId);
      if (remoteSessions.isNotEmpty) {
        final aBox = Hive.box(analyticsBox);
        final localDaily = aBox.get('daily_minutes') as Map? ?? {};
        if (localDaily.isEmpty) {
          final Map<String, int> daily = {};
          final List<Map<String, dynamic>> recent = [];
          for (final s in remoteSessions) {
            final createdStr = s['created_at'] as String?;
            final dt = createdStr != null ? DateTime.tryParse(createdStr) : null;
            final mins = (s['duration_min'] as num? ?? 0).toInt();
            if (dt != null && mins > 0) {
              final k = dateKey(dt.toLocal());
              daily[k] = (daily[k] ?? 0) + mins;
            }
            if ((s['session_type'] as String? ?? '') != 'task' && recent.length < 20) {
              recent.add({
                'activity': s['session_type'] ?? 'quiz',
                'subject': s['subject'] ?? 'General',
                'title': s['topic'] ?? 'Study session',
                'subtitle': '$mins min',
                'timestamp': createdStr ?? DateTime.now().toIso8601String(),
              });
            }
          }
          await aBox.put('daily_minutes', daily);
          if (recent.isNotEmpty) {
            await aBox.put('recent_sessions', recent);
          }
        }
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // NOTEBOOK & DOCUMENT CACHING
  // ---------------------------------------------------------------------------
  static Future<void> cacheNotebook(String notebookId, Map<String, dynamic> notebookMap) async {
    final box = Hive.box(notebooksBox);
    await box.put(notebookId, notebookMap);

    final docs = (notebookMap['documents'] as List? ?? [])
        .map((d) => Map<String, dynamic>.from(d as Map))
        .toList();
    SupabaseService.instance.upsertNotebook(
      id: notebookId,
      userId: getUserId(),
      title: notebookMap['title'] as String? ?? 'Subject',
      subject: notebookMap['subject'] as String? ?? 'Subject',
      documents: docs,
    );
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
    SupabaseService.instance.deleteNotebook(notebookId);
  }

  static Future<void> renameNotebook(String notebookId, String newTitle) async {
    final nb = getCachedNotebook(notebookId);
    if (nb != null && newTitle.trim().isNotEmpty) {
      nb['title'] = newTitle.trim();
      nb['subject'] = newTitle.trim();
      nb['lastModified'] = DateTime.now().toIso8601String();
      await cacheNotebook(notebookId, nb);
    }
  }

  static Future<Map<String, dynamic>> createNotebook({
    required String title,
    required String subject,
    List<String>? tags,
    int? colorValue,
  }) async {
    final existing = getAllCachedNotebooks().where(
      (n) => (n['title'] as String? ?? '').toLowerCase() == title.trim().toLowerCase(),
    );
    if (existing.isNotEmpty) {
      return existing.first;
    }

    final userId = getUserId();
    final id = 'nb_${DateTime.now().millisecondsSinceEpoch}_${title.hashCode.abs()}';
    final nb = {
      'id': id,
      'userId': userId,
      'title': title.trim(),
      'subject': subject.trim(),
      'colorValue': colorValue ?? 0xFF2563EB,
      'tags': tags ?? [subject],
      'fileRefs': <String>[],
      'documents': <Map<String, dynamic>>[],
      'createdAt': DateTime.now().toIso8601String(),
      'lastModified': DateTime.now().toIso8601String(),
    };
    await cacheNotebook(id, nb);

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
    final nb = getCachedNotebook(notebookId);
    if (nb != null) {
      final rawDocs = nb['documents'] as List? ?? [];
      final docs = rawDocs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final docMap = Map<String, dynamic>.from(doc);
      docMap['id'] ??= 'doc_${DateTime.now().millisecondsSinceEpoch}';
      docMap['createdAt'] ??= DateTime.now().toIso8601String();

      final existingIdx = docs.indexWhere((d) => d['id'] == docMap['id']);
      if (existingIdx >= 0) {
        docs[existingIdx] = {
          ...docs[existingIdx],
          ...docMap,
        };
      } else {
        docs.add(docMap);
      }

      final fName = docMap['fileName'] as String? ?? '';
      nb['documents'] = docs;
      nb['fileRefs'] = docs
          .map((d) => (d['fileName'] as String? ?? ''))
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      nb['lastModified'] = DateTime.now().toIso8601String();
      await cacheNotebook(notebookId, nb);

      if (existingIdx < 0) {
        SupabaseService.instance.registerUserFile(
          userId: getUserId(),
          notebookId: notebookId,
          fileName: fName.isNotEmpty ? fName : 'Source',
          fileType: docMap['fileType'] as String? ?? 'text',
          driveFileId: docMap['driveFileId'] as String? ?? '',
          sizeBytes: (docMap['sizeBytes'] as num? ?? 0).toInt(),
          chunkCount: 1,
        );
      }
    }
  }

  static Future<void> removeDocumentFromNotebook(String notebookId, String docId) async {
    final nb = getCachedNotebook(notebookId);
    if (nb != null) {
      final rawDocs = nb['documents'] as List? ?? [];
      final docs = rawDocs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      docs.removeWhere((d) => d['id'] == docId);
      nb['documents'] = docs;
      nb['fileRefs'] = docs.map((d) => (d['fileName'] as String? ?? '')).where((s) => s.isNotEmpty).toList();
      nb['lastModified'] = DateTime.now().toIso8601String();
      await cacheNotebook(notebookId, nb);
    }
  }

  static Future<void> updateDocumentInNotebook(
    String notebookId,
    String docId, {
    String? fileName,
    String? section,
  }) async {
    final nb = getCachedNotebook(notebookId);
    if (nb == null) return;
    final rawDocs = nb['documents'] as List? ?? [];
    final docs = rawDocs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    bool changed = false;
    for (final d in docs) {
      if (d['id'] == docId) {
        if (fileName != null && fileName.trim().isNotEmpty) {
          d['fileName'] = fileName.trim();
          changed = true;
        }
        if (section != null && section.trim().isNotEmpty) {
          d['section'] = section.trim();
          changed = true;
        }
        break;
      }
    }
    if (changed) {
      nb['documents'] = docs;
      nb['fileRefs'] = docs.map((d) => (d['fileName'] as String? ?? '')).where((s) => s.isNotEmpty).toList();
      nb['lastModified'] = DateTime.now().toIso8601String();
      await cacheNotebook(notebookId, nb);
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
    final seenDocIds = <String>{};
    for (final d in docs) {
      final id = d['id']?.toString();
      if (id != null && id.isNotEmpty) seenDocIds.add(id);
      final name = d['fileName'] ?? 'Source';
      final section = d['section'] ?? 'Notes';
      final content = (d['content'] as String? ?? '').trim();
      if (content.isNotEmpty) {
        buffer.writeln('--- [$section: $name] ---');
        buffer.writeln(content);
        buffer.writeln();
      }
    }

    final notes = getAllCachedNotes().where((n) => n['notebookId'] == notebookId);
    for (final n in notes) {
      final id = n['id']?.toString();
      if (id != null && seenDocIds.contains(id)) continue;
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
  // DAILY STUDY PLAN CACHING + SUPABASE SYNC
  // ---------------------------------------------------------------------------
  static String dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Calendar-day countdown from today's midnight to [target]'s midnight.
  static int daysUntil(DateTime target) {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final targetMidnight = DateTime(target.year, target.month, target.day);
    return targetMidnight.difference(todayMidnight).inDays.clamp(0, 999);
  }

  static Future<void> cacheStudyPlan(String date, Map<String, dynamic> planMap) async {
    final box = Hive.box(studyPlanBox);
    await box.put(date, planMap);

    final sessions = (planMap['sessions'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    SupabaseService.instance.syncStudyTasksForDate(
      userId: getUserId(),
      planDate: date,
      tasks: sessions,
    );
  }

  static Map<String, dynamic>? getCachedStudyPlan(String date) {
    final box = Hive.box(studyPlanBox);
    final data = box.get(date);
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  // ---------------------------------------------------------------------------
  // FLASHCARD DECK CACHING + SUPABASE SYNC
  // ---------------------------------------------------------------------------
  static Future<void> cacheDeck(String deckId, Map<String, dynamic> deckMap) async {
    final box = Hive.box(flashcardsBox);
    await box.put(deckId, deckMap);
    SupabaseService.instance.upsertFlashcardDeck(getUserId(), deckMap);
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
    SupabaseService.instance.deleteFlashcardDeck(deckId);
  }

  static List<Map<String, dynamic>> getAllCachedDecks() {
    final box = Hive.box(flashcardsBox);
    return box.values
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // QUIZ CACHING & RESULTS ANALYTICS + SUPABASE SYNC
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
    final pct = total > 0 ? ((score / total) * 100).round() : 0;
    final resolvedTopic = topic.isNotEmpty ? topic : subject;

    attempts.insert(0, {
      'id': id,
      'subject': subject,
      'topic': resolvedTopic,
      'score': score,
      'total': total,
      'percentage': pct,
      'missedTopics': missedTopics,
      'timestamp': DateTime.now().toIso8601String(),
    });

    if (attempts.length > 50) attempts.removeRange(50, attempts.length);
    await box.put('quiz_attempts', attempts);

    SupabaseService.instance.insertQuizAttempt(
      id: id,
      userId: getUserId(),
      subject: subject,
      topic: resolvedTopic,
      score: score,
      total: total,
      percentage: pct,
      missedTopics: missedTopics,
    );

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
  // STUDY ACTIVITY, STREAK & RECENT SESSIONS + SUPABASE SYNC
  // ---------------------------------------------------------------------------
  static Future<void> logStudySession({
    required String activity,
    required String subject,
    required String title,
    String? subtitle,
    required int minutes,
  }) async {
    final box = Hive.box(analyticsBox);
    final todayStr = dateKey(DateTime.now());

    final rawDaily = box.get('daily_minutes') as Map? ?? {};
    final daily = Map<String, int>.from(
      rawDaily.map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
    );
    daily[todayStr] = (daily[todayStr] ?? 0) + minutes;
    await box.put('daily_minutes', daily);

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

    SupabaseService.instance.insertStudySession(
      userId: getUserId(),
      subject: subject,
      topic: title,
      sessionType: activity,
      durationMin: minutes,
    );
  }

  static List<int> getWeeklyStudyMinutes() {
    try {
      final box = Hive.box(analyticsBox);
      final rawDaily = box.get('daily_minutes') as Map? ?? {};
      final now = DateTime.now();
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
