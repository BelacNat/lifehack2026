import 'dart:convert';
import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/inventory_ocr_detection.dart';
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
      imageQuality: 92,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (image == null) return null;
    final input = InputImage.fromFilePath(image.path);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognizedText = await recognizer.processImage(input);
      final foods = await _recognizeFoods(image);
      return InventoryRecognitionResult(
        text: recognizedText.text,
        imageDetections: foods,
      );
    } finally {
      await recognizer.close();
    }
  }

  Future<List<InventoryOcrDetection>> _recognizeFoods(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      final response = await supabase.functions.invoke(
        'recognize-inventory-foods',
        body: {
          'image_base64': base64Encode(bytes),
          'media_type': _mediaType(image.path),
        },
      );
      final data = response.data;
      final rawFoods = data is Map ? data['foods'] : null;
      if (rawFoods is! List) return const [];
      final detections = <InventoryOcrDetection>[];
      for (final rawFood in rawFoods) {
        if (rawFood is String) {
          final name = rawFood.trim().toLowerCase();
          if (name.isNotEmpty) {
            detections.add(InventoryOcrDetection(name: name));
          }
          continue;
        }
        if (rawFood is! Map) continue;
        final rawName = rawFood['name'];
        if (rawName is! String) continue;
        final name = rawName.trim().toLowerCase();
        if (name.isEmpty) continue;
        final rawQuantity = rawFood['quantity'];
        final quantity = rawQuantity is num ? rawQuantity.toDouble() : 1.0;
        detections.add(
          InventoryOcrDetection(
            name: name,
            quantity: quantity.isFinite && quantity > 0 ? quantity : 1,
          ),
        );
      }
      return detections;
    } on FunctionException {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  String _mediaType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
