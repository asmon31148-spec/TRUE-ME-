import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/mega_vault_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/true_me_ui.dart';

/// Soft Ivory & Lavender modal sheet for connecting a student's 20 GB Free MEGA.nz Vault.
class MegaConnectSheet extends StatefulWidget {
  const MegaConnectSheet({super.key});

  static Future<bool> show(BuildContext context) async {
    final res = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MegaConnectSheet(),
    );
    return res == true;
  }

  @override
  State<MegaConnectSheet> createState() => _MegaConnectSheetState();
}

class _MegaConnectSheetState extends State<MegaConnectSheet> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  late final TextEditingController _bridgeCtrl;

  bool _isBusy = false;
  bool _obscurePassword = true;
  bool _showBridgeConfig = false;
  String? _errorText;
  MegaStorageStats? _stats;

  @override
  void initState() {
    super.initState();
    _bridgeCtrl = TextEditingController(text: MegaVaultService.instance.bridgeUrl);
    _showBridgeConfig = !MegaVaultService.instance.hasBridgeConfigured;
    if (MegaVaultService.instance.isSignedIn) {
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    final s = await MegaVaultService.instance.getStats();
    if (mounted && s != null) {
      setState(() => _stats = s);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _bridgeCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final bridge = _bridgeCtrl.text.trim();

    if (bridge.isEmpty) {
      setState(() {
        _showBridgeConfig = true;
        _errorText = 'Paste your MEGA Bridge Server URL (e.g. from Render or Railway).';
      });
      return;
    }
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _errorText = 'Enter your MEGA email and password.');
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _isBusy = true;
      _errorText = null;
    });

    final ok = await MegaVaultService.instance.login(
      email: email,
      password: pass,
      customBridgeUrl: bridge,
    );

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _isBusy = false;
        _errorText = MegaVaultService.instance.lastError ?? 'Could not connect MEGA account.';
      });
    }
  }

  Future<void> _disconnect() async {
    HapticFeedback.mediumImpact();
    setState(() => _isBusy = true);
    await MegaVaultService.instance.disconnect();
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final connected = MegaVaultService.instance.isSignedIn;
    final email = MegaVaultService.instance.userEmail ?? 'Connected';

    return Container(
      decoration: BoxDecoration(
        color: context.bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: TrueMeAmbientBackground(
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: AppColors.sageOrbGradient,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MEGA 20 GB Vault',
                              style: AppTypography.sectionHeading.copyWith(color: context.textPrimary),
                            ),
                            Text(
                              'Encrypted personal storage · No Google OAuth wall',
                              style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: context.textSecondary),
                        onPressed: () => Navigator.pop(context, false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (connected) ...[
                    TrueMeCard(
                      borderRadius: 20,
                      padding: const EdgeInsets.all(16),
                      gradient: isDark ? AppColors.heroFocusDarkGradient : AppColors.heroFocusLightGradient,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.verified_user_rounded, color: AppColors.success, size: 19),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: context.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          AppProgressBar(value: _stats?.progress ?? 0.02),
                          const SizedBox(height: 8),
                          Text(
                            _stats?.summaryLabel ?? '20 GB free personal study vault active',
                            style: AppTypography.smallLabel.copyWith(color: context.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TrueMeCard(
                      borderRadius: 18,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(Icons.folder_copy_outlined, size: 20, color: context.accentColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'PDFs, photos & study exports save automatically inside MEGA / True Me.',
                              style: AppTypography.secondary.copyWith(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppSecondaryButton(
                      label: _isBusy ? 'Disconnecting...' : 'Disconnect MEGA Vault',
                      icon: const Icon(Icons.link_off_rounded, size: 18),
                      onPressed: _isBusy ? null : _disconnect,
                    ),
                  ] else ...[
                    TrueMeCard(
                      borderRadius: 18,
                      padding: const EdgeInsets.all(14),
                      color: isDark ? AppColors.darkAccentWash : AppColors.milkyLavender,
                      showShadow: false,
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 19, color: context.accentColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Every user gets 20 GB free inside their own MEGA account — zero server storage cost.',
                              style: AppTypography.secondary.copyWith(
                                fontSize: 13,
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      label: 'MEGA Email',
                      hintText: 'you@example.com',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icon(Icons.email_outlined, size: 19, color: context.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    AppInput(
                      label: 'MEGA Password',
                      hintText: 'Enter your MEGA password',
                      controller: _passCtrl,
                      obscureText: _obscurePassword,
                      prefixIcon: Icon(Icons.key_rounded, size: 19, color: context.textSecondary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 19,
                          color: context.textSecondary,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse('https://mega.nz/register');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 15),
                          label: const Text('Create free 20 GB MEGA'),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _showBridgeConfig = !_showBridgeConfig),
                          child: Text(_showBridgeConfig ? 'Hide Server URL' : 'Server URL'),
                        ),
                      ],
                    ),
                    if (_showBridgeConfig) ...[
                      const SizedBox(height: 6),
                      AppInput(
                        label: 'MEGA Bridge Server URL',
                        hintText: 'https://trueme-mega-bridge.onrender.com',
                        controller: _bridgeCtrl,
                        keyboardType: TextInputType.url,
                        prefixIcon: Icon(Icons.dns_outlined, size: 19, color: context.textSecondary),
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (_errorText != null) ...[
                      const SizedBox(height: 10),
                      TrueMeCard(
                        borderRadius: 14,
                        padding: const EdgeInsets.all(12),
                        color: isDark ? const Color(0xFF321822) : AppColors.pastelRose,
                        showShadow: false,
                        child: Text(
                          _errorText!,
                          style: const TextStyle(fontSize: 13, color: AppColors.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    TrueMePrimaryButton(
                      label: _isBusy ? 'Connecting...' : 'Connect MEGA 20 GB Vault',
                      isLoading: _isBusy,
                      leadingIcon: const Icon(Icons.cloud_upload_rounded, size: 18, color: Colors.white),
                      onPressed: _isBusy ? null : _connect,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
