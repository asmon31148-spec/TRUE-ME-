import 'dart:io';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class DriveService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: dotenv.env['GOOGLE_DRIVE_CLIENT_ID'],
    scopes: [
      drive.DriveApi.driveFileScope,
      drive.DriveApi.driveAppdataScope,
    ],
  );

  drive.DriveApi? _driveApi;
  String? _vaultFolderId;

  bool get isSignedIn => _driveApi != null;

  /// Signs the user into Google Drive using OAuth.
  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return false;

      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) return false;

      _driveApi = drive.DriveApi(httpClient);
      await _ensureVaultFolder();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Ensures a dedicated 'TrueMe_Study_Vault' folder exists in user's Google Drive.
  Future<String> _ensureVaultFolder() async {
    if (_vaultFolderId != null) return _vaultFolderId!;
    if (_driveApi == null) throw StateError('Not signed in to Google Drive');

    final folderList = await _driveApi!.files.list(
      q: "mimeType = 'application/vnd.google-apps.folder' and name = 'TrueMe_Study_Vault' and trashed = false",
      spaces: 'drive',
    );

    if (folderList.files != null && folderList.files!.isNotEmpty) {
      _vaultFolderId = folderList.files!.first.id;
      return _vaultFolderId!;
    }

    // Create folder
    final folderMeta = drive.File()
      ..name = 'TrueMe_Study_Vault'
      ..mimeType = 'application/vnd.google-apps.folder';

    final createdFolder = await _driveApi!.files.create(folderMeta);
    _vaultFolderId = createdFolder.id;
    return _vaultFolderId!;
  }

  /// Uploads a local file directly into the user's Google Drive vault.
  /// Returns the Google Drive file ID.
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
}
