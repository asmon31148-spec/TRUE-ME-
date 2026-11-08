import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
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

  static bool _hasDismissedThisSession = false;
  static String? _dismissedVersion;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 60),
  ));

  /// Marks a specific version as dismissed so it doesn't pop up again repeatedly.
  static Future<void> markUpdateDismissed(String version) async {
    _hasDismissedThisSession = true;
    _dismissedVersion = version;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_dismissed_update_version', version);
    } catch (_) {}
  }

  /// Checks GitHub Releases API for a newer APK release.
  Future<AppUpdateInfo?> checkForUpdate({bool force = false}) async {
    try {
      final response = await _dio.get(
        'https://api.github.com/repos/$repoOwner/$repoName/releases/latest',
        options: Options(headers: {'Accept': 'application/vnd.github.v3+json'}),
      );

      if (response.statusCode != 200) return null;

      final data = response.data;
      final tagName = (data['tag_name'] as String? ?? 'v1.0.0').replaceAll('v', '').trim();
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

      // If not forced and user dismissed or already installed this version, suppress popup
      if (!force) {
        if (_hasDismissedThisSession && _dismissedVersion == tagName) {
          return AppUpdateInfo(
            latestVersion: tagName,
            releaseNotes: body,
            apkDownloadUrl: downloadUrl,
            hasUpdate: false,
          );
        }

        try {
          final prefs = await SharedPreferences.getInstance();
          final lastDismissed = prefs.getString('last_dismissed_update_version');
          if (lastDismissed == tagName) {
            return AppUpdateInfo(
              latestVersion: tagName,
              releaseNotes: body,
              apkDownloadUrl: downloadUrl,
              hasUpdate: false,
            );
          }
        } catch (_) {}
      }

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
      final cleanCurrent = current.replaceAll(RegExp(r'[^0-9.]'), '');
      final cleanLatest = latest.replaceAll(RegExp(r'[^0-9.]'), '');

      final currentParts = cleanCurrent.split('.').where((s) => s.isNotEmpty).map(int.parse).toList();
      final latestParts = cleanLatest.split('.').where((s) => s.isNotEmpty).map(int.parse).toList();

      final maxLen = currentParts.length > latestParts.length ? currentParts.length : latestParts.length;
      for (int i = 0; i < maxLen; i++) {
        final cur = i < currentParts.length ? currentParts[i] : 0;
        final lat = i < latestParts.length ? latestParts[i] : 0;
        if (lat > cur) return true;
        if (lat < cur) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Downloads the APK file to accessible storage and returns the local File.
  Future<File> downloadApk({
    required String downloadUrl,
    required Function(double progress, String progressLabel) onProgress,
  }) async {
    Directory saveDir;
    try {
      final ext = await getExternalStorageDirectory();
      saveDir = ext ?? await getTemporaryDirectory();
    } catch (_) {
      saveDir = await getTemporaryDirectory();
    }

    final savePath = '${saveDir.path}/TrueMe-update.apk';
    final targetFile = File(savePath);

    if (await targetFile.exists()) {
      try {
        await targetFile.delete();
      } catch (_) {}
    }

    await _dio.download(
      downloadUrl,
      savePath,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          final pct = (received / total).clamp(0.0, 1.0);
          final recMb = (received / (1024 * 1024)).toStringAsFixed(1);
          final totalMb = (total / (1024 * 1024)).toStringAsFixed(1);
          onProgress(pct, '$recMb MB / $totalMb MB (${(pct * 100).toInt()}%)');
        } else {
          final recMb = (received / (1024 * 1024)).toStringAsFixed(1);
          onProgress(0.5, '$recMb MB downloaded...');
        }
      },
    );

    if (!await targetFile.exists() || await targetFile.length() < 100000) {
      throw StateError('Downloaded APK is incomplete or missing.');
    }

    return targetFile;
  }

  /// Checks Unknown Apps installation permission and opens the system Package Installer.
  static Future<OpenResult> installApk(File apkFile) async {
    if (Platform.isAndroid) {
      // 1. Request Unknown App Sources Install Permission on Android 8.0+
      try {
        final status = await Permission.requestInstallPackages.status;
        if (!status.isGranted) {
          final res = await Permission.requestInstallPackages.request();
          if (!res.isGranted) {
            await openAppSettings();
          }
        }
      } catch (e) {
        debugPrint('requestInstallPackages exception: $e');
      }
    }

    // 2. Launch Android PackageInstaller with explicit MIME type
    final result = await OpenFilex.open(
      apkFile.path,
      type: 'application/vnd.android.package-archive',
    );

    return result;
  }

  /// Opens the direct APK link in the user's web browser as an immediate fallback.
  static Future<void> launchBrowserDownload(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch browser download: $e');
    }
  }

  /// Displays the Liquid Glass in-app update prompt dialog.
  static void showUpdateDialog({
    required BuildContext context,
    required AppUpdateInfo info,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return _UpdateDialogWidget(info: info, dialogCtx: dialogCtx);
      },
    );
  }
}

class _UpdateDialogWidget extends StatefulWidget {
  final AppUpdateInfo info;
  final BuildContext dialogCtx;

  const _UpdateDialogWidget({required this.info, required this.dialogCtx});

  @override
  State<_UpdateDialogWidget> createState() => _UpdateDialogWidgetState();
}

class _UpdateDialogWidgetState extends State<_UpdateDialogWidget> {
  bool _isDownloading = false;
  bool _isDownloaded = false;
  double _progress = 0.0;
  String _progressLabel = '';
  File? _downloadedFile;
  String? _statusError;

  Future<void> _startDownloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _statusError = null;
    });

    try {
      UpdateService.markUpdateDismissed(widget.info.latestVersion);
      final file = await UpdateService().downloadApk(
        downloadUrl: widget.info.apkDownloadUrl,
        onProgress: (p, label) {
          if (mounted) {
            setState(() {
              _progress = p;
              _progressLabel = label;
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _isDownloading = false;
        _isDownloaded = true;
        _downloadedFile = file;
      });

      // Automatically launch Android package installer
      final result = await UpdateService.installApk(file);
      if (result.type != ResultType.done && mounted) {
        setState(() {
          _statusError = result.type == ResultType.permissionDenied
              ? 'Permission required: Please allow True Me to "Install unknown apps" in Settings.'
              : 'Could not launch package installer automatically (${result.message}). Use the buttons below.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusError = 'Download failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                color: _isDownloaded
                    ? AppColors.success.withOpacity(0.18)
                    : AppColors.accentCyan.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isDownloaded
                    ? Icons.check_circle_rounded
                    : Icons.system_update_rounded,
                color: _isDownloaded ? AppColors.success : AppColors.accentCyan,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isDownloaded
                  ? 'Update Downloaded!'
                  : 'True Me Update Available',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Version v${widget.info.latestVersion}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),

            if (!_isDownloading && !_isDownloaded) ...[
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.info.releaseNotes,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary.withOpacity(0.9),
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Progress Bar during download
            if (_isDownloading) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _progressLabel.isNotEmpty
                    ? _progressLabel
                    : 'Connecting to GitHub server...',
                style: const TextStyle(fontSize: 12, color: AppColors.accentCyan, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
            ],

            // Error or status note
            if (_statusError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusError!,
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action Buttons
            if (!_isDownloading && !_isDownloaded) ...[
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        UpdateService.markUpdateDismissed(widget.info.latestVersion);
                        Navigator.of(widget.dialogCtx).pop();
                      },
                      child: const Text('Later', style: TextStyle(color: Colors.white60)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassButton(
                      isPrimary: true,
                      onPressed: _startDownloadAndInstall,
                      child: const Text('Update Now'),
                    ),
                  ),
                ],
              ),
            ],

            if (_isDownloaded) ...[
              const Text(
                'Ready to install. If the Android installer did not open automatically, tap "Install Now".',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              GlassButton(
                isPrimary: true,
                width: double.infinity,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.install_mobile, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Install Now', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                onPressed: () async {
                  if (_downloadedFile != null) {
                    final res = await UpdateService.installApk(_downloadedFile!);
                    if (res.type != ResultType.done && mounted) {
                      setState(() {
                        _statusError = 'Android blocked the installer (${res.type}). Please enable "Install unknown apps" for True Me in Settings, or use browser download.';
                      });
                    }
                  }
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.open_in_browser, size: 16, color: AppColors.accentCyan),
                      label: const Text('Browser Download', style: TextStyle(color: AppColors.accentCyan, fontSize: 12)),
                      onPressed: () => UpdateService.launchBrowserDownload(widget.info.apkDownloadUrl),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        UpdateService.markUpdateDismissed(widget.info.latestVersion);
                        Navigator.of(widget.dialogCtx).pop();
                      },
                      child: const Text('Close', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
