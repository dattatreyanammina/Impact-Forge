import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

class CacheAwareHttpClient {
  static const String _cacheBox = 'cache';
  static const Duration _defaultTtl = Duration(minutes: 10);
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    if (!Hive.isBoxOpen(_cacheBox)) {
      await Hive.openBox(_cacheBox);
    }

    _initialized = true;
  }

  Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 15),
    Duration ttl = _defaultTtl,
  }) async {
    await initialize();
    final cacheKey = _cacheKeyFor(url);

    try {
      final response = await http.get(url, headers: headers).timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _saveCachedResponse(cacheKey, response);
      }

      return response;
    } catch (error) {
      final cached = _loadCachedResponse(cacheKey, ttl);
      if (cached != null) {
        return cached;
      }

      debugPrint('CacheAwareHttpClient GET failed: $error');
      rethrow;
    }
  }

  String _cacheKeyFor(Uri url) {
    final normalized = url.toString().replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
    return 'http_get_$normalized';
  }

  Future<void> _saveCachedResponse(String cacheKey, http.Response response) async {
    try {
      final box = Hive.box(_cacheBox);
      await box.put(
        cacheKey,
        jsonEncode({
          'body': response.body,
          'statusCode': response.statusCode,
          'headers': response.headers,
          'cachedAt': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } catch (error) {
      debugPrint('CacheAwareHttpClient cache save failed: $error');
    }
  }

  http.Response? _loadCachedResponse(String cacheKey, Duration ttl) {
    try {
      final box = Hive.box(_cacheBox);
      final raw = box.get(cacheKey);
      if (raw == null) return null;

      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final cachedAtMs = data['cachedAt'] as int?;
      if (cachedAtMs == null) return null;

      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(cachedAtMs),
      );
      if (age > ttl) return null;

      final body = data['body'] as String? ?? '';
      final statusCode = data['statusCode'] as int? ?? 200;
      final headersMap = (data['headers'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          const <String, String>{};

      return http.Response(body, statusCode, headers: headersMap);
    } catch (_) {
      return null;
    }
  }
}
