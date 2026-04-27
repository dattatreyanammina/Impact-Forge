import 'package:hive_flutter/hive_flutter.dart';

class StorageService {
  static const String _settingsBox = 'settings';
  static const String _cacheBox = 'cache';

  static Future<void> saveAdvice(String key, String advice) async {
    final box = Hive.box(_cacheBox);
    await box.put(key, advice);
  }

  static String? getCachedAdvice(String key) {
    final box = Hive.box(_cacheBox);
    return box.get(key) as String?;
  }

  static Future<void> saveUserPreference(String key, dynamic value) async {
    final box = Hive.box(_settingsBox);
    await box.put(key, value);
  }

  static dynamic getUserPreference(String key) {
    final box = Hive.box(_settingsBox);
    return box.get(key);
  }
}
