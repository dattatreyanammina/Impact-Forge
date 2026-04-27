import 'package:flutter/foundation.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final tfliteServiceProvider = Provider((ref) => TFLiteService());

/// Service for handling on-device AI models (ML Kit & TFLite)
/// Used for offline detection of crop diseases and soil types.
class TFLiteService {
  ImageLabeler? _labeler;

  TFLiteService() {
    _initializeLabeler();
  }

  void _initializeLabeler() async {
    // Using ML Kit's generic labeler as a base.
    // In a real production app for the Google Solution Challenge, 
    // we would swap this with a custom TFLite model using LocalModel:
    // final modelPath = 'assets/models/crop_disease_model.tflite';
    _labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.5));
  }

  Future<List<ImageLabel>> detectFromImage(XFile imageFile) async {
    if (kIsWeb) {
      return [];
    }

    if (_labeler == null) _initializeLabeler();

    final inputImage = InputImage.fromFilePath(imageFile.path);
    try {
      final labels = await _labeler!.processImage(inputImage);
      return labels;
    } catch (e) {
      return [];
    }
  }

  void dispose() {
    _labeler?.close();
  }
}
