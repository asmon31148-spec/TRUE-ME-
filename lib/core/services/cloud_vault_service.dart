import 'dart:io';
import 'drive_service.dart';
import 'mega_vault_service.dart';

class CloudUploadResult {
  final String provider; // 'mega' | 'drive'
  final String fileId;

  const CloudUploadResult({required this.provider, required this.fileId});
}

/// Smart Cloud Vault Router: prefers the user's connected 20 GB MEGA.nz Vault
/// (zero OAuth verification friction) and falls back to Google Drive if connected.
class CloudVaultService {
  CloudVaultService._();

  static bool get isAnyVaultConnected =>
      MegaVaultService.instance.isSignedIn || DriveService.instance.isSignedIn;

  static String get activeVaultName {
    if (MegaVaultService.instance.isSignedIn) return 'MEGA Vault';
    if (DriveService.instance.isSignedIn) return 'Google Drive';
    return 'Local';
  }

  static Future<CloudUploadResult?> uploadFile(
    File file, {
    String? customName,
    String? subject,
    String? section,
  }) async {
    if (MegaVaultService.instance.isSignedIn) {
      try {
        final id = await MegaVaultService.instance.uploadFile(
          file,
          customName: customName,
          subject: subject,
          section: section,
        );
        if (id.isNotEmpty) {
          return CloudUploadResult(provider: 'mega', fileId: id);
        }
      } catch (_) {}
    }

    if (DriveService.instance.isSignedIn) {
      try {
        final id = await DriveService.instance.uploadFile(
          file,
          customName: customName,
          subject: subject,
          section: section,
        );
        if (id.isNotEmpty) {
          return CloudUploadResult(provider: 'drive', fileId: id);
        }
      } catch (_) {}
    }

    return null;
  }

  static Future<bool> deleteFile(String fileId) async {
    if (fileId.trim().isEmpty) return false;
    if (MegaVaultService.instance.isSignedIn) {
      return await MegaVaultService.instance.deleteFile(fileId);
    }
    return false;
  }

  static Future<bool> renameFile(String fileId, String newName) async {
    if (fileId.trim().isEmpty || newName.trim().isEmpty) return false;
    if (MegaVaultService.instance.isSignedIn) {
      return await MegaVaultService.instance.renameFile(fileId, newName);
    }
    return false;
  }

  static Future<void> deleteAllCloudVaults() async {
    if (MegaVaultService.instance.isSignedIn) {
      await MegaVaultService.instance.deleteVaultFolder();
      await MegaVaultService.instance.disconnect();
    }
    if (DriveService.instance.isSignedIn) {
      await DriveService.instance.deleteVaultFolder();
      await DriveService.instance.signOut();
    }
  }
}
