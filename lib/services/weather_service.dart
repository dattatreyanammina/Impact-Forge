import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

const String _defaultLocation = 'Kurnool, Andhra Pradesh';
const String _andhraPradeshName = 'Andhra Pradesh';

class WeatherLookupException implements Exception {
  final String message;

  const WeatherLookupException(this.message);

  @override
  String toString() => message;
}

class WeatherData {
  final String location;
  final double tempC;
  final String condition;
  final String conditionTelugu;
  final String icon;
  final int humidity;
  final double windSpeed;
  final List<ForecastDay> forecast;
  final bool isFromCache;

  const WeatherData({
    required this.location,
    required this.tempC,
    required this.condition,
    required this.conditionTelugu,
    required this.icon,
    required this.humidity,
    required this.windSpeed,
    required this.forecast,
    this.isFromCache = false,
  });

  factory WeatherData.demo([String location = _defaultLocation]) => WeatherData(
        location: location,
        tempC: 32,
        condition: 'Partly Cloudy',
        conditionTelugu: 'Partly Cloudy',
        icon: '02d',
        humidity: 65,
        windSpeed: 12.4,
        forecast: ForecastDay.demoList(),
        isFromCache: true,
      );

  factory WeatherData.fromCacheJson(Map<String, dynamic> json) => WeatherData(
        location: (json['location'] as String?) ?? _defaultLocation,
        tempC: (json['tempC'] as num).toDouble(),
        condition: json['condition'] as String,
        conditionTelugu: json['conditionTelugu'] as String,
        icon: json['icon'] as String,
        humidity: json['humidity'] as int,
        windSpeed: (json['windSpeed'] as num).toDouble(),
        forecast: (json['forecast'] as List)
            .map((f) => ForecastDay.fromCacheJson(f as Map<String, dynamic>))
            .toList(),
        isFromCache: true,
      );

  Map<String, dynamic> toJson() => {
        'location': location,
        'tempC': tempC,
        'condition': condition,
        'conditionTelugu': conditionTelugu,
        'icon': icon,
        'humidity': humidity,
        'windSpeed': windSpeed,
        'forecast': forecast.map((f) => f.toJson()).toList(),
      };
}

class ForecastDay {
  final String day;
  final double tempC;
  final String icon;
  final String condition;

  const ForecastDay({
    required this.day,
    required this.tempC,
    required this.icon,
    required this.condition,
  });

  static List<ForecastDay> demoList() => [
        const ForecastDay(day: 'Mon', tempC: 32, icon: '02d', condition: 'Cloudy'),
        const ForecastDay(day: 'Tue', tempC: 30, icon: '10d', condition: 'Rain'),
        const ForecastDay(day: 'Wed', tempC: 28, icon: '10d', condition: 'Rain'),
        const ForecastDay(day: 'Thu', tempC: 31, icon: '01d', condition: 'Sunny'),
        const ForecastDay(day: 'Fri', tempC: 33, icon: '01d', condition: 'Sunny'),
      ];

  Map<String, dynamic> toJson() =>
      {'day': day, 'tempC': tempC, 'icon': icon, 'condition': condition};

  factory ForecastDay.fromCacheJson(Map<String, dynamic> json) => ForecastDay(
        day: json['day'] as String,
        tempC: (json['tempC'] as num).toDouble(),
        icon: json['icon'] as String,
        condition: json['condition'] as String,
      );
}

final weatherLocationProvider = StateProvider<String>((ref) {
  return WeatherService.instance.getSavedLocation();
});

final weatherProvider = FutureProvider<WeatherData>((ref) async {
  final location = ref.watch(weatherLocationProvider);
  return WeatherService.instance.fetchWeather(location: location);
});

class WeatherService {
  WeatherService._();

  static final WeatherService instance = WeatherService._();

  static const _settingsBox = 'settings';
  static const _preferredLocationKey = 'preferred_weather_location';
  static const _cacheBox = 'cache';

  String getSavedLocation() {
    try {
      final box = Hive.box(_settingsBox);
      final saved = box.get(_preferredLocationKey) as String?;
      if (saved != null && saved.trim().isNotEmpty) {
        return saved.trim();
      }
    } catch (_) {}
    return _defaultLocation;
  }

  Future<void> savePreferredLocation(String location) async {
    final trimmed = location.trim();
    if (trimmed.isEmpty) return;
    try {
      final box = Hive.box(_settingsBox);
      await box.put(_preferredLocationKey, trimmed);
    } catch (_) {}
  }

  Future<WeatherData> fetchWeather({required String location}) async {
    final query = location.trim().isEmpty ? _defaultLocation : location.trim();

    try {
      final place = await _resolveLocation(query);
      final latitude = (place['latitude'] as num).toDouble();
      final longitude = (place['longitude'] as num).toDouble();
      final displayLocation = _formatLocation(place);

      final forecastUrl = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m&daily=weather_code,temperature_2m_max&timezone=auto&forecast_days=5',
      );
      final forecastResponse = await http.get(forecastUrl);
      if (forecastResponse.statusCode != 200) {
        throw Exception('Forecast request failed');
      }

      final weatherJson =
          jsonDecode(forecastResponse.body) as Map<String, dynamic>;
      final current = weatherJson['current'] as Map<String, dynamic>;
      final daily = weatherJson['daily'] as Map<String, dynamic>;

      final codes = (daily['weather_code'] as List).cast<num>();
      final temps = (daily['temperature_2m_max'] as List).cast<num>();

      final forecast = List.generate(codes.length, (index) {
        final condition = _weatherCodeToCondition(codes[index].toInt());
        return ForecastDay(
          day: _dayLabel(index),
          tempC: temps[index].toDouble(),
          icon: _weatherCodeToIcon(codes[index].toInt()),
          condition: condition,
        );
      });

      final currentCode = (current['weather_code'] as num).toInt();
      final data = WeatherData(
        location: displayLocation,
        tempC: (current['temperature_2m'] as num).toDouble(),
        condition: _weatherCodeToCondition(currentCode),
        conditionTelugu: _weatherCodeToCondition(currentCode),
        icon: _weatherCodeToIcon(currentCode),
        humidity: (current['relative_humidity_2m'] as num).round(),
        windSpeed: (current['wind_speed_10m'] as num).toDouble(),
        forecast: forecast,
      );

      await savePreferredLocation(displayLocation);
      await _saveToCache(query, data);
      if (displayLocation.toLowerCase() != query.toLowerCase()) {
        await _saveToCache(displayLocation, data);
      }
      return data;
    } catch (error) {
      final cached = await _tryLoadFromCache(query);
      if (cached != null) {
        return cached;
      }
      if (error is WeatherLookupException) rethrow;
      throw const WeatherLookupException(
        'Live weather is unavailable right now. Please try again.',
      );
    }
  }

  Future<WeatherData?> _tryLoadFromCache(String location) async {
    try {
      final box = Hive.box(_cacheBox);
      final raw = box.get(_cacheKeyFor(location));
      if (raw != null) {
        return WeatherData.fromCacheJson(
          jsonDecode(raw as String) as Map<String, dynamic>,
        );
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveToCache(String location, WeatherData data) async {
    try {
      final box = Hive.box(_cacheBox);
      await box.put(_cacheKeyFor(location), jsonEncode(data.toJson()));
    } catch (_) {}
  }

  String _cacheKeyFor(String location) {
    final normalized = location
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return 'weather_data_live_ap_v2_$normalized';
  }

  String _formatLocation(Map<String, dynamic> place) {
    final name = (place['name'] as String?)?.trim() ?? _defaultLocation;
    final admin1 = (place['admin1'] as String?)?.trim();
    final country = (place['country'] as String?)?.trim();
    final parts = [
      name,
      if (admin1 != null && admin1.isNotEmpty && admin1 != name) admin1,
      if (country != null && country.isNotEmpty) country,
    ];
    return parts.join(', ');
  }

  Future<Map<String, dynamic>> _resolveLocation(String query) async {
    final searchTerms = _buildSearchTerms(query);
    final requestedParts = query
        .split(',')
        .map((part) => part.trim().toLowerCase())
        .where((part) => part.isNotEmpty)
        .toList();

    for (final term in searchTerms) {
      final geoUrl = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeQueryComponent(term)}&count=10&language=en&format=json',
      );
      final geoResponse = await http.get(geoUrl);
      if (geoResponse.statusCode != 200) {
        continue;
      }

      final geoJson = jsonDecode(geoResponse.body) as Map<String, dynamic>;
      final results = (geoJson['results'] as List?)
          ?.whereType<Map<String, dynamic>>()
          .toList();

      if (results == null || results.isEmpty) {
        continue;
      }

      final matched = _bestLocationMatch(results, requestedParts);
      if (matched != null) {
        return matched;
      }
    }

    throw const WeatherLookupException(
      'Enter a city from Andhra Pradesh to get live weather.',
    );
  }

  List<String> _buildSearchTerms(String query) {
    final parts = query
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    final terms = <String>[query.trim()];
    if (parts.isNotEmpty) {
      terms.add(parts.first);
      terms.add('${parts.first}, $_andhraPradeshName');
    }
    if (parts.length >= 2) {
      terms.add(parts.last);
      terms.add(parts.take(2).join(' '));
    }

    final seen = <String>{};
    return terms.where((term) => seen.add(term.toLowerCase())).toList();
  }

  Map<String, dynamic>? _bestLocationMatch(
    List<Map<String, dynamic>> results,
    List<String> requestedParts,
  ) {
    final andhraResults = results.where(_isAndhraPradeshResult).toList();
    if (andhraResults.isEmpty) return null;
    if (requestedParts.isEmpty) return andhraResults.first;

    for (final result in andhraResults) {
      final haystack = [
        result['name'],
        result['admin1'],
        result['admin2'],
        result['country'],
      ].whereType<String>().join(' ').toLowerCase();

      final allPartsMatch =
          requestedParts.every((part) => haystack.contains(part));
      if (allPartsMatch) {
        return result;
      }
    }

    return andhraResults.first;
  }

  bool _isAndhraPradeshResult(Map<String, dynamic> result) {
    final admin1 = (result['admin1'] as String?)?.toLowerCase() ?? '';
    final country = (result['country'] as String?)?.toLowerCase() ?? '';
    return admin1.contains(_andhraPradeshName.toLowerCase()) &&
        country.contains('india');
  }

  String _weatherCodeToCondition(int code) {
    if (code == 0) return 'Clear';
    if (code == 1 || code == 2) return 'Partly Cloudy';
    if (code == 3) return 'Cloudy';
    if (code == 45 || code == 48) return 'Fog';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) {
      return 'Rain';
    }
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
      return 'Snow';
    }
    if (code >= 95 && code <= 99) return 'Thunderstorm';
    return 'Weather';
  }

  String _weatherCodeToIcon(int code) {
    if (code == 0) return '01d';
    if (code == 1 || code == 2) return '02d';
    if (code == 3) return '03d';
    if (code == 45 || code == 48) return '50d';
    if (code >= 51 && code <= 57) return '09d';
    if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) {
      return '10d';
    }
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
      return '13d';
    }
    if (code >= 95 && code <= 99) return '11d';
    return '02d';
  }

  String _dayLabel(int index) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    return days[(now.weekday - 1 + index) % 7];
  }
}
