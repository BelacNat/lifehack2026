enum InventoryImageSource { camera, gallery }

class InventoryRecognitionResult {
  const InventoryRecognitionResult({
    required this.text,
    this.imageLabels = const [],
  });

  final String text;
  final List<String> imageLabels;
}

abstract class InventoryOcrService {
  bool get isSupported;

  Future<InventoryRecognitionResult?> recognize(InventoryImageSource source);
}
