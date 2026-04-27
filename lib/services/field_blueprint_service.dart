import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

const String _defaultFieldLocation = 'Kurnool, Andhra Pradesh';
const String _apName = 'Andhra Pradesh';
const Duration _fieldBlueprintRefreshInterval = Duration(minutes: 10);

class FieldBlueprintException implements Exception {
  final String message;

  const FieldBlueprintException(this.message);

  @override
  String toString() => message;
}

class FieldBlueprintData {
  final String location;
  final String dataSource;
  final DateTime updatedAt;
  final double latitude;
  final double longitude;
  final double temperatureC;
  final int humidity;
  final double windSpeedKmh;
  final double nextSevenDayRainMm;
  final double maxTempC;
  final double minTempC;
  final int groundwaterStressScore;
  final String groundwaterRisk;
  final String rechargeOutlook;
  final List<String> blueprintActions;

  const FieldBlueprintData({
    required this.location,
    required this.dataSource,
    required this.updatedAt,
    required this.latitude,
    required this.longitude,
    required this.temperatureC,
    required this.humidity,
    required this.windSpeedKmh,
    required this.nextSevenDayRainMm,
    required this.maxTempC,
    required this.minTempC,
    required this.groundwaterStressScore,
    required this.groundwaterRisk,
    required this.rechargeOutlook,
    required this.blueprintActions,
  });
}

final fieldLocationProvider =
    StateProvider<String>((ref) => _defaultFieldLocation);

final fieldBlueprintProvider =
    StreamProvider.autoDispose<FieldBlueprintData>((ref) async* {
  final location = ref.watch(fieldLocationProvider);
  while (true) {
    yield await FieldBlueprintService.instance
        .fetchBlueprint(location: location);
    await Future.delayed(_fieldBlueprintRefreshInterval);
  }
});

class _WeatherSnapshot {
  final String source;
  final double currentTemp;
  final int humidity;
  final double windSpeed;
  final double rainTotal;
  final double maxTemp;
  final double minTemp;

  const _WeatherSnapshot({
    required this.source,
    required this.currentTemp,
    required this.humidity,
    required this.windSpeed,
    required this.rainTotal,
    required this.maxTemp,
    required this.minTemp,
  });
}

class FieldBlueprintService {
  FieldBlueprintService._();

  static final FieldBlueprintService instance = FieldBlueprintService._();

  Future<FieldBlueprintData> fetchBlueprint({required String location}) async {
    final query =
        location.trim().isEmpty ? _defaultFieldLocation : location.trim();
    final place = await _resolveAndhraLocation(query);
    final latitude = (place['latitude'] as num).toDouble();
    final longitude = (place['longitude'] as num).toDouble();
    final displayLocation = _formatLocation(place);

    final snapshot = await _fetchLiveSnapshot(
      latitude: latitude,
      longitude: longitude,
    );

    final stressScore = _computeStressScore(
      currentTemp: snapshot.currentTemp,
      humidity: snapshot.humidity,
      windSpeed: snapshot.windSpeed,
      rainTotal: snapshot.rainTotal,
      maxTemp: snapshot.maxTemp,
    );

    return FieldBlueprintData(
      location: displayLocation,
      dataSource: snapshot.source,
      updatedAt: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      temperatureC: snapshot.currentTemp,
      humidity: snapshot.humidity,
      windSpeedKmh: snapshot.windSpeed,
      nextSevenDayRainMm: snapshot.rainTotal,
      maxTempC: snapshot.maxTemp,
      minTempC: snapshot.minTemp,
      groundwaterStressScore: stressScore,
      groundwaterRisk: _riskLabel(stressScore),
      rechargeOutlook: _rechargeOutlook(snapshot.rainTotal),
      blueprintActions: _blueprintActions(
        stressScore: stressScore,
        rainTotal: snapshot.rainTotal,
        maxTemp: snapshot.maxTemp,
      ),
    );
  }

  Future<_WeatherSnapshot> _fetchLiveSnapshot({
    required double latitude,
    required double longitude,
  }) async {
    try {
      return await _fetchNasaPowerSnapshot(
        latitude: latitude,
        longitude: longitude,
      );
    } catch (_) {
      return _fetchOpenMeteoSnapshot(
        latitude: latitude,
        longitude: longitude,
      );
    }
  }

  Future<_WeatherSnapshot> _fetchNasaPowerSnapshot({
    required double latitude,
    required double longitude,
  }) async {
    final today = DateTime.now().toUtc();
    final end = today.subtract(const Duration(days: 1));
    final start = end.subtract(const Duration(days: 6));

    final startDate = _dateKey(start);
    final endDate = _dateKey(end);
    final uri = Uri.parse(
      'https://power.larc.nasa.gov/api/temporal/daily/point?parameters=T2M,T2M_MAX,T2M_MIN,RH2M,WS2M,PRECTOTCORR&community=AG&longitude=$longitude&latitude=$latitude&start=$startDate&end=$endDate&format=JSON',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw const FieldBlueprintException('NASA POWER endpoint unavailable');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final properties = json['properties'] as Map<String, dynamic>?;
    final parameter = properties?['parameter'] as Map<String, dynamic>?;
    if (parameter == null || parameter.isEmpty) {
      throw const FieldBlueprintException('NASA POWER data unavailable');
    }

    final t2m = _seriesValues(parameter['T2M']);
    final t2mMax = _seriesValues(parameter['T2M_MAX']);
    final t2mMin = _seriesValues(parameter['T2M_MIN']);
    final rh2m = _seriesValues(parameter['RH2M']);
    final ws2m = _seriesValues(parameter['WS2M']);
    final rain = _seriesValues(parameter['PRECTOTCORR']);

    if (t2m.isEmpty || rh2m.isEmpty || rain.isEmpty) {
      throw const FieldBlueprintException('NASA POWER timeseries incomplete');
    }

    final currentTemp = t2m.last;
    final humidity = rh2m.last.round();
    final windSpeed = ws2m.isEmpty ? 8.0 : ws2m.last * 3.6;
    final rainTotal = rain.fold<double>(0, (sum, value) => sum + value);
    final maxTemp = t2mMax.isEmpty
        ? t2m.reduce((a, b) => a > b ? a : b)
        : t2mMax.reduce((a, b) => a > b ? a : b);
    final minTemp = t2mMin.isEmpty
        ? t2m.reduce((a, b) => a < b ? a : b)
        : t2mMin.reduce((a, b) => a < b ? a : b);

    return _WeatherSnapshot(
      source: 'NASA POWER (Government) - last 7 days',
      currentTemp: currentTemp,
      humidity: humidity,
      windSpeed: windSpeed,
      rainTotal: rainTotal,
      maxTemp: maxTemp,
      minTemp: minTemp,
    );
  }

  Future<_WeatherSnapshot> _fetchOpenMeteoSnapshot({
    required double latitude,
    required double longitude,
  }) async {
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current=temperature_2m,relative_humidity_2m,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min,precipitation_sum&timezone=auto&forecast_days=7',
    );
    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw const FieldBlueprintException(
        'Live field blueprint is unavailable right now. Please try again.',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>;

    final precipitation = (daily['precipitation_sum'] as List).cast<num>();
    final maxTemps = (daily['temperature_2m_max'] as List).cast<num>();
    final minTemps = (daily['temperature_2m_min'] as List).cast<num>();

    final rainTotal =
        precipitation.fold<double>(0, (sum, value) => sum + value.toDouble());
    final maxTemp = maxTemps.fold<double>(
      0,
      (sum, value) => value.toDouble() > sum ? value.toDouble() : sum,
    );
    final minTemp = minTemps.isEmpty ? 0.0 : minTemps.first.toDouble();
    final currentTemp = (current['temperature_2m'] as num).toDouble();
    final humidity = (current['relative_humidity_2m'] as num).round();
    final windSpeed = (current['wind_speed_10m'] as num).toDouble();

    return _WeatherSnapshot(
      source: 'Open-Meteo fallback',
      currentTemp: currentTemp,
      humidity: humidity,
      windSpeed: windSpeed,
      rainTotal: rainTotal,
      maxTemp: maxTemp,
      minTemp: minTemp,
    );
  }

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  List<double> _seriesValues(dynamic rawSeries) {
    final map = rawSeries as Map<String, dynamic>?;
    if (map == null || map.isEmpty) return const [];
    final values = <double>[];

    for (final entry in map.entries) {
      final value = entry.value;
      if (value is num) {
        final asDouble = value.toDouble();
        if (asDouble > -900) {
          values.add(asDouble);
        }
      }
    }
    return values;
  }

  Future<Map<String, dynamic>> _resolveAndhraLocation(String query) async {
    final terms = _buildSearchTerms(query);
    for (final term in terms) {
      final url = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeQueryComponent(term)}&count=10&language=en&format=json',
      );
      final response = await http.get(url);
      if (response.statusCode != 200) continue;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (json['results'] as List?)
          ?.whereType<Map<String, dynamic>>()
          .where(_isAndhraResult)
          .toList();

      if (results != null && results.isNotEmpty) {
        return results.first;
      }
    }

    throw const FieldBlueprintException(
      'Enter a city or place from Andhra Pradesh to see the field blueprint.',
    );
  }

  List<String> _buildSearchTerms(String query) {
    final base = query.trim();
    final parts = base
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    final values = <String>[
      base,
      if (parts.isNotEmpty) parts.first,
      if (parts.isNotEmpty) '${parts.first}, $_apName',
    ];

    final seen = <String>{};
    return values.where((value) => seen.add(value.toLowerCase())).toList();
  }

  bool _isAndhraResult(Map<String, dynamic> result) {
    final admin1 = (result['admin1'] as String?)?.toLowerCase() ?? '';
    final country = (result['country'] as String?)?.toLowerCase() ?? '';
    return admin1.contains(_apName.toLowerCase()) && country.contains('india');
  }

  String _formatLocation(Map<String, dynamic> place) {
    final name = (place['name'] as String?)?.trim() ?? _defaultFieldLocation;
    final admin1 = (place['admin1'] as String?)?.trim();
    final country = (place['country'] as String?)?.trim();
    return [
      name,
      if (admin1 != null && admin1.isNotEmpty && admin1 != name) admin1,
      if (country != null && country.isNotEmpty) country,
    ].join(', ');
  }

  int _computeStressScore({
    required double currentTemp,
    required int humidity,
    required double windSpeed,
    required double rainTotal,
    required double maxTemp,
  }) {
    var score = 50;
    if (rainTotal < 10) score += 25;
    if (rainTotal < 25) score += 10;
    if (maxTemp > 36) score += 15;
    if (currentTemp > 34) score += 10;
    if (humidity < 45) score += 10;
    if (windSpeed > 18) score += 8;
    if (rainTotal > 40) score -= 18;
    if (rainTotal > 70) score -= 12;
    return score.clamp(0, 100).toInt();
  }

  String _riskLabel(int score) {
    if (score >= 75) return 'High Stress';
    if (score >= 50) return 'Moderate Stress';
    return 'Lower Stress';
  }

  String _rechargeOutlook(double rainTotal) {
    if (rainTotal >= 70) return 'Strong recharge chance this week';
    if (rainTotal >= 30) return 'Partial recharge chance this week';
    return 'Weak recharge chance this week';
  }

  List<String> _blueprintActions({
    required int stressScore,
    required double rainTotal,
    required double maxTemp,
  }) {
    final actions = <String>[];

    if (stressScore >= 75) {
      actions.add(
          'Prioritize drip or alternate-furrow irrigation for water saving.');
      actions
          .add('Mulch exposed soil to cut evaporation during hot afternoons.');
      actions.add(
          'Delay non-essential water-intensive sowing until rainfall improves.');
    } else if (stressScore >= 50) {
      actions.add(
          'Use shorter irrigation cycles and monitor field moisture every 2-3 days.');
      actions.add(
          'Repair field channels and bunds before the next rainfall event.');
    } else {
      actions.add(
          'Current conditions are relatively safer, but continue moisture monitoring.');
      actions.add(
          'Capture runoff in farm ponds or recharge pits when rain arrives.');
    }

    if (rainTotal < 20) {
      actions.add(
          'Plan borewell usage carefully because recharge outlook is weak this week.');
    } else {
      actions.add(
          'Prepare recharge trenches or storage pits to hold the upcoming rainwater.');
    }

    if (maxTemp > 36) {
      actions.add(
          'Prefer early-morning irrigation to reduce heat-loss and crop stress.');
    }

    return actions;
  }
}
