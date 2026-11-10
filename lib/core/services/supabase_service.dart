import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/document_chunk_model.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  factory SupabaseService({SupabaseClient? client}) {
    if (client != null) {
      return SupabaseService._withClient(client);
    }
    return instance;
  }

  SupabaseClient? _overrideClient;
  SupabaseService._internal();
  SupabaseService._withClient(this._overrideClient);

  static bool _initialized = false;

  SupabaseClient? get _clientOrNull {
    if (_overrideClient != null) return _overrideClient;
    if (!_initialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static Future<void> initialize() async {
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (url.isNotEmpty && anonKey.isNotEmpty) {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
      _initialized = true;
    }
  }

  bool get isReady => _clientOrNull != null;
  String? get authUserId => _clientOrNull?.auth.currentUser?.id;

  // ---------------------------------------------------------------------------
  // AUTHENTICATION
  // ---------------------------------------------------------------------------
  Future<AuthResponse?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final client = _clientOrNull;
    if (client == null) return null;
    return await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name},
    );
  }

  Future<AuthResponse?> signIn({
    required String email,
    required String password,
  }) async {
    final client = _clientOrNull;
    if (client == null) return null;
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    try {
      await _clientOrNull?.auth.signOut();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // USER PROFILES
  // ---------------------------------------------------------------------------
  Future<void> upsertProfile({
    required String userId,
    required String name,
    required String email,
    required List<String> subjects,
    required String learningStyle,
    required DateTime targetExamDate,
    DateTime? setupStartedAt,
  }) async {
    final client = _clientOrNull;
    if (client == null) return;
    try {
      await client.from('user_profiles').upsert({
        'id': userId,
        'name': name,
        'email': email,
        'subjects': subjects,
        'learning_style': learningStyle,
        'target_exam_date': targetExamDate.toIso8601String(),
        if (setupStartedAt != null) 'setup_started_at': setupStartedAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Supabase upsertProfile skipped: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    final client = _clientOrNull;
    if (client == null) return null;
    try {
      final res = await client
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (res != null) return Map<String, dynamic>.from(res);
    } catch (e) {
      debugPrint('Supabase fetchProfile skipped: $e');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // NOTEBOOKS & FILES
  // ---------------------------------------------------------------------------
  Future<void> upsertNotebook({
    required String id,
    required String userId,
    required String title,
    required String subject,
    required List<Map<String, dynamic>> documents,
  }) async {
    final client = _clientOrNull;
    if (client == null) return;
    try {
      await client.from('notebooks').upsert({
        'id': id,
        'user_id': userId,
        'title': title,
        'subject': subject,
        'documents': documents,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Supabase upsertNotebook skipped: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchNotebooks(String userId) async {
    final client = _clientOrNull;
    if (client == null) return [];
    try {
      final res = await client
          .from('notebooks')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);
      return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('Supabase fetchNotebooks skipped: $e');
      return [];
    }
  }

  Future<void> deleteNotebook(String notebookId) async {
    final client = _clientOrNull;
    if (client == null) return;
    try {
      await client.from('notebooks').delete().eq('id', notebookId);
    } catch (e) {
      debugPrint('Supabase deleteNotebook skipped: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // DAILY STUDY TASKS (TODAY & SCHEDULE)
  // ---------------------------------------------------------------------------
  Future<void> syncStudyTasksForDate({
    required String userId,
    required String planDate,
    required List<Map<String, dynamic>> tasks,
  }) async {
    final client = _clientOrNull;
    if (client == null) return;
    try {
      // Replace tasks for this user & date atomically
      await client
          .from('study_tasks')
          .delete()
          .eq('user_id', userId)
          .eq('plan_date', planDate);

      if (tasks.isNotEmpty) {
        final rows = List.generate(tasks.length, (i) {
          final t = tasks[i];
          return {
            'id': t['id'] ?? 'task_${userId}_${planDate}_$i',
            'user_id': userId,
            'plan_date': planDate,
            'title': t['title'] ?? 'Study task',
            'subject': t['subject'] ?? 'General',
            'task_type': t['type'] ?? 'reading',
            'duration_min': (t['duration'] as num? ?? 20).toInt(),
            'completed': t['completed'] == true,
            'sort_order': i,
            'updated_at': DateTime.now().toIso8601String(),
          };
        });
        await client.from('study_tasks').upsert(rows);
      }
    } catch (e) {
      debugPrint('Supabase syncStudyTasksForDate skipped: $e');
    }
  }

  Future<List<Map<String, dynamic>>?> fetchStudyTasksForDate({
    required String userId,
    required String planDate,
  }) async {
    final client = _clientOrNull;
    if (client == null) return null;
    try {
      final res = await client
          .from('study_tasks')
          .select()
          .eq('user_id', userId)
          .eq('plan_date', planDate)
          .order('sort_order', ascending: true);
      final list = res as List;
      return list.map((row) {
        final m = Map<String, dynamic>.from(row as Map);
        return {
          'id': m['id'],
          'title': m['title'],
          'subject': m['subject'],
          'type': m['task_type'],
          'duration': m['duration_min'],
          'completed': m['completed'] == true,
        };
      }).toList();
    } catch (e) {
      debugPrint('Supabase fetchStudyTasksForDate skipped: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // STUDY SESSIONS & QUIZ ATTEMPTS
  // ---------------------------------------------------------------------------
  Future<void> insertStudySession({
    required String userId,
    required String subject,
    required String topic,
    required String sessionType,
    required int durationMin,
    double? score,
    Map<String, dynamic>? metadata,
  }) async {
    final client = _clientOrNull;
    if (client == null) return;
    try {
      await client.from('study_sessions').insert({
        'user_id': userId,
        'subject': subject,
        'topic': topic,
        'session_type': sessionType,
        'duration_min': durationMin,
        if (score != null) 'score': score,
        'metadata': metadata ?? {},
      });
    } catch (e) {
      debugPrint('Supabase insertStudySession skipped: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchStudySessions(String userId) async {
    final client = _clientOrNull;
    if (client == null) return [];
    try {
      final res = await client
          .from('study_sessions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('Supabase fetchStudySessions skipped: $e');
      return [];
    }
  }

  Future<void> insertQuizAttempt({
    required String id,
    required String userId,
    required String subject,
    required String topic,
    required int score,
    required int total,
    required int percentage,
    required List<String> missedTopics,
  }) async {
    final client = _clientOrNull;
    if (client == null) return;
    try {
      await client.from('quiz_attempts').upsert({
        'id': id,
        'user_id': userId,
        'subject': subject,
        'topic': topic,
        'score': score,
        'total': total,
        'percentage': percentage,
        'missed_topics': missedTopics,
      });
    } catch (e) {
      debugPrint('Supabase insertQuizAttempt skipped: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchQuizAttempts(String userId) async {
    final client = _clientOrNull;
    if (client == null) return [];
    try {
      final res = await client
          .from('quiz_attempts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('Supabase fetchQuizAttempts skipped: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // FLASHCARD DECKS
  // ---------------------------------------------------------------------------
  Future<void> upsertFlashcardDeck(String userId, Map<String, dynamic> deckMap) async {
    final client = _clientOrNull;
    if (client == null) return;
    try {
      await client.from('flashcard_decks').upsert({
        'id': deckMap['id'],
        'user_id': userId,
        'notebook_id': deckMap['notebookId'],
        'subject': deckMap['subject'] ?? 'General',
        'topic': deckMap['topic'] ?? 'Flashcards',
        'cards': deckMap['cards'] ?? [],
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Supabase upsertFlashcardDeck skipped: $e');
    }
  }

  Future<void> deleteFlashcardDeck(String deckId) async {
    final client = _clientOrNull;
    if (client == null) return;
    try {
      await client.from('flashcard_decks').delete().eq('id', deckId);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // EXISTING RAG CHUNKS & USER FILES
  // ---------------------------------------------------------------------------
  /// Inserts a document chunk with its 768-dimensional Gemini embedding.
  Future<void> insertChunk({
    required String userId,
    required String notebookId,
    required String fileName,
    required int chunkIndex,
    required String content,
    required List<double> embedding,
  }) async {
    final client = _clientOrNull;
    if (client == null) return;
    await client.from('document_chunks').insert({
      'user_id': userId,
      'notebook_id': notebookId,
      'file_name': fileName,
      'chunk_index': chunkIndex,
      'content': content,
      'embedding': embedding,
    });
  }

  /// Performs vector similarity search via PostgreSQL RPC `match_document_chunks`.
  Future<List<DocumentChunkModel>> searchSimilarChunks({
    required List<double> queryEmbedding,
    int matchCount = 5,
    String? userId,
    String? notebookId,
  }) async {
    final client = _clientOrNull;
    if (client == null) return [];
    final response = await client.rpc(
      'match_document_chunks',
      params: {
        'query_embedding': queryEmbedding,
        'match_count': matchCount,
        'filter_user_id': userId,
        'filter_notebook_id': notebookId,
      },
    );

    final rawList = response as List<dynamic>? ?? [];
    return rawList
        .map((item) => DocumentChunkModel.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  /// Registers user file reference.
  Future<void> registerUserFile({
    required String userId,
    required String notebookId,
    required String fileName,
    required String fileType,
    required String driveFileId,
    required int sizeBytes,
    required int chunkCount,
  }) async {
    final client = _clientOrNull;
    if (client == null) return;
    try {
      await client.from('user_files').insert({
        'user_id': userId,
        'notebook_id': notebookId,
        'file_name': fileName,
        'file_type': fileType,
        'drive_file_id': driveFileId,
        'size_bytes': sizeBytes,
        'processed': true,
        'chunk_count': chunkCount,
      });
    } catch (e) {
      debugPrint('Supabase registerUserFile skipped: $e');
    }
  }
}
