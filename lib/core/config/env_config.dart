import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Safe public client configuration reader that never throws [NotInitializedError].
/// Contains ONLY public client config (Supabase URL/anon key, Google Drive client ID,
/// and MEGA Bridge URL). Private AI provider keys must stay exclusively on the backend.
class EnvConfig {
  EnvConfig._();

  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _googleDriveClientId = String.fromEnvironment('GOOGLE_DRIVE_CLIENT_ID');
  static const _megaBridgeUrl = String.fromEnvironment('MEGA_BRIDGE_URL');

  static String get(String key) {
    try {
      if (dotenv.isInitialized) {
        final val = dotenv.maybeGet(key) ?? dotenv.env[key];
        if (val != null && val.isNotEmpty) return val;
      }
    } catch (_) {
      // Gracefully fall back to compile-time definitions if dotenv is not loaded
    }
    switch (key) {
      case 'SUPABASE_URL':
        return _supabaseUrl;
      case 'SUPABASE_ANON_KEY':
        return _supabaseAnonKey;
      case 'GOOGLE_DRIVE_CLIENT_ID':
        return _googleDriveClientId;
      case 'MEGA_BRIDGE_URL':
        return _megaBridgeUrl;
      default:
        return '';
    }
  }
}
