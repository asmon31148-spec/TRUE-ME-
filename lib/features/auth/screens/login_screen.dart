import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/mega_vault_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/true_me_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSignUp = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorText;
  bool _isLoading = false;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = SupabaseService.instance.onAuthStateChange?.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn && data.session != null && mounted) {
        final user = data.session!.user;
        final meta = user.userMetadata ?? {};
        final name = (meta['full_name'] ?? meta['name'] ?? user.email?.split('@').first ?? 'Student')
            .toString();
        final email = user.email ?? 'student@trueme.app';

        await OfflineCacheService.saveUserProfile(
          userId: user.id,
          name: name,
          email: email,
          isLoggedIn: true,
          hasCompletedOnboarding: true,
        );
        await MegaVaultService.instance.restoreSession();
        if (mounted) {
          setState(() => _isLoading = false);
          context.go('/today');
        }
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    setState(() => _errorText = null);

    if (_isSignUp && name.isEmpty) {
      setState(() => _errorText = 'Enter your name');
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorText = 'Enter a valid email address');
      return;
    }

    if (password.length < 6) {
      setState(() => _errorText = 'Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? cloudUid;
      String resolvedName = _isSignUp ? name : (name.isNotEmpty ? name : email.split('@').first);

      if (SupabaseService.instance.isReady) {
        try {
          if (_isSignUp) {
            final res = await SupabaseService.instance.signUp(
              email: email,
              password: password,
              name: name,
            );
            cloudUid = res?.user?.id;
          } else {
            final res = await SupabaseService.instance.signIn(
              email: email,
              password: password,
            );
            cloudUid = res?.user?.id;
            final metaName = res?.user?.userMetadata?['full_name'] as String?;
            if (metaName != null && metaName.trim().isNotEmpty) {
              resolvedName = metaName.trim();
            }
          }
        } catch (authErr) {
          final msg = authErr.toString();
          final isOfflineError = msg.contains('SocketException') ||
              msg.contains('TimeoutException') ||
              msg.contains('Failed host lookup') ||
              msg.contains('ClientException');
          if (!isOfflineError) {
            String friendly = 'Authentication failed. Please check your credentials.';
            if (msg.contains('Invalid login credentials')) {
              friendly = 'Incorrect email or password.';
            } else if (msg.contains('already registered') || msg.contains('User already')) {
              friendly = 'An account with this email already exists. Please sign in instead.';
            } else if (msg.contains('Email not confirmed')) {
              friendly = 'Please confirm your email address before signing in.';
            } else if (msg.contains('Password')) {
              friendly = 'Password does not meet security requirements.';
            }
            if (mounted) {
              setState(() {
                _errorText = friendly;
                _isLoading = false;
              });
            }
            return;
          }
        }
      }

      await OfflineCacheService.saveUserProfile(
        userId: cloudUid,
        name: resolvedName,
        email: email,
        isLoggedIn: true,
        hasCompletedOnboarding: true,
      );

      if (!_isSignUp) {
        await OfflineCacheService.syncFromCloud();
      }

      if (!mounted) return;
      if (_isSignUp) {
        context.go('/setup-profile');
      } else {
        context.go('/today');
      }
    } catch (e) {
      setState(() => _errorText = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleOAuthSignIn(OAuthProvider provider, String label) async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final launched = await SupabaseService.instance.signInWithOAuthProvider(provider);
      if (!launched && mounted) {
        setState(() {
          _isLoading = false;
          _errorText = 'Could not open $label Sign-In. Please try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = '$label Sign-In failed: $e';
        });
      }
    }
  }

  Future<void> _handleGuest() async {
    final anon = await SupabaseService.instance.signInAnonymously();
    await OfflineCacheService.saveUserProfile(
      userId: anon?.user?.id,
      name: 'Student',
      email: 'student@trueme.app',
      isLoggedIn: true,
      hasCompletedOnboarding: true,
    );
    if (mounted) context.go('/today');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: TrueMeAmbientBackground(
        intenseLavender: true,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  _isSignUp ? 'Create Account' : 'Welcome Back',
                  style: AppTypography.editorialHero.copyWith(
                    fontSize: 30,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isSignUp
                      ? 'Set up your personal study companion.'
                      : 'Sign in to continue your learning journey.',
                  style: AppTypography.secondary.copyWith(color: context.textSecondary),
                ),
                const SizedBox(height: 22),

                // Pill Segmented Control
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: context.borderColor),
                    boxShadow: context.cardShadow,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _isSignUp = false;
                            _errorText = null;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              gradient: !_isSignUp ? AppColors.indigoButtonGradient : null,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: !_isSignUp ? FontWeight.w700 : FontWeight.w500,
                                color: !_isSignUp ? Colors.white : context.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _isSignUp = true;
                            _errorText = null;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              gradient: _isSignUp ? AppColors.indigoButtonGradient : null,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: _isSignUp ? FontWeight.w700 : FontWeight.w500,
                                color: _isSignUp ? Colors.white : context.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                if (_errorText != null) ...[
                  TrueMeCard(
                    borderRadius: 14,
                    padding: const EdgeInsets.all(14),
                    borderColor: AppColors.error,
                    child: Text(_errorText!, style: const TextStyle(fontSize: 14, color: AppColors.error)),
                  ),
                  const SizedBox(height: 16),
                ],

                TrueMeCard(
                  borderRadius: 22,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      if (_isSignUp) ...[
                        AppInput(
                          label: 'Name',
                          hintText: 'Your name',
                          controller: _nameController,
                        ),
                        const SizedBox(height: 16),
                      ],
                      AppInput(
                        label: 'Email',
                        hintText: 'name@example.com',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      AppInput(
                        label: 'Password',
                        hintText: 'Password (min 6 characters)',
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 20,
                            color: context.textSecondary,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ],
                  ),
                ),

                if (!_isSignUp)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password reset link sent if account exists.')),
                        );
                      },
                      child: const Text('Forgot password?'),
                    ),
                  )
                else
                  const SizedBox(height: 22),

                TrueMePrimaryButton(
                  label: _isSignUp ? 'Create Account' : 'Sign In',
                  isLoading: _isLoading,
                  onPressed: _handleSubmit,
                ),
                const SizedBox(height: 12),
                AppSecondaryButton(
                  label: 'Continue with Google',
                  icon: const Icon(Icons.g_mobiledata_rounded, size: 22),
                  onPressed: _isLoading
                      ? null
                      : () => _handleOAuthSignIn(OAuthProvider.google, 'Google'),
                ),
                const SizedBox(height: 10),
                AppSecondaryButton(
                  label: 'Continue with Facebook',
                  icon: const Icon(Icons.facebook_rounded, size: 20),
                  onPressed: _isLoading
                      ? null
                      : () => _handleOAuthSignIn(OAuthProvider.facebook, 'Facebook'),
                ),
                const SizedBox(height: 14),
                Center(
                  child: TextButton(
                    onPressed: _handleGuest,
                    child: const Text('Continue as guest'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
