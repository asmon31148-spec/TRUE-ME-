import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/env_config.dart';
import 'offline_cache_service.dart';
import 'supabase_service.dart';

class MegaFileEntry {
  final String id;
  final String name;
  final int size;
  final String subject;
  final String folder;
  final DateTime? createdAt;

  const MegaFileEntry({
    required this.id,
    required this.name,
    required this.size,
    required this.subject,
    required this.folder,
    this.createdAt,
  });

  factory MegaFileEntry.fromMap(Map<String, dynamic> map) {
    return MegaFileEntry(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'file',
      size: (map['size'] as num? ?? 0).toInt(),
      subject: map['subject']?.toString() ?? 'General',
      folder: map['folder']?.toString() ?? 'True Me',
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) : null,
    );
  }
}

class MegaStorageStats {
  final int usedBytes;
  final int totalBytes;

  const MegaStorageStats({
    required this.usedBytes,
    required this.totalBytes,
  });

  double get usedGb => usedBytes / 1073741824.0;
  double get totalGb => totalBytes > 0 ? totalBytes / 1073741824.0 : 20.0;
  double get progress => totalBytes > 0 ? (usedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
  String get summaryLabel => '${usedGb.toStringAsFixed(2)} GB / ${totalGb.toStringAsFixed(0)} GB used';
}

/// Personal 20 GB Encrypted MEGA.nz Vault Service talking to the True Me MEGA Bridge.
class MegaVaultService {
  static final MegaVaultService instance = MegaVaultService._internal();
  factory MegaVaultService() => instance;
  MegaVaultService._internal();

  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  String get _tokenKey => 'trueme_mega_jwt_${OfflineCacheService.getUserId()}';

  String? _cachedToken;
  String? lastError;

  /// Clears in-memory Mega session on logout/account switch without deleting
  /// the outgoing TRUE ME user's persisted secure storage key.
  void clearActiveMemorySession() {
    _cachedToken = null;
    lastError = null;
  }

  String get bridgeUrl {
    final custom = OfflineCacheService.getMegaBridgeUrl().trim();
    if (custom.isNotEmpty) return _normalizeUrl(custom);
    final envUrl = EnvConfig.get('MEGA_BRIDGE_URL').trim();
    return envUrl.isNotEmpty ? _normalizeUrl(envUrl) : '';
  }

  bool get hasBridgeConfigured => bridgeUrl.isNotEmpty;
  bool get isSignedIn =>
      hasBridgeConfigured &&
      ((_cachedToken != null && _cachedToken!.isNotEmpty) || OfflineCacheService.isMegaConnected());
  String? get userEmail => OfflineCacheService.getMegaEmail();

  static String _normalizeUrl(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  Dio _client() {
    return Dio(
      BaseOptions(
        baseUrl: bridgeUrl,
        connectTimeout: const Duration(seconds: 45), // Allows Render/Railway cold-start wakeups
        receiveTimeout: const Duration(minutes: 4),
        sendTimeout: const Duration(minutes: 4),
      ),
    );
  }

  /// Loads cached JWT from encrypted device keystore (or Supabase user metadata after reinstall).
  Future<bool> restoreSession() async {
    try {
      _cachedToken = await _secure.read(key: _tokenKey);
      if (_cachedToken != null && _cachedToken!.isNotEmpty && hasBridgeConfigured) {
        await OfflineCacheService.saveMegaStatus(true, email: OfflineCacheService.getMegaEmail());
        return true;
      }

      // Reinstall / new-device recovery from authenticated user's Supabase metadata
      final cloud = SupabaseService.instance.getMegaVaultSession();
      if (cloud != null && hasBridgeConfigured) {
        final token = cloud['token'] ?? '';
        final email = cloud['email'] ?? '';
        if (token.isNotEmpty) {
          _cachedToken = token;
          await _secure.write(key: _tokenKey, value: token);
          await OfflineCacheService.saveMegaStatus(
            true,
            email: email.isNotEmpty ? email : null,
          );
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<String?> _getToken() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) return _cachedToken;
    try {
      _cachedToken = await _secure.read(key: _tokenKey);
    } catch (_) {}
    return _cachedToken;
  }

  String _humanizeError(Object err) {
    if (err is DioException) {
      final data = err.response?.data;
      if (data is Map && data['error'] != null) {
        return data['error'].toString();
      }
      if (err.type == DioExceptionType.connectionTimeout ||
          err.type == DioExceptionType.receiveTimeout) {
        return 'Storage bridge is waking up or timed out. Wait 15 seconds and tap Connect again.';
      }
      if (err.type == DioExceptionType.connectionError) {
        return 'Cannot reach MEGA Bridge Server ($bridgeUrl). Check internet or Server URL.';
      }
      return 'MEGA connection error (${err.response?.statusCode ?? err.message}).';
    }
    return err.toString();
  }

  /// Authenticates user's own MEGA account via Bridge Server and saves encrypted JWT.
  Future<bool> login({
    required String email,
    required String password,
    String? customBridgeUrl,
  }) async {
    lastError = null;
    if (customBridgeUrl != null && customBridgeUrl.trim().isNotEmpty) {
      await OfflineCacheService.saveMegaBridgeUrl(_normalizeUrl(customBridgeUrl));
    }

    if (!hasBridgeConfigured) {
      lastError = 'Enter your MEGA Bridge Server URL first (Render / Railway URL).';
      return false;
    }

    try {
      final dio = _client();
      final res = await dio.post(
        '/mega/login',
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      final data = Map<String, dynamic>.from(res.data as Map);
      final token = data['token']?.toString() ?? '';
      final megaIdentityHash = data['megaIdentityHash']?.toString() ?? '';
      if (token.isEmpty) {
        lastError = 'Bridge server returned an empty session token.';
        return false;
      }

      if (megaIdentityHash.isNotEmpty) {
        final conflictError = await SupabaseService.instance.claimMegaIdentity(
          megaEmail: email.trim(),
          megaIdentityHash: megaIdentityHash,
        );
        if (conflictError != null) {
          lastError = conflictError;
          return false;
        }
      }

      _cachedToken = token;
      await _secure.write(key: _tokenKey, value: token);

      final used = (data['storageUsed'] as num? ?? 0).toInt();
      final total = (data['storageTotal'] as num? ?? 21474836480).toInt();
      await OfflineCacheService.saveMegaStatus(
        true,
        email: email.trim(),
        usedBytes: used,
        totalBytes: total,
      );
      await SupabaseService.instance.saveMegaVaultSession(
        token: token,
        email: email.trim(),
      );
      return true;
    } catch (e) {
      lastError = _humanizeError(e);
      return false;
    }
  }

  /// Disconnects MEGA Vault and wipes encrypted session token from device & cloud profile.
  Future<void> disconnect() async {
    _cachedToken = null;
    lastError = null;
    try {
      await _secure.delete(key: _tokenKey);
    } catch (_) {}
    await SupabaseService.instance.unlinkMegaIdentity();
    await SupabaseService.instance.clearMegaVaultSession();
    await OfflineCacheService.saveMegaStatus(false);
  }

  /// Fetches live 20 GB quota usage stats from user's MEGA account.
  Future<MegaStorageStats?> getStats() async {
    final token = await _getToken();
    if (token == null || token.isEmpty || !hasBridgeConfigured) return null;

    try {
      final res = await _client().get(
        '/mega/stats',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      final used = (data['used'] as num? ?? 0).toInt();
      final total = (data['total'] as num? ?? 21474836480).toInt();
      await OfflineCacheService.saveMegaStatus(
        true,
        email: OfflineCacheService.getMegaEmail(),
        usedBytes: used,
        totalBytes: total,
      );
      return MegaStorageStats(usedBytes: used, totalBytes: total);
    } catch (_) {
      return MegaStorageStats(
        usedBytes: OfflineCacheService.getMegaUsedBytes(),
        totalBytes: OfflineCacheService.getMegaTotalBytes(),
      );
    }
  }

  /// Uploads a study file into `True Me / [subject] / [section]` inside user's MEGA account.
  Future<String> uploadFile(
    File file, {
    String? customName,
    String? subject,
    String? section,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty || !hasBridgeConfigured) {
      throw StateError('MEGA Vault is not connected.');
    }

    final fileName = customName ?? file.path.split(Platform.pathSeparator).last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
      if (subject != null && subject.trim().isNotEmpty) 'subject': subject.trim(),
      if (section != null && section.trim().isNotEmpty) 'section': section.trim(),
      'customName': fileName,
    });

    final res = await _client().post(
      '/mega/upload',
      data: formData,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    return data['fileId']?.toString() ?? '';
  }

  /// Lists files stored inside the user's `True Me` MEGA folder.
  Future<List<MegaFileEntry>> listFiles({String? subject}) async {
    lastError = null;
    final token = await _getToken();
    if (token == null || token.isEmpty || !hasBridgeConfigured) return [];

    try {
      final res = await _client().get(
        '/mega/files',
        queryParameters: subject != null && subject.isNotEmpty ? {'subject': subject} : null,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      final rawList = data['files'] as List? ?? [];
      return rawList
          .map((item) => MegaFileEntry.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      lastError = _humanizeError(e);
      return [];
    }
  }

  /// Downloads raw bytes for a file from user's MEGA vault.
  Future<List<int>> downloadFile(String fileId) async {
    final token = await _getToken();
    if (token == null || token.isEmpty || !hasBridgeConfigured) {
      throw StateError('MEGA Vault is not connected.');
    }

    final res = await _client().get<List<int>>(
      '/mega/download/$fileId',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        responseType: ResponseType.bytes,
      ),
    );
    return res.data ?? [];
  }

  /// Deletes the `True Me` folder inside user's MEGA account when deleting all data.
  Future<void> deleteVaultFolder() async {
    final token = await _getToken();
    if (token == null || token.isEmpty || !hasBridgeConfigured) return;
    try {
      await _client().delete(
        '/mega/vault',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {}
  }
}
