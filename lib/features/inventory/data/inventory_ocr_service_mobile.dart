import 'dart:io';

import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'inventory_ocr_service.dart';

InventoryOcrService createInventoryOcrService() => _MobileOcrService();

class _MobileOcrService implements InventoryOcrService {
  final _picker = ImagePicker();

  @override
  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  @override
  Future<InventoryRecognitionResult?> recognize(
    InventoryImageSource source,
  ) async {
    if (!isSupported) return null;
    final image = await _picker.pickImage(
      source: source == InventoryImageSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 90,
    );
    if (image == null) return null;
    final input = InputImage.fromFilePath(image.path);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.65),
    );
    try {
      final results = await Future.wait([
        recognizer.processImage(input),
        labeler.processImage(input),
      ]);
      final recognizedText = results[0] as RecognizedText;
      final labels = results[1] as List<ImageLabel>;
      return InventoryRecognitionResult(
        text: recognizedText.text,
        imageLabels: labels.map((label) => label.label).toList(),
      );
    } finally {
      await recognizer.close();
      await labeler.close();
    }
  }
}
