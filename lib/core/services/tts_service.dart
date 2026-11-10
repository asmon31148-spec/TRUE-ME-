import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts;
  bool _isSpeaking = false;

  TtsService({FlutterTts? tts}) : _flutterTts = tts ?? FlutterTts() {
    _initTts();
  }

  bool get isSpeaking => _isSpeaking;

  void _initTts() {
    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
    });

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
    });

    // Default configuration for natural academic tutoring
    _flutterTts.setLanguage('en-US');
    _flutterTts.setSpeechRate(0.5); // Natural conversational speed
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.05); // Friendly, clear pitch
    _flutterTts.awaitSpeakCompletion(true);
  }

  /// Speaks the provided text using device native engine (zero API cost).
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await stop();
    await _flutterTts.speak(text);
  }

  /// Stops any currently active speech immediately.
  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
  }

  /// Sets speech rate (0.5 is normal conversational rate).
  Future<void> setSpeechRate(double rate) async {
    await _flutterTts.setSpeechRate((0.5 * rate).clamp(0.25, 1.0));
  }

  void dispose() {
    _flutterTts.stop();
  }
}
