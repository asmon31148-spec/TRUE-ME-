import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../app/theme/colors.dart';
import '../../shared/widgets/glass_button.dart';
import '../../shared/widgets/glass_card.dart';

class AppUpdateInfo {
  final String latestVersion;
  final String releaseNotes;
  final String apkDownloadUrl;
  final bool hasUpdate;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.releaseNotes,
    required this.apkDownloadUrl,
    required this.hasUpdate,
  });
}

/// Service to check, download, and install in-app updates directly from GitHub Releases.
class UpdateService {
  static const String repoOwner = 'asmon31148-spec';
  static const String repoName = 'TRUE-ME-';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  /// Checks GitHub Releases API for a newer APK release.
  Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final response = await _dio.get(
        'https://api.github.com/repos/$repoOwner/$repoName/releases/latest',
        options: Options(headers: {'Accept': 'application/vnd.github.v3+json'}),
      );

      if (response.statusCode != 200) return null;

      final data = response.data;
      final tagName = (data['tag_name'] as String? ?? 'v1.0.0').replaceAll('v', '');
      final body = data['body'] as String? ?? 'Bug fixes and performance improvements.';

      final assets = data['assets'] as List<dynamic>? ?? [];
      String downloadUrl = '';
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] as String? ?? '';
          break;
        }
      }

      if (downloadUrl.isEmpty && assets.isNotEmpty) {
        downloadUrl = assets.first['browser_download_url'] as String? ?? '';
      }

      // Check current package version
      String currentVersion = '1.0.0';
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        currentVersion = packageInfo.version;
      } catch (_) {}

      final hasUpdate = _isNewerVersion(currentVersion, tagName);

      return AppUpdateInfo(
        latestVersion: tagName,
        releaseNotes: body,
        apkDownloadUrl: downloadUrl,
        hasUpdate: hasUpdate,
      );
    } catch (_) {
      return null;
    }
  }

  bool _isNewerVersion(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();

      for (int i = 0; i < latestParts.length; i++) {
        final cur = i < currentParts.length ? currentParts[i] : 0;
        final lat = latestParts[i];
        if (lat > cur) return true;
        if (lat < cur) return false;
      }
      return false;
    } catch (_) {
      return current != latest;
    }
  }

  /// Downloads the APK with a progress callback and launches the Android installer.
  Future<void> downloadAndInstallApk({
    required String downloadUrl,
    required Function(double progress) onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final savePath = '${tempDir.path}/trueme-update.apk';

    await _dio.download(
      downloadUrl,
      savePath,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          onProgress(received / total);
        }
      },
    );

    // Launch Android package installer
    await OpenFilex.open(savePath);
  }

  /// Displays the Liquid Glass in-app update prompt dialog.
  static void showUpdateDialog({
    required BuildContext context,
    required AppUpdateInfo info,
  }) {
    double progress = 0.0;
    bool isDownloading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: GlassCard(
                borderRadius: 24,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.accentCyan.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.system_update_rounded,
                        color: AppColors.accentCyan,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'True Me Update Available',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Version v${info.latestVersion}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          info.releaseNotes,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary.withOpacity(0.9),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (isDownloading) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.accentCyan,
                          ),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Downloading ${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(dialogCtx).pop(),
                              child: Text(
                                'Later',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GlassButton(
                              isPrimary: true,
                              onPressed: () async {
                                setState(() {
                                  isDownloading = true;
                                });
                                await UpdateService().downloadAndInstallApk(
                                  downloadUrl: info.apkDownloadUrl,
                                  onProgress: (p) {
                                    setState(() {
                                      progress = p;
                                    });
                                  },
                                );
                                if (Navigator.of(dialogCtx).canPop()) {
                                  Navigator.of(dialogCtx).pop();
                                }
                              },
                              child: const Text('Update Now'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
