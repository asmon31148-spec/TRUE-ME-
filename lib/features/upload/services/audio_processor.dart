import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../core/ai/groq_service.dart';

class AudioProcessor {
  final AudioRecorder _recorder;
  final GroqService _groqService;
  String? _currentRecordingPath;

  AudioProcessor({AudioRecorder? recorder, GroqService? groqService})
      : _recorder = recorder ?? AudioRecorder(),
        _groqService = groqService ?? GroqService();

  bool get isRecording => _currentRecordingPath != null;

  /// Starts recording a lecture or voice note.
  Future<void> startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw StateError('Microphone permission not granted');
    }

    final tempDir = await getTemporaryDirectory();
    final fileName = 'lecture_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final filePath = '${tempDir.path}/$fileName';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: filePath,
    );

    _currentRecordingPath = filePath;
  }

  /// Stops recording and transcribes the audio using Groq Whisper Large v3.
  Future<String> stopAndTranscribe() async {
    final path = await _recorder.stop();
    _currentRecordingPath = null;

    if (path == null) {
      throw StateError('No recording found');
    }

    final file = File(path);
    if (!await file.exists()) {
      throw StateError('Recorded audio file missing: $path');
    }

    // Transcribe with Groq Whisper Large v3
    return await _groqService.transcribeAudio(file);
  }

  void dispose() {
    _recorder.dispose();
  }
}
