import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../core/services/drive_service.dart';
import '../../../core/services/offline_cache_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    if (OfflineCacheService.isDriveConnected()) {
      DriveService.instance.signInSilently();
    }
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    if (OfflineCacheService.isLoggedIn()) {
      OfflineCacheService.syncFromCloud();
      context.go('/today');
    } else if (OfflineCacheService.hasCompletedOnboarding()) {
      context.go('/login');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: Center(
        child: Text(
          'True Me',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}
