import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/services/notification_service.dart';
import 'core/services/offline_cache_service.dart';
import 'core/services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load environment variables (.env)
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('dotenv could not load .env file: $e');
  }

  // 2. Initialize Offline Hive Cache Boxes
  try {
    await OfflineCacheService.initialize();
  } catch (e) {
    debugPrint('OfflineCacheService init failed: $e');
  }

  // 3. Initialize Supabase Client
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('SupabaseService init failed: $e');
  }

  // 4. Initialize Local Notifications Plugin
  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('NotificationService init failed: $e');
  }

  // 5. System UI Overlay Style for Liquid Glass theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF070B14),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // 6. Prevent Grey Screen of Death in Release Mode
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF0B0F19),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF06B6D4), size: 48),
              const SizedBox(height: 16),
              const Text(
                'True Me • Loading View',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  };

  runApp(
    const ProviderScope(
      child: TrueMeApp(),
    ),
  );
}
