import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/mega_vault_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/true_me_ui.dart';

/// Full-screen Soft Ivory & Lavender page for connecting a student's 20 GB Free MEGA.nz Vault.
class MegaConnectSheet extends StatefulWidget {
  const MegaConnectSheet({super.key});

  static Future<bool> show(BuildContext context) async {
    final res = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(builder: (_) => const MegaConnectSheet()),
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

  Future<void> _openMegaRegister() async {
    final uri = Uri.parse('https://mega.nz/register');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _connect() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final bridge = _bridgeCtrl.text.trim();

    if (bridge.isEmpty) {
      setState(() {
        _showBridgeConfig = true;
        _errorText = 'Paste your MEGA Bridge Server URL (e.g. from Render).';
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
      Navigator.of(context).pop(true);
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
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final connected = MegaVaultService.instance.isSignedIn;
    final email = MegaVaultService.instance.userEmail ?? 'Connected';

    return Scaffold(
      backgroundColor: context.bgColor,
      body: TrueMeAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              TrueMeTopBar(
                title: 'MEGA 20 GB Vault',
                onBack: () => Navigator.of(context).pop(false),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero Card matching True Me Ivory & Lavender design
                      TrueMeCard(
                        borderRadius: 24,
                        padding: const EdgeInsets.all(18),
                        gradient: isDark
                            ? AppColors.heroFocusDarkGradient
                            : AppColors.heroFocusLightGradient,
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: AppColors.sageOrbGradient,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.cloud_done_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    connected ? 'Vault Connected' : 'Personal 20 GB Cloud',
                                    style: AppTypography.sectionHeading.copyWith(
                                      fontSize: 18,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Encrypted study storage inside your own MEGA.nz account.',
                                    style: AppTypography.secondary.copyWith(
                                      fontSize: 13,
                                      color: context.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      if (connected) ...[
                        TrueMeCard(
                          borderRadius: 20,
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.verified_user_rounded,
                                    color: AppColors.success,
                                    size: 20,
                                  ),
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
                              const SizedBox(height: 12),
                              AppProgressBar(value: _stats?.progress ?? 0.02),
                              const SizedBox(height: 8),
                              Text(
                                _stats?.summaryLabel ?? '20 GB free personal study vault active',
                                style: AppTypography.smallLabel.copyWith(
                                  color: context.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
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
                        const SizedBox(height: 24),
                        AppSecondaryButton(
                          label: _isBusy ? 'Disconnecting...' : 'Disconnect MEGA Vault',
                          icon: const Icon(Icons.link_off_rounded, size: 18),
                          onPressed: _isBusy ? null : _disconnect,
                        ),
                      ] else ...[
                        // Clear Sign-Up vs Sign-In Guidance Card
                        TrueMeCard(
                          borderRadius: 18,
                          padding: const EdgeInsets.all(14),
                          color: isDark ? AppColors.darkAccentWash : AppColors.milkyLavender,
                          showShadow: false,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 19,
                                    color: context.accentColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Already have a MEGA account? Sign in below.',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'New to MEGA? First create & verify your free 20 GB account on mega.nz, then come back and sign in.',
                                style: AppTypography.secondary.copyWith(
                                  fontSize: 12.5,
                                  color: context.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _openMegaRegister,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.open_in_new_rounded,
                                      size: 15,
                                      color: context.accentColor,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Create free 20 GB MEGA account',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: context.accentColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        TrueMeCard(
                          borderRadius: 22,
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppInput(
                                label: 'MEGA Email',
                                hintText: 'you@example.com',
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: Icon(
                                  Icons.email_outlined,
                                  size: 19,
                                  color: context.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 14),
                              AppInput(
                                label: 'MEGA Password',
                                hintText: 'Enter your MEGA password',
                                controller: _passCtrl,
                                obscureText: _obscurePassword,
                                prefixIcon: Icon(
                                  Icons.key_rounded,
                                  size: 19,
                                  color: context.textSecondary,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 19,
                                    color: context.textSecondary,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              if (_showBridgeConfig) ...[
                                const SizedBox(height: 14),
                                AppInput(
                                  label: 'MEGA Bridge Server URL',
                                  hintText: 'https://trueme-mega-bridge.onrender.com',
                                  controller: _bridgeCtrl,
                                  keyboardType: TextInputType.url,
                                  prefixIcon: Icon(
                                    Icons.dns_outlined,
                                    size: 19,
                                    color: context.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () =>
                                      setState(() => _showBridgeConfig = !_showBridgeConfig),
                                  child: Text(
                                    _showBridgeConfig ? 'Hide Server URL' : 'Server URL',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: context.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              if (_errorText != null) ...[
                                const SizedBox(height: 6),
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
                              const SizedBox(height: 16),
                              TrueMePrimaryButton(
                                label: _isBusy ? 'Connecting...' : 'Connect MEGA 20 GB Vault',
                                isLoading: _isBusy,
                                leadingIcon: const Icon(
                                  Icons.cloud_upload_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                onPressed: _isBusy ? null : _connect,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
