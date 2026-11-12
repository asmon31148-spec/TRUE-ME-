import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Safe environment variable reader that never throws [NotInitializedError].
/// Checks runtime `dotenv` (if initialized) and falls back to compile-time
/// `--dart-define-from-file=.env` constants.
class EnvConfig {
  EnvConfig._();

  static const _geminiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _groqKey = String.fromEnvironment('GROQ_API_KEY');
  static const _cohereKey = String.fromEnvironment('COHERE_API_KEY');
  static const _openRouterKey = String.fromEnvironment('OPENROUTER_API_KEY');
  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _cloudflareAccountId = String.fromEnvironment('CLOUDFLARE_ACCOUNT_ID');
  static const _cloudflareApiToken = String.fromEnvironment('CLOUDFLARE_API_TOKEN');

  static String get(String key) {
    if (dotenv.isInitialized) {
      final val = dotenv.env[key];
      if (val != null && val.isNotEmpty) return val;
    }
    switch (key) {
      case 'GEMINI_API_KEY':
        return _geminiKey;
      case 'GROQ_API_KEY':
        return _groqKey;
      case 'COHERE_API_KEY':
        return _cohereKey;
      case 'OPENROUTER_API_KEY':
        return _openRouterKey;
      case 'SUPABASE_URL':
        return _supabaseUrl;
      case 'SUPABASE_ANON_KEY':
        return _supabaseAnonKey;
      case 'CLOUDFLARE_ACCOUNT_ID':
        return _cloudflareAccountId;
      case 'CLOUDFLARE_API_TOKEN':
        return _cloudflareApiToken;
      default:
        return '';
    }
  }
}
