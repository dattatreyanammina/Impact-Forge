import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ImageCacheService {
  ImageCacheService._();

  static const String _cacheBox = 'cache';
  static const String _keyPrefix = 'image_url_';
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    if (!Hive.isBoxOpen(_cacheBox)) {
      await Hive.openBox(_cacheBox);
    }

    _initialized = true;
  }

  static Future<void> cacheImageUrl(String key, String url) async {
    if (key.trim().isEmpty || url.trim().isEmpty) return;
    await initialize();

    try {
      final box = Hive.box(_cacheBox);
      await box.put('$_keyPrefix$key', url);
    } catch (error) {
      debugPrint('ImageCacheService cacheImageUrl failed: $error');
    }
  }

  static String? getCachedImageUrl(String key) {
    if (key.trim().isEmpty) return null;

    try {
      final box = Hive.box(_cacheBox);
      return box.get('$_keyPrefix$key') as String?;
    } catch (_) {
      return null;
    }
  }
}
