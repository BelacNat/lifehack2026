import 'inventory_ocr_service.dart';
import 'inventory_ocr_service_stub.dart'
    if (dart.library.io) 'inventory_ocr_service_mobile.dart' as implementation;

InventoryOcrService createInventoryOcrService() =>
    implementation.createInventoryOcrService();
