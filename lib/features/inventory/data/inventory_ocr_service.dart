import '../domain/inventory_ocr_detection.dart';

enum InventoryImageSource { camera, gallery }

class InventoryRecognitionResult {
  const InventoryRecognitionResult({
    required this.text,
    this.imageDetections = const [],
  });

  final String text;
  final List<InventoryOcrDetection> imageDetections;
}

abstract class InventoryOcrService {
  bool get isSupported;

  Future<InventoryRecognitionResult?> recognize(InventoryImageSource source);
}
