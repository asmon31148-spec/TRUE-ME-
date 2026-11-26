import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env_config.dart';
import '../models/document_chunk_model.dart';
import 'sync_outbox_service.dart';

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
    final url = EnvConfig.get('SUPABASE_URL');
    final anonKey = EnvConfig.get('SUPABASE_ANON_KEY');

    if (url.isNotEmpty && anonKey.isNotEmpty) {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
      _initialized = true;
    }
  }

  bool get isReady => _clientOrNull != null;
  SupabaseClient? get clientOrNull => _clientOrNull;
  String? get authUserId => _clientOrNull?.auth.currentUser?.id;
  String? get currentAccessToken => _clientOrNull?.auth.currentSession?.accessToken;

  /// Observable last cloud sync/query error (DATA-01). Cleared on successful sync.
  String? lastSyncError;

  Future<int> flushPendingSync() async {
    final client = _clientOrNull;
    if (client == null || client.auth.currentUser == null) return 0;
    return SyncOutboxService.flush((opType, payload) async {
      switch (opType) {
        case 'upsert_profile':
          return _execUpsertProfile(client, payload);
        case 'upsert_notebook':
          return _execUpsertNotebook(client, payload);
        case 'delete_notebook':
          return _execDeleteNotebook(client, payload['id']?.toString() ?? '');
        case 'sync_study_tasks':
          return _execSyncStudyTasks(
            client,
            payload['planDate']?.toString() ?? '',
            (payload['tasks'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(),
          );
        case 'insert_study_session':
          return _execInsertStudySession(client, payload);
        case 'insert_quiz_attempt':
          return _execInsertQuizAttempt(client, payload);
        case 'upsert_flashcard_deck':
          return _execUpsertFlashcardDeck(client, payload);
        case 'delete_flashcard_deck':
          return _execDeleteFlashcardDeck(client, payload['id']?.toString() ?? '');
        default:
          return true;
      }
    });
  }

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

  Stream<AuthState>? get onAuthStateChange => _clientOrNull?.auth.onAuthStateChange;

  Future<bool> signInWithOAuthProvider(OAuthProvider provider) async {
    final client = _clientOrNull;
    if (client == null) return false;
    return await client.auth.signInWithOAuth(
      provider,
      redirectTo: 'io.supabase.trueme://login-callback/',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  Future<bool> signInWithGoogleOAuth() => signInWithOAuthProvider(OAuthProvider.google);

  Future<bool> signInWithFacebookOAuth() => signInWithOAuthProvider(OAuthProvider.facebook);

  Future<AuthResponse?> signInAnonymously() async {
    final client = _clientOrNull;
    if (client == null) return null;
    try {
      return await client.auth.signInAnonymously();
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _clientOrNull?.auth.signOut();
    } catch (_) {}
  }

  /// Persists encrypted MEGA Vault session token in the user's Supabase metadata
  /// so reinstalling the app restores MEGA automatically without re-entering credentials.
  Future<void> saveMegaVaultSession({
    required String token,
    required String email,
  }) async {
    final client = _clientOrNull;
    if (client == null || client.auth.currentUser == null) return;
    try {
      await client.auth.updateUser(
        UserAttributes(
          data: {
            'mega_vault_token': token,
            'mega_vault_email': email,
          },
        ),
      );
    } catch (_) {}
  }

  /// Reads persisted MEGA Vault session from Supabase user metadata (for reinstall recovery).
  Map<String, String>? getMegaVaultSession() {
    final meta = _clientOrNull?.auth.currentUser?.userMetadata;
    if (meta == null) return null;
    final token = meta['mega_vault_token']?.toString() ?? '';
    final email = meta['mega_vault_email']?.toString() ?? '';
    if (token.isEmpty) return null;
    return {'token': token, 'email': email};
  }

  Future<void> clearMegaVaultSession() async {
    final client = _clientOrNull;
    if (client == null || client.auth.currentUser == null) return;
    try {
      await client.auth.updateUser(
        UserAttributes(
          data: {
            'mega_vault_token': null,
            'mega_vault_email': null,
          },
        ),
      );
    } catch (_) {}
  }

  /// Claims 1-to-1 ownership of a Mega identity for the current TRUE ME account.
  /// Returns `null` on success, or an error string if already linked to another account.
  Future<String?> claimMegaIdentity({
    required String megaEmail,
    required String megaIdentityHash,
  }) async {
    final client = _clientOrNull;
    if (client == null || client.auth.currentUser == null) return null;
    try {
      final res = await client.rpc(
        'claim_mega_identity',
        params: {
          'p_mega_email': megaEmail.trim().toLowerCase(),
          'p_mega_identity_hash': megaIdentityHash,
        },
      );
      if (res is Map && res['ok'] == false) {
        return res['error']?.toString() ??
            'This MEGA account is already linked to another TRUE ME account.';
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Unlinks the Mega identity owned by the current TRUE ME account.
  Future<void> unlinkMegaIdentity() async {
    final client = _clientOrNull;
    final uid = client?.auth.currentUser?.id;
    if (client == null || uid == null) return;
    try {
      await client.from('mega_account_links').delete().eq('user_id', uid);
    } catch (_) {}
  }

  /// Idempotently records an AI request in the server-side `ai_usage_ledger` (AI-01 / AI-02).
  Future<bool> recordAiUsage({
    required String requestId,
    required String provider,
    required String taskType,
    String status = 'success',
  }) async {
    final client = _clientOrNull;
    if (client == null || client.auth.currentUser == null) return true;
    try {
      final res = await client.rpc(
        'check_and_record_ai_usage',
        params: {
          'p_request_id': requestId,
          'p_provider': provider,
          'p_task_type': taskType,
          'p_status': status,
        },
      );
      if (res is Map && res['allowed'] == false) {
        return false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  // ---------------------------------------------------------------------------
  // USER PROFILES
  // ---------------------------------------------------------------------------
  Future<bool> _execUpsertProfile(SupabaseClient client, Map<String, dynamic> row) async {
    await client.from('user_profiles').upsert(row);
    lastSyncError = null;
    return true;
  }

  Future<bool> upsertProfile({
    required String userId,
    required String name,
    required String email,
    required List<String> subjects,
    required String learningStyle,
    required DateTime targetExamDate,
    DateTime? setupStartedAt,
  }) async {
    final row = <String, dynamic>{
      'id': userId,
      'name': name,
      'email': email,
      'subjects': subjects,
      'learning_style': learningStyle,
      'target_exam_date': targetExamDate.toIso8601String(),
      if (setupStartedAt != null) 'setup_started_at': setupStartedAt.toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final client = _clientOrNull;
    if (client == null) {
      await SyncOutboxService.enqueue(
        opType: 'upsert_profile',
        dedupKey: 'profile_$userId',
        payload: row,
      );
      return false;
    }
    try {
      return await _execUpsertProfile(client, row);
    } catch (e) {
      lastSyncError = 'Profile sync failed: $e';
      debugPrint(lastSyncError);
      await SyncOutboxService.enqueue(
        opType: 'upsert_profile',
        dedupKey: 'profile_$userId',
        payload: row,
      );
      return false;
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
      lastSyncError = null;
      if (res != null) return Map<String, dynamic>.from(res);
    } catch (e) {
      lastSyncError = 'Profile fetch failed: $e';
      debugPrint(lastSyncError);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // NOTEBOOKS & FILES
  // ---------------------------------------------------------------------------
  Future<bool> _execUpsertNotebook(SupabaseClient client, Map<String, dynamic> row) async {
    await client.from('notebooks').upsert(row);
    lastSyncError = null;
    return true;
  }

  Future<bool> upsertNotebook({
    required String id,
    required String userId,
    required String title,
    required String subject,
    required List<Map<String, dynamic>> documents,
  }) async {
    final row = <String, dynamic>{
      'id': id,
      'user_id': userId,
      'title': title,
      'subject': subject,
      'documents': documents,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final client = _clientOrNull;
    if (client == null) {
      await SyncOutboxService.enqueue(
        opType: 'upsert_notebook',
        dedupKey: 'notebook_$id',
        payload: row,
      );
      return false;
    }
    try {
      return await _execUpsertNotebook(client, row);
    } catch (e) {
      lastSyncError = 'Notebook sync failed: $e';
      debugPrint(lastSyncError);
      await SyncOutboxService.enqueue(
        opType: 'upsert_notebook',
        dedupKey: 'notebook_$id',
        payload: row,
      );
      return false;
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
      lastSyncError = null;
      return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      lastSyncError = 'Notebooks fetch failed: $e';
      debugPrint(lastSyncError);
      return [];
    }
  }

  Future<bool> _execDeleteNotebook(SupabaseClient client, String notebookId) async {
    await client.from('notebooks').delete().eq('id', notebookId);
    lastSyncError = null;
    return true;
  }

  Future<bool> deleteNotebook(String notebookId) async {
    final client = _clientOrNull;
    if (client == null) {
      await SyncOutboxService.enqueue(
        opType: 'delete_notebook',
        dedupKey: 'notebook_$notebookId',
        payload: {'id': notebookId},
      );
      return false;
    }
    try {
      return await _execDeleteNotebook(client, notebookId);
    } catch (e) {
      lastSyncError = 'Notebook delete failed: $e';
      debugPrint(lastSyncError);
      await SyncOutboxService.enqueue(
        opType: 'delete_notebook',
        dedupKey: 'notebook_$notebookId',
        payload: {'id': notebookId},
      );
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // DAILY STUDY TASKS (TODAY & SCHEDULE) — Atomic RPC (DATA-02)
  // ---------------------------------------------------------------------------
  Future<bool> _execSyncStudyTasks(
    SupabaseClient client,
    String planDate,
    List<Map<String, dynamic>> tasks,
  ) async {
    final normalized = List.generate(tasks.length, (i) {
      final t = tasks[i];
      return {
        'id': t['id']?.toString(),
        'title': t['title'] ?? 'Study task',
        'subject': t['subject'] ?? 'General',
        'type': t['type'] ?? 'reading',
        'duration': (t['duration'] as num? ?? 20).toInt(),
        'completed': t['completed'] == true,
      };
    });

    await client.rpc(
      'sync_study_tasks_for_date',
      params: {
        'p_plan_date': planDate,
        'p_tasks': normalized,
      },
    );
    lastSyncError = null;
    return true;
  }

  Future<bool> syncStudyTasksForDate({
    required String userId,
    required String planDate,
    required List<Map<String, dynamic>> tasks,
  }) async {
    final payload = {
      'userId': userId,
      'planDate': planDate,
      'tasks': tasks,
    };
    final client = _clientOrNull;
    if (client == null) {
      await SyncOutboxService.enqueue(
        opType: 'sync_study_tasks',
        dedupKey: 'tasks_${userId}_$planDate',
        payload: payload,
      );
      return false;
    }
    try {
      return await _execSyncStudyTasks(client, planDate, tasks);
    } catch (e) {
      lastSyncError = 'Study tasks sync failed: $e';
      debugPrint(lastSyncError);
      await SyncOutboxService.enqueue(
        opType: 'sync_study_tasks',
        dedupKey: 'tasks_${userId}_$planDate',
        payload: payload,
      );
      return false;
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
  Future<bool> _execInsertStudySession(SupabaseClient client, Map<String, dynamic> row) async {
    await client.from('study_sessions').insert(row);
    lastSyncError = null;
    return true;
  }

  Future<bool> insertStudySession({
    required String userId,
    required String subject,
    required String topic,
    required String sessionType,
    required int durationMin,
    double? score,
    Map<String, dynamic>? metadata,
  }) async {
    final row = <String, dynamic>{
      'user_id': userId,
      'subject': subject,
      'topic': topic,
      'session_type': sessionType,
      'duration_min': durationMin,
      if (score != null) 'score': score,
      'metadata': metadata ?? {},
    };
    final dedup = 'session_${userId}_${DateTime.now().millisecondsSinceEpoch}';
    final client = _clientOrNull;
    if (client == null) {
      await SyncOutboxService.enqueue(
        opType: 'insert_study_session',
        dedupKey: dedup,
        payload: row,
      );
      return false;
    }
    try {
      return await _execInsertStudySession(client, row);
    } catch (e) {
      lastSyncError = 'Study session sync failed: $e';
      debugPrint(lastSyncError);
      await SyncOutboxService.enqueue(
        opType: 'insert_study_session',
        dedupKey: dedup,
        payload: row,
      );
      return false;
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
      lastSyncError = null;
      return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      lastSyncError = 'Study sessions fetch failed: $e';
      debugPrint(lastSyncError);
      return [];
    }
  }

  Future<bool> _execInsertQuizAttempt(SupabaseClient client, Map<String, dynamic> row) async {
    await client.from('quiz_attempts').upsert(row);
    lastSyncError = null;
    return true;
  }

  Future<bool> insertQuizAttempt({
    required String id,
    required String userId,
    required String subject,
    required String topic,
    required int score,
    required int total,
    required int percentage,
    required List<String> missedTopics,
  }) async {
    final row = <String, dynamic>{
      'id': id,
      'user_id': userId,
      'subject': subject,
      'topic': topic,
      'score': score,
      'total': total,
      'percentage': percentage,
      'missed_topics': missedTopics,
    };
    final client = _clientOrNull;
    if (client == null) {
      await SyncOutboxService.enqueue(
        opType: 'insert_quiz_attempt',
        dedupKey: 'quiz_$id',
        payload: row,
      );
      return false;
    }
    try {
      return await _execInsertQuizAttempt(client, row);
    } catch (e) {
      lastSyncError = 'Quiz attempt sync failed: $e';
      debugPrint(lastSyncError);
      await SyncOutboxService.enqueue(
        opType: 'insert_quiz_attempt',
        dedupKey: 'quiz_$id',
        payload: row,
      );
      return false;
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
      lastSyncError = null;
      return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      lastSyncError = 'Quiz attempts fetch failed: $e';
      debugPrint(lastSyncError);
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // FLASHCARD DECKS
  // ---------------------------------------------------------------------------
  Future<bool> _execUpsertFlashcardDeck(SupabaseClient client, Map<String, dynamic> row) async {
    await client.from('flashcard_decks').upsert(row);
    lastSyncError = null;
    return true;
  }

  Future<bool> upsertFlashcardDeck(String userId, Map<String, dynamic> deckMap) async {
    final deckId = deckMap['id']?.toString() ?? '';
    final row = <String, dynamic>{
      'id': deckId,
      'user_id': userId,
      'notebook_id': deckMap['notebookId'],
      'subject': deckMap['subject'] ?? 'General',
      'topic': deckMap['topic'] ?? 'Flashcards',
      'cards': deckMap['cards'] ?? [],
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final client = _clientOrNull;
    if (client == null) {
      await SyncOutboxService.enqueue(
        opType: 'upsert_flashcard_deck',
        dedupKey: 'deck_$deckId',
        payload: row,
      );
      return false;
    }
    try {
      return await _execUpsertFlashcardDeck(client, row);
    } catch (e) {
      lastSyncError = 'Flashcard deck sync failed: $e';
      debugPrint(lastSyncError);
      await SyncOutboxService.enqueue(
        opType: 'upsert_flashcard_deck',
        dedupKey: 'deck_$deckId',
        payload: row,
      );
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchFlashcardDecks(String userId) async {
    final client = _clientOrNull;
    if (client == null) return [];
    try {
      final res = await client
          .from('flashcard_decks')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);
      lastSyncError = null;
      return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      lastSyncError = 'Flashcard decks fetch failed: $e';
      debugPrint(lastSyncError);
      return [];
    }
  }

  Future<bool> _execDeleteFlashcardDeck(SupabaseClient client, String deckId) async {
    await client.from('flashcard_decks').delete().eq('id', deckId);
    lastSyncError = null;
    return true;
  }

  Future<bool> deleteFlashcardDeck(String deckId) async {
    final client = _clientOrNull;
    if (client == null) {
      await SyncOutboxService.enqueue(
        opType: 'delete_flashcard_deck',
        dedupKey: 'deck_$deckId',
        payload: {'id': deckId},
      );
      return false;
    }
    try {
      return await _execDeleteFlashcardDeck(client, deckId);
    } catch (e) {
      lastSyncError = 'Flashcard deck delete failed: $e';
      debugPrint(lastSyncError);
      await SyncOutboxService.enqueue(
        opType: 'delete_flashcard_deck',
        dedupKey: 'deck_$deckId',
        payload: {'id': deckId},
      );
      return false;
    }
  }

  /// Deletes all cloud records belonging to [userId] across all tables.
  Future<void> deleteAllUserData(String userId) async {
    final client = _clientOrNull;
    if (client == null) return;
    final userOwnedTables = [
      'study_tasks',
      'study_sessions',
      'quiz_attempts',
      'flashcard_decks',
      'notebooks',
      'user_files',
      'document_chunks',
    ];
    for (final table in userOwnedTables) {
      try {
        await client.from(table).delete().eq('user_id', userId);
      } catch (e) {
        debugPrint('Supabase delete $table skipped: $e');
      }
    }
    try {
      await client.from('user_profiles').delete().eq('id', userId);
    } catch (e) {
      debugPrint('Supabase delete user_profiles skipped: $e');
    }
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
