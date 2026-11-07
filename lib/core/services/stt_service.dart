import 'package:speech_to_text/speech_to_text.dart' as stt;

class SttService {
  final stt.SpeechToText _speech;
  bool _isAvailable = false;
  bool _isListening = false;

  SttService({stt.SpeechToText? speech}) : _speech = speech ?? stt.SpeechToText();

  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;

  /// Initializes the on-device speech recognizer.
  Future<bool> initialize() async {
    if (_isAvailable) return true;

    _isAvailable = await _speech.initialize(
      onError: (val) => _isListening = false,
      onStatus: (val) {
        if (val == 'done' || val == 'notListening') {
          _isListening = false;
        }
      },
    );
    return _isAvailable;
  }

  /// Starts listening to microphone speech on device.
  Future<void> startListening({
    required Function(String recognizedText) onResult,
  }) async {
    final available = await initialize();
    if (!available) {
      throw StateError('Speech recognition is not available on this device');
    }

    _isListening = true;
    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords);
      },
      listenFor: const Duration(seconds: 40),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
      cancelOnError: true,
      partialResults: true,
    );
  }

  /// Stops listening to speech.
  Future<void> stopListening() async {
    await _speech.stop();
    _isListening = false;
  }
}
