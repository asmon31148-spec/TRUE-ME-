import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _textRecognizer;

  OcrService({TextRecognizer? recognizer})
      : _textRecognizer = recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  /// Extracts text from an image file (notes, whiteboard, slides).
  /// Fully on-device, offline, and free without API quota limitations.
  Future<String> recognizeTextFromImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

    final StringBuffer buffer = StringBuffer();
    for (final textBlock in recognizedText.blocks) {
      buffer.writeln(textBlock.text);
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  void dispose() {
    _textRecognizer.close();
  }
}
