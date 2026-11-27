import 'dart:async';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/cloud_vault_service.dart';
import '../services/mega_vault_service.dart';
import '../services/offline_cache_service.dart';
import '../services/supabase_service.dart';
import '../utils/text_chunker.dart';
import 'ai_router.dart';

/// Syllabus-first hierarchy & source coverage service (Phases C & D).
/// Stores syllabus nodes (`semester -> unit -> topic -> subtopic`),
/// source-to-syllabus coverage mappings, and saved study artifacts per subject.
class SyllabusService {
  SyllabusService._();

  static const String _syllabusBoxPrefix = 'syllabus_nodes_';
  static const String _mappingBoxPrefix = 'source_mappings_';
  static const String _artifactBoxPrefix = 'study_artifacts_';
  static String? lastSyncError;

  static Box get _notebooksBox => Hive.box(OfflineCacheService.notebooksBox);

  static List<Map<String, dynamic>> getSyllabusNodes(String notebookId, {bool includeArchived = false}) {
    try {
      final raw = _notebooksBox.get('$_syllabusBoxPrefix$notebookId') as List? ?? [];
      final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (includeArchived) return list;
      return list.where((n) => n['archived'] != true).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveSyllabusNodes(String notebookId, List<Map<String, dynamic>> nodes) async {
    await _notebooksBox.put('$_syllabusBoxPrefix$notebookId', nodes);
    unawaited(_syncNodesToSupabase(notebookId, nodes));
  }

  static List<Map<String, dynamic>> getSourceMappings(String notebookId) {
    try {
      final raw = _notebooksBox.get('$_mappingBoxPrefix$notebookId') as List? ?? [];
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveSourceMappings(String notebookId, List<Map<String, dynamic>> mappings) async {
    await _notebooksBox.put('$_mappingBoxPrefix$notebookId', mappings);
  }

  /// Saved Study Artifacts per subject (PDF, Word, Slides, Summary, Mind Map, Explainer, Quiz, Flashcards).
  static List<Map<String, dynamic>> getArtifacts(String notebookId, {String? artifactType}) {
    try {
      final raw = _notebooksBox.get('$_artifactBoxPrefix$notebookId') as List? ?? [];
      final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (artifactType == null || artifactType.isEmpty) return list;
      return list.where((a) => a['artifactType'] == artifactType).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveArtifact({
    String? documentId,
    required String notebookId,
    required String artifactType,
    required String title,
    String? nodeId,
    String? topicLabel,
    String? depthLevel,
    String? styleId,
    String? styleVersion,
    String? filePath,
    int? fileSize,
    int? pageCount,
    int? slideCount,
    String generationState = 'ready',
    String? vaultId,
    String? sourceChatId,
    List<String>? sourceRefs,
    Map<String, dynamic>? contentJson,
  }) async {
      final existing = getArtifacts(notebookId);
      final id = documentId ?? 'art_${DateTime.now().millisecondsSinceEpoch}';
      final entry = {
        'id': id,
        'documentId': id,
        'notebookId': notebookId,
        'nodeId': nodeId,
        'artifactType': artifactType,
        'title': title,
        'topicLabel': topicLabel ?? title,
        'depthLevel': depthLevel ?? 'standard',
        if (styleId != null) 'styleId': styleId,
        if (styleVersion != null) 'styleVersion': styleVersion,
        if (filePath != null) 'filePath': filePath,
        if (fileSize != null) 'fileSize': fileSize,
        if (pageCount != null) 'pageCount': pageCount,
        if (slideCount != null) 'slideCount': slideCount,
        'generationState': generationState,
        if (vaultId != null) 'vaultId': vaultId,
        if (sourceChatId != null) 'sourceChatId': sourceChatId,
        if (sourceRefs != null && sourceRefs.isNotEmpty) 'sourceRefs': sourceRefs,
        if (contentJson != null) 'contentJson': contentJson,
        'archived': false,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      };
      final idx = existing.indexWhere((a) => a['id'] == id || a['documentId'] == id);
      if (idx >= 0) {
        existing[idx] = entry;
      } else {
        existing.insert(0, entry);
      }
      if (existing.length > 150) existing.removeRange(150, existing.length);
      await _notebooksBox.put('$_artifactBoxPrefix$notebookId', existing);
      unawaited(_syncArtifactToSupabase(entry));
  }

  /// Renames a generated study artifact locally, in Supabase, and in MEGA Vault if backed up.
  static Future<void> renameArtifact(
    String notebookId,
    String artifactId,
    String newTitle,
  ) async {
    final clean = newTitle.trim();
    if (clean.isEmpty) return;
    final list = getArtifacts(notebookId);
    final idx = list.indexWhere((a) => a['id'] == artifactId || a['documentId'] == artifactId);
    if (idx < 0) return;

    final updated = Map<String, dynamic>.from(list[idx]);
    updated['title'] = clean;
    list[idx] = updated;
    await _notebooksBox.put('$_artifactBoxPrefix$notebookId', list);
    unawaited(_syncArtifactToSupabase(updated));

    final vaultId = updated['vaultId']?.toString() ?? '';
    if (vaultId.isNotEmpty) {
      final path = updated['filePath']?.toString() ?? '';
      final ext = path.contains('.') ? '.${path.split('.').last}' : '';
      final megaName = ext.isNotEmpty && !clean.toLowerCase().endsWith(ext.toLowerCase())
          ? '$clean$ext'
          : clean;
      unawaited(CloudVaultService.renameFile(vaultId, megaName));
    }
  }

  /// Deletes a generated study artifact from local device storage, Hive, Supabase, and MEGA Vault.
  static Future<void> deleteArtifact(
    String notebookId,
    String artifactId, {
    String? subject,
  }) async {
    final list = getArtifacts(notebookId);
    final idx = list.indexWhere((a) => a['id'] == artifactId || a['documentId'] == artifactId);
    if (idx < 0) return;

    final target = Map<String, dynamic>.from(list[idx]);
    final localPath = target['filePath']?.toString() ?? '';
    if (localPath.isNotEmpty) {
      try {
        final f = File(localPath);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }

    String vaultId = target['vaultId']?.toString() ?? '';
    if (vaultId.isEmpty && MegaVaultService.instance.isSignedIn && localPath.isNotEmpty) {
      try {
        final fileName = localPath.split(RegExp(r'[/\\]')).last;
        final files = await MegaVaultService.instance.listFiles(subject: subject);
        final match = files.where((f) => f.name == fileName).firstOrNull;
        if (match != null) vaultId = match.id;
      } catch (_) {}
    }
    if (vaultId.isNotEmpty) {
      await CloudVaultService.deleteFile(vaultId);
    }

    list.removeAt(idx);
    await _notebooksBox.put('$_artifactBoxPrefix$notebookId', list);

    try {
      final client = SupabaseService.instance.clientOrNull;
      final uid = SupabaseService.instance.authUserId;
      if (client != null && uid != null) {
        await client
            .from('study_artifacts')
            .delete()
            .eq('id', artifactId)
            .eq('user_id', uid);
      }
    } catch (e) {
      lastSyncError = 'Artifact delete sync failed: $e';
    }
  }

  static Future<void> _syncArtifactToSupabase(Map<String, dynamic> entry) async {
    try {
      final client = SupabaseService.instance.clientOrNull;
      final uid = SupabaseService.instance.authUserId;
      if (client == null || uid == null) return;
      await client.from('study_artifacts').upsert({
        'id': entry['id'],
        'user_id': uid,
        'notebook_id': entry['notebookId'],
        'node_id': entry['nodeId'],
        'artifact_type': entry['artifactType'],
        'title': entry['title'],
        'topic_label': entry['topicLabel'],
        'depth_level': entry['depthLevel'],
        'file_path': entry['filePath'],
        'vault_id': entry['vaultId'],
        'source_chat_id': entry['sourceChatId'],
        'content_json': entry['contentJson'],
        'archived': entry['archived'] == true,
      });
      lastSyncError = null;
    } catch (e) {
      lastSyncError = 'Artifact sync failed: $e';
    }
  }

  static Future<void> _syncNodesToSupabase(
    String notebookId,
    List<Map<String, dynamic>> nodes,
  ) async {
    try {
      final client = SupabaseService.instance.clientOrNull;
      final uid = SupabaseService.instance.authUserId;
      if (client == null || uid == null || nodes.isEmpty) return;
      final payload = nodes.map((n) => {
        'id': n['id'],
        'user_id': uid,
        'notebook_id': notebookId,
        'parent_id': n['parentId'],
        'node_type': n['nodeType'],
        'title': n['title'],
        'academic_level': n['academicLevel'],
        'source_origin': n['sourceOrigin'] ?? 'official_syllabus',
        'status': n['status'] ?? 'pending',
        'confirmed': n['confirmed'] == true,
        'archived': n['archived'] == true,
        'sort_order': n['sortOrder'] ?? 0,
      }).toList();
      await client.from('syllabus_nodes').upsert(payload);
      lastSyncError = null;
    } catch (e) {
      lastSyncError = 'Syllabus sync failed: $e';
    }
  }

  /// Extracts a `semester -> unit -> topic -> subtopic` hierarchy from an uploaded syllabus.
  /// Chunks long syllabi so units are not silently truncated.
  static Future<List<Map<String, dynamic>>> extractAndSaveSyllabus({
    required AiRouter aiRouter,
    required String notebookId,
    required String subject,
    required String syllabusText,
  }) async {
    final trimmed = syllabusText.trim();
    if (trimmed.isEmpty) return [];

    final chunks = trimmed.length > 12000
        ? TextChunker.splitIntoChunks(trimmed, targetChunkChars: 12000, overlapChars: 400)
        : null;
    final segments = chunks != null ? chunks.map((c) => c.content).toList() : [trimmed];

    final List<dynamic> items = [];
    String academicLevel = 'Unknown';

    for (int i = 0; i < segments.length; i++) {
      final raw = await aiRouter.executeHeavyReasoning(
        jsonMode: true,
        prompt: '''
Analyze this syllabus segment (${i + 1}/${segments.length}) for "$subject". Extract the academic hierarchy and course level.
Return ONLY valid JSON:
{
  "academicLevel": "BSc | MSc | High School | Competitive | Unknown",
  "levelConfidence": 0.0,
  "items": [
    {
      "semester": "Semester 1",
      "unit": "Unit 1: Title",
      "topics": [
        {
          "title": "Topic Name",
          "subtopics": ["Subtopic A", "Subtopic B"]
        }
      ]
    }
  ]
}

Syllabus text:
${segments[i]}
''',
      );
      final parsed = AiRouter.parseJsonObject(raw);
      if (academicLevel == 'Unknown' && parsed['academicLevel'] != null) {
        academicLevel = parsed['academicLevel'].toString();
      }
      items.addAll(parsed['items'] as List? ?? []);
    }

    // Archive existing active nodes on syllabus revision (preserving artifact links)
    final previous = getSyllabusNodes(notebookId, includeArchived: true)
        .map((n) => {...n, 'archived': true})
        .toList();

    final List<Map<String, dynamic>> newNodes = [];
    int order = 0;
    final nowTs = DateTime.now().millisecondsSinceEpoch;

    for (final semItem in items) {
      if (semItem is! Map) continue;
      final semTitle = (semItem['semester'] ?? 'Semester 1').toString().trim();
      final unitTitle = (semItem['unit'] ?? 'Unit 1').toString().trim();

      final semId = 'sem_${nowTs}_${order++}';
      newNodes.add({
        'id': semId,
        'parentId': null,
        'nodeType': 'semester',
        'title': semTitle,
        'academicLevel': academicLevel,
        'sourceOrigin': 'official_syllabus',
        'confirmed': true,
        'archived': false,
        'sortOrder': order,
      });

      final unitId = 'unit_${nowTs}_${order++}';
      newNodes.add({
        'id': unitId,
        'parentId': semId,
        'nodeType': 'unit',
        'title': unitTitle,
        'academicLevel': academicLevel,
        'sourceOrigin': 'official_syllabus',
        'confirmed': true,
        'archived': false,
        'sortOrder': order,
      });

      final topics = semItem['topics'] as List? ?? [];
      for (final t in topics) {
        if (t is! Map) continue;
        final tTitle = (t['title'] ?? '').toString().trim();
        if (tTitle.isEmpty) continue;
        final topicId = 'top_${nowTs}_${order++}';
        newNodes.add({
          'id': topicId,
          'parentId': unitId,
          'nodeType': 'topic',
          'title': tTitle,
          'academicLevel': academicLevel,
          'sourceOrigin': 'official_syllabus',
          'confirmed': true,
          'archived': false,
          'sortOrder': order,
        });

        final subs = t['subtopics'] as List? ?? [];
        for (final sub in subs) {
          final subTitle = sub.toString().trim();
          if (subTitle.isEmpty) continue;
          newNodes.add({
            'id': 'sub_${nowTs}_${order++}',
            'parentId': topicId,
            'nodeType': 'subtopic',
            'title': subTitle,
            'academicLevel': academicLevel,
            'sourceOrigin': 'official_syllabus',
            'confirmed': true,
            'archived': false,
            'sortOrder': order,
          });
        }
      }
    }

    await saveSyllabusNodes(notebookId, [...newNodes, ...previous]);
    await mapSourcesToTopics(notebookId);
    return newNodes;
  }

  /// Computes syllabus coverage counts across active syllabus nodes.
  static Map<String, int> computeCoverageStats(String notebookId) {
    final nodes = getSyllabusNodes(notebookId)
        .where((n) => n['nodeType'] == 'topic' || n['nodeType'] == 'subtopic')
        .toList();
    final mappings = getSourceMappings(notebookId);
    final coveredIds = mappings
        .where((m) => m['coverageStatus'] == 'covered')
        .map((m) => m['nodeId']?.toString())
        .toSet();
    final partialIds = mappings
        .where((m) => m['coverageStatus'] == 'partial')
        .map((m) => m['nodeId']?.toString())
        .toSet();

    int covered = 0;
    int partial = 0;
    int uncovered = 0;
    for (final n in nodes) {
      final id = n['id']?.toString();
      if (coveredIds.contains(id)) {
        covered++;
      } else if (partialIds.contains(id)) {
        partial++;
      } else {
        uncovered++;
      }
    }
    return {
      'total': nodes.length,
      'covered': covered,
      'partial': partial,
      'uncovered': uncovered,
    };
  }

  /// Deterministically maps uploaded documents (Notes, Books, PYQs, Syllabus)
  /// to syllabus topics/subtopics with source authority & confidence (SAGE-003).
  static Future<List<Map<String, dynamic>>> mapSourcesToTopics(
    String notebookId, {
    List<Map<String, dynamic>>? overrideDocs,
  }) async {
    final nodes = getSyllabusNodes(notebookId)
        .where((n) => n['nodeType'] == 'topic' || n['nodeType'] == 'subtopic')
        .toList();
    if (nodes.isEmpty) return const [];

    final docs = overrideDocs ?? OfflineCacheService.getNotebookDocuments(notebookId);
    final List<Map<String, dynamic>> mappings = [];

    for (final doc in docs) {
      final content = (doc['content'] as String? ?? '').toLowerCase();
      if (content.trim().length < 20) continue;
      final fileName = doc['fileName'] as String? ?? 'Document';
      final section = (doc['section'] as String? ?? 'Notes').toLowerCase();
      final authority = section.contains('syllabus')
          ? 'official_syllabus'
          : (section.contains('paper') || section.contains('pyq')
              ? 'pyq'
              : (section.contains('book') ? 'textbook' : 'teacher_notes'));

      for (final node in nodes) {
        final nodeId = node['id']?.toString() ?? '';
        final title = (node['title'] as String? ?? '').trim();
        if (nodeId.isEmpty || title.isEmpty) continue;
        final terms = title
            .toLowerCase()
            .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
            .where((w) => w.length >= 3)
            .toList();
        if (terms.isEmpty) continue;

        final hits = terms.where((t) => content.contains(t)).length;
        if (hits == 0) continue;
        final ratio = hits / terms.length;
        if (ratio < 0.4) continue;

        mappings.add({
          'id': 'map_${nodeId}_${fileName.hashCode}',
          'notebookId': notebookId,
          'nodeId': nodeId,
          'sourceName': fileName,
          'section': doc['section'] ?? 'Notes',
          'sourceAuthority': authority,
          'coverageStatus': ratio >= 0.75 ? 'covered' : 'partial',
          'confidence': double.parse(ratio.clamp(0.4, 0.99).toStringAsFixed(2)),
        });
      }
    }

    await saveSourceMappings(notebookId, mappings);
    return mappings;
  }

  /// Returns a unified knowledge map for a syllabus topic: mapped sources,
  /// PYQs, generated artifacts, coverage status, and unresolved gaps (SAGE-003).
  static Map<String, dynamic> getTopicKnowledgeMap(
    String notebookId,
    String nodeId,
  ) {
    final nodes = getSyllabusNodes(notebookId);
    final node = nodes.firstWhere(
      (n) => n['id'] == nodeId,
      orElse: () => <String, dynamic>{},
    );
    final title = (node['title'] as String? ?? '').trim();
    final mappings =
        getSourceMappings(notebookId).where((m) => m['nodeId'] == nodeId).toList();
    final pyqs = mappings.where((m) => m['sourceAuthority'] == 'pyq').toList();
    final artifacts = getArtifacts(notebookId).where((a) {
      if (a['nodeId'] == nodeId) return true;
      final label = (a['topicLabel'] as String? ?? '').toLowerCase();
      return title.isNotEmpty && label.contains(title.toLowerCase());
    }).toList();

    final hasCovered = mappings.any((m) => m['coverageStatus'] == 'covered');
    final coverage = hasCovered
        ? 'covered'
        : (mappings.isNotEmpty ? 'partial' : 'uncovered_gap');

    return {
      'node': node,
      'coverageStatus': coverage,
      'mappedSources': mappings,
      'pyqs': pyqs,
      'artifacts': artifacts,
      'hasUnresolvedGap': mappings.isEmpty,
    };
  }

  /// Distinguishes "not found in uploaded material" from "not part of the syllabus" (SAGE-003).
  static String classifyTopicStatus(
    String notebookId,
    String query, {
    bool hasEvidenceInUploadedDocs = false,
  }) {
    final nodes = getSyllabusNodes(notebookId)
        .where((n) => n['nodeType'] == 'topic' || n['nodeType'] == 'subtopic')
        .toList();
    if (nodes.isEmpty) {
      return hasEvidenceInUploadedDocs
          ? 'covered_in_sources'
          : 'not_found_in_uploaded_material';
    }

    final qTerms = query
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((w) => w.length >= 3)
        .toSet();
    final inSyllabus = nodes.any((n) {
      final title = (n['title'] as String? ?? '').toLowerCase();
      return qTerms.any((t) => title.contains(t));
    });

    if (!inSyllabus) {
      return hasEvidenceInUploadedDocs
          ? 'outside_syllabus_but_in_sources'
          : 'not_part_of_the_syllabus';
    }
    return hasEvidenceInUploadedDocs
        ? 'in_syllabus_and_covered'
        : 'in_syllabus_not_found_in_uploaded_material';
  }

  /// Detects duplicate syllabus topic names and uncovered syllabus topics (SAGE-003).
  static Map<String, List<String>> detectDuplicateAndMissingTopics(String notebookId) {
    final nodes = getSyllabusNodes(notebookId)
        .where((n) => n['nodeType'] == 'topic' || n['nodeType'] == 'subtopic')
        .toList();
    final mappings = getSourceMappings(notebookId);
    final mappedIds = mappings.map((m) => m['nodeId']?.toString()).toSet();

    final seen = <String>{};
    final duplicates = <String>[];
    final missing = <String>[];

    for (final n in nodes) {
      final title = (n['title'] as String? ?? '').trim();
      final lower = title.toLowerCase();
      if (lower.isNotEmpty && !seen.add(lower)) {
        duplicates.add(title);
      }
      if (!mappedIds.contains(n['id']?.toString())) {
        missing.add(title);
      }
    }
    return {
      'duplicates': duplicates,
      'missingCoverage': missing,
    };
  }
}
