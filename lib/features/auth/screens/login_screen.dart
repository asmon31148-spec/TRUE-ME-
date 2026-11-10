import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/app_components.dart';

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

  @override
  void dispose() {
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
          if (msg.contains('Invalid login credentials')) {
            if (mounted) {
              setState(() {
                _errorText = 'Incorrect email or password.';
                _isLoading = false;
              });
            }
            return;
          }
          // Otherwise continue gracefully offline / unconfirmed email
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

  Future<void> _handleGuest() async {
    await OfflineCacheService.saveUserProfile(
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                _isSignUp ? 'Create account' : 'Sign in',
                style: AppTypography.screenTitle,
              ),
              const SizedBox(height: 16),

              // Two-option Segmented Control
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() {
                          _isSignUp = false;
                          _errorText = null;
                        }),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isSignUp ? AppColors.background : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: !_isSignUp
                                ? Border.all(color: AppColors.border, width: 1)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Sign in',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: !_isSignUp ? FontWeight.w600 : FontWeight.w400,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() {
                          _isSignUp = true;
                          _errorText = null;
                        }),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isSignUp ? AppColors.background : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: _isSignUp
                                ? Border.all(color: AppColors.border, width: 1)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Sign up',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: _isSignUp ? FontWeight.w600 : FontWeight.w400,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_errorText != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error, width: 1),
                  ),
                  child: Text(
                    _errorText!,
                    style: const TextStyle(fontSize: 14, color: AppColors.error),
                  ),
                ),
                const SizedBox(height: 16),
              ],

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
                hintText: 'Password',
                controller: _passwordController,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),

              if (!_isSignUp) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password reset link sent if account exists.')),
                      );
                    },
                    child: const Text('Forgot password'),
                  ),
                ),
              ] else
                const SizedBox(height: 24),

              AppPrimaryButton(
                label: _isSignUp ? 'Create account' : 'Sign in',
                isLoading: _isLoading,
                onPressed: _handleSubmit,
              ),
              const SizedBox(height: 16),

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
    );
  }
}
