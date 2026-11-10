import 'dart:io';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'offline_cache_service.dart';

class DriveService {
  static final DriveService instance = DriveService._internal();
  factory DriveService() => instance;
  DriveService._internal();

  static const List<String> _driveScopes = [
    drive.DriveApi.driveFileScope,
    drive.DriveApi.driveAppdataScope,
  ];

  // Do NOT pass serverClientId here on Android unless issuing server auth codes
  // for a Web OAuth client; passing an Android Client ID triggers ApiException 10.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: _driveScopes,
  );

  drive.DriveApi? _driveApi;
  String? _vaultFolderId;
  GoogleSignInAccount? _currentAccount;
  String? lastError;

  bool get isSignedIn => _driveApi != null;
  String? get userEmail => _currentAccount?.email ?? OfflineCacheService.getDriveEmail();

  String _formatSignInError(Object error) {
    final raw = error.toString();
    if (raw.contains('ApiException: 10') || raw.contains('DEVELOPER_ERROR')) {
      return 'Google OAuth config mismatch (Error 10). Register Android package "com.trueme.study.trueme" with release SHA-1 DA:F8:48:4B:5B:07:4F:AF:CF:C4:57:0D:D1:DB:34:FF:B0:FD:61:AB in Google Cloud Console.';
    }
    if (raw.contains('ApiException: 12500') || raw.contains('SIGN_IN_FAILED')) {
      return 'Google Sign-In failed (Error 12500). Configure the OAuth Consent Screen, add your Gmail as a Test User, and enable Google Drive API in Google Cloud Console.';
    }
    if (raw.contains('ApiException: 12501') || raw.contains('sign_in_canceled')) {
      return 'Google Drive sign-in was cancelled.';
    }
    if (raw.contains('ApiException: 7') || raw.contains('network_error') || raw.contains('SocketException')) {
      return 'Network error while connecting to Google Drive. Check your internet connection.';
    }
    if (raw.contains('accessNotConfigured') || raw.contains('403')) {
      return 'Google Drive API is not enabled or access was denied in Google Cloud Console ($raw).';
    }
    return 'Google Drive error: $raw';
  }

  /// Attempts silent sign-in on startup/resume if previously connected.
  Future<bool> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return false;
      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) return false;
      _currentAccount = account;
      _driveApi = drive.DriveApi(httpClient);
      lastError = null;
      await OfflineCacheService.saveDriveStatus(true, email: account.email);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Signs the user into Google Drive using interactive OAuth.
  Future<bool> signIn() async {
    lastError = null;
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        lastError = 'Google Drive sign-in was cancelled.';
        return false;
      }

      var httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) {
        await _googleSignIn.requestScopes(_driveScopes);
        httpClient = await _googleSignIn.authenticatedClient();
      }
      if (httpClient == null) {
        lastError = 'Could not obtain Google Drive OAuth permission token.';
        return false;
      }

      _currentAccount = account;
      _driveApi = drive.DriveApi(httpClient);
      await _ensureVaultFolder();
      await OfflineCacheService.saveDriveStatus(true, email: account.email);
      return true;
    } catch (e) {
      lastError = _formatSignInError(e);
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    _driveApi = null;
    _vaultFolderId = null;
    _currentAccount = null;
    await OfflineCacheService.saveDriveStatus(false);
  }

  /// Ensures a dedicated 'True Me' folder exists in user's Google Drive.
  Future<String> _ensureVaultFolder() async {
    if (_vaultFolderId != null) return _vaultFolderId!;
    if (_driveApi == null) throw StateError('Not signed in to Google Drive');

    final folderList = await _driveApi!.files.list(
      q: "mimeType = 'application/vnd.google-apps.folder' and (name = 'True Me' or name = 'TrueMe_Study_Vault') and trashed = false",
      spaces: 'drive',
    );

    if (folderList.files != null && folderList.files!.isNotEmpty) {
      _vaultFolderId = folderList.files!.first.id;
      return _vaultFolderId!;
    }

    final folderMeta = drive.File()
      ..name = 'True Me'
      ..mimeType = 'application/vnd.google-apps.folder';

    final createdFolder = await _driveApi!.files.create(folderMeta);
    _vaultFolderId = createdFolder.id;
    return _vaultFolderId!;
  }

  /// Lists files inside the user's Google Drive 'True Me' folder or recent Drive files.
  Future<List<drive.File>> listFiles({int pageSize = 25}) async {
    if (_driveApi == null) {
      final ok = await signIn();
      if (!ok) return [];
    }
    try {
      final res = await _driveApi!.files.list(
        q: "trashed = false and mimeType != 'application/vnd.google-apps.folder'",
        pageSize: pageSize,
        orderBy: 'modifiedTime desc',
        $fields: 'files(id, name, mimeType, size, modifiedTime)',
      );
      return res.files ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Uploads a local file directly into the user's Google Drive vault.
  Future<String> uploadFile(File file, {String? customName}) async {
    if (_driveApi == null) throw StateError('Not signed in to Google Drive');

    final folderId = await _ensureVaultFolder();
    final fileName = customName ?? file.path.split(Platform.pathSeparator).last;

    final driveFile = drive.File()
      ..name = fileName
      ..parents = [folderId];

    final media = drive.Media(file.openRead(), await file.length());
    final uploaded = await _driveApi!.files.create(
      driveFile,
      uploadMedia: media,
    );

    return uploaded.id ?? '';
  }

  /// Downloads a file from user's Google Drive as bytes.
  Future<List<int>> downloadFile(String fileId) async {
    if (_driveApi == null) throw StateError('Not signed in to Google Drive');

    final drive.Media response = await _driveApi!.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final List<int> dataStore = [];
    await response.stream.listen((data) {
      dataStore.addAll(data);
    }).asFuture();

    return dataStore;
  }

  /// Deletes the True Me Drive folder when requested by user ("Delete everything").
  Future<void> deleteVaultFolder() async {
    if (_driveApi == null) return;
    try {
      final folderId = await _ensureVaultFolder();
      await _driveApi!.files.delete(folderId);
      _vaultFolderId = null;
    } catch (_) {}
  }
}
