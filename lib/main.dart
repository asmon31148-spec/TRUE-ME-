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

  runApp(
    const ProviderScope(
      child: TrueMeApp(),
    ),
  );
}
