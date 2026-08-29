import 'inventory_ocr_service.dart';

InventoryOcrService createInventoryOcrService() => _UnsupportedOcrService();

class _UnsupportedOcrService implements InventoryOcrService {
  @override
  bool get isSupported => false;

  @override
  Future<InventoryRecognitionResult?> recognize(
    InventoryImageSource source,
  ) async =>
      null;
}
