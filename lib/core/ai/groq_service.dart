import 'dart:io';
import 'ai_gateway_client.dart';

/// Gateway-backed Groq adapter. Private GROQ_API_KEY lives exclusively on the backend.
class GroqService {
  final AiGatewayClient _gateway;

  GroqService({String? apiKey, dynamic dio, AiGatewayClient? gateway})
      : _gateway = gateway ?? AiGatewayClient.instance;

  bool get isConfigured => _gateway.isConfigured;

  /// High-volume fast completion routed via authenticated Supabase AI Gateway.
  Future<String> complete8B({
    required String prompt,
    String? systemPrompt,
    bool jsonMode = false,
    double temperature = 0.3,
    int? maxTokens,
  }) async {
    return _gateway.chat(
      prompt: prompt,
      systemPrompt: systemPrompt,
      tier: 'realtime',
      taskType: 'groq_speed',
      jsonMode: jsonMode,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  /// Complex reasoning and RAG chat routed via authenticated Supabase AI Gateway.
  Future<String> complete70B({
    required String prompt,
    String? systemPrompt,
    bool jsonMode = false,
    double temperature = 0.3,
    int? maxTokens,
  }) async {
    return _gateway.chat(
      prompt: prompt,
      systemPrompt: systemPrompt,
      tier: 'heavy',
      preferredProvider: 'groq',
      taskType: 'groq_heavy',
      jsonMode: jsonMode,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  /// Audio transcription via authenticated Supabase AI Gateway (Whisper Large v3).
  Future<String> transcribeAudio(File audioFile) async {
    return _gateway.transcribe(audioFile: audioFile);
  }
}
