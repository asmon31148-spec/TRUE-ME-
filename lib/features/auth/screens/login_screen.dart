import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    setState(() => _errorMessage = null);

    if (_isSignUp && name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your student name');
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    if (password.length < 4) {
      setState(() => _errorMessage = 'Password must be at least 4 characters');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Determine student display name
      final displayName = _isSignUp
          ? name
          : (name.isNotEmpty
              ? name
              : email.split('@').first);

      await OfflineCacheService.saveUserProfile(
        name: displayName,
        email: email,
        isLoggedIn: true,
        hasCompletedOnboarding: true,
      );

      if (!mounted) return;

      if (_isSignUp) {
        context.go('/setup-profile');
      } else {
        context.go('/library');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Authentication failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGuestLogin() async {
    setState(() => _isLoading = true);
    await OfflineCacheService.saveUserProfile(
      name: 'Asmon',
      email: 'asmon@trueme.ai',
      isLoggedIn: true,
      hasCompletedOnboarding: true,
    );
    if (mounted) {
      context.go('/library');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background ambient lights
          Positioned(
            top: 40,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.25),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withOpacity(0.2),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand Icon
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.sageGlowGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary,
                            blurRadius: 24,
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.school, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isSignUp ? 'Create Your Account' : 'Welcome to True Me',
                      style: AppTypography.displayMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isSignUp
                          ? 'Join 100% free — powered by Sage AI'
                          : 'Sign in to access your library & study plan',
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: 24),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Login Glass Container
                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      borderRadius: 28,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_isSignUp) ...[
                            TextField(
                              controller: _nameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Your Name (e.g. Asmon)',
                                labelStyle: const TextStyle(color: AppColors.textSecondary),
                                prefixIcon: const Icon(Icons.person_outline, color: AppColors.accentCyan),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.04),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              labelStyle: const TextStyle(color: AppColors.textSecondary),
                              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.accentCyan),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.04),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: const TextStyle(color: AppColors.textSecondary),
                              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.accentCyan),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.04),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          GlassButton(
                            isPrimary: true,
                            onPressed: _isLoading ? null : _handleAuth,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(_isSignUp ? 'Sign Up' : 'Sign In'),
                          ),
                          const SizedBox(height: 14),

                          // Divider
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.white.withOpacity(0.12))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('OR', style: AppTypography.bodySmall),
                              ),
                              Expanded(child: Divider(color: Colors.white.withOpacity(0.12))),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Instant Guest Login Button
                          GlassButton(
                            icon: const Icon(Icons.flash_on, size: 20, color: AppColors.accentCyan),
                            onPressed: _handleGuestLogin,
                            child: const Text('Instant Scholar Access'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Toggle sign in / sign up
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isSignUp = !_isSignUp;
                          _errorMessage = null;
                        });
                      },
                      child: Text(
                        _isSignUp
                            ? 'Already have an account? Sign in'
                            : "Don't have an account? Sign up free",
                        style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
