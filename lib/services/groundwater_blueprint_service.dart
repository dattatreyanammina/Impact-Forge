import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroundwaterException implements Exception {
  final String message;

  const GroundwaterException(this.message);

  @override
  String toString() => message;
}

class GroundwaterLevel {
  final double depthInMeters;
  final double lastYearDepth;
  final String qualityStatus;
  final double fluorideLevelMgL;
  final double pHLevel;
  final String rechargeStatus;
  final DateTime lastMeasuredDate;

  const GroundwaterLevel({
    required this.depthInMeters,
    required this.lastYearDepth,
    required this.qualityStatus,
    required this.fluorideLevelMgL,
    required this.pHLevel,
    required this.rechargeStatus,
    required this.lastMeasuredDate,
  });
}

class WaterSupplyData {
  final double dailyAvailability; // in liters/hectare
  final String sourceType; // Groundwater, Surface, Mixed
  final double demandSatisfaction; // percentage
  final List<double> nextWeekAvailability; // daily forecast
  final String criticalityStatus;

  const WaterSupplyData({
    required this.dailyAvailability,
    required this.sourceType,
    required this.demandSatisfaction,
    required this.nextWeekAvailability,
    required this.criticalityStatus,
  });
}

class DroughtRiskAnalysis {
  final int severityScore; // 0-100
  final String riskLevel; // Critical, High, Moderate, Low
  final List<String> mitigationStrategies;
  final double estimatedWaterDeficit; // in mm
  final String cropSuggestion;
  final double irrigationFrequency; // days between irrigation

  const DroughtRiskAnalysis({
    required this.severityScore,
    required this.riskLevel,
    required this.mitigationStrategies,
    required this.estimatedWaterDeficit,
    required this.cropSuggestion,
    required this.irrigationFrequency,
  });
}

class GroundwaterBlueprintData {
  final String location;
  final double latitude;
  final double longitude;
  final GroundwaterLevel groundwaterLevel;
  final WaterSupplyData waterSupply;
  final DroughtRiskAnalysis droughtRisk;
  final List<Map<String, dynamic>> premiumInsights;
  final DateTime lastUpdated;

  const GroundwaterBlueprintData({
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.groundwaterLevel,
    required this.waterSupply,
    required this.droughtRisk,
    required this.premiumInsights,
    required this.lastUpdated,
  });
}

// Andhra Pradesh groundwater baseline data (historical averages by region)
final Map<String, Map<String, double>> _apGroundwaterBaseline = {
  'kurnool': {'depth': 18.5, 'fluoride': 1.2, 'pH': 7.8},
  'anantapur': {'depth': 22.0, 'fluoride': 1.8, 'pH': 7.5},
  'kadapa': {'depth': 20.5, 'fluoride': 1.5, 'pH': 7.6},
  'nellore': {'depth': 8.5, 'fluoride': 0.8, 'pH': 7.4},
  'chittoor': {'depth': 15.0, 'fluoride': 1.1, 'pH': 7.7},
  'tirupati': {'depth': 12.0, 'fluoride': 0.9, 'pH': 7.5},
  'ongole': {'depth': 14.0, 'fluoride': 1.3, 'pH': 7.6},
  'prakasam': {'depth': 16.0, 'fluoride': 1.4, 'pH': 7.5},
  'vijayawada': {'depth': 6.5, 'fluoride': 0.7, 'pH': 7.3},
  'guntur': {'depth': 8.0, 'fluoride': 0.8, 'pH': 7.4},
  'tenali': {'depth': 7.0, 'fluoride': 0.75, 'pH': 7.3},
  'visakhapatnam': {'depth': 9.5, 'fluoride': 0.85, 'pH': 7.5},
  'kakinada': {'depth': 7.5, 'fluoride': 0.8, 'pH': 7.4},
  'rajahmundry': {'depth': 8.5, 'fluoride': 0.9, 'pH': 7.4},
  'warangal': {'depth': 11.0, 'fluoride': 1.0, 'pH': 7.5},
  'hanamkonda': {'depth': 10.5, 'fluoride': 0.95, 'pH': 7.5},
  'hyderabad': {'depth': 14.5, 'fluoride': 1.2, 'pH': 7.6},
  'secunderabad': {'depth': 13.5, 'fluoride': 1.15, 'pH': 7.6},
};

final groundwaterBlueprintProvider = FutureProvider.family<GroundwaterBlueprintData, Map<String, dynamic>>((ref, data) async {
  return GroundwaterBlueprintService.instance.fetchGroundwaterBlueprint(
    location: data['location'] as String,
    latitude: data['latitude'] as double,
    longitude: data['longitude'] as double,
    currentRainfall: data['rainfall'] as double,
    temperature: data['temperature'] as double,
  );
});

class GroundwaterBlueprintService {
  GroundwaterBlueprintService._();

  static final GroundwaterBlueprintService instance = GroundwaterBlueprintService._();

  Future<GroundwaterBlueprintData> fetchGroundwaterBlueprint({
    required String location,
    required double latitude,
    required double longitude,
    required double currentRainfall,
    required double temperature,
  }) async {
    try {
      // Get historical data based on region
      final baseline = _getGroundwaterBaseline(location);
      
      // Simulate groundwater depth variation based on rainfall and temperature
      final currentDepth = _calculateCurrentDepth(
        baseline['depth']!,
        currentRainfall,
        temperature,
      );
      
      final lastYearDepth = baseline['depth']! * 1.15; // Simulate degradation trend
      
      // Generate groundwater level data
      final gwLevel = GroundwaterLevel(
        depthInMeters: currentDepth,
        lastYearDepth: lastYearDepth,
        qualityStatus: _assessQualityStatus(baseline['fluoride']!, baseline['pH']!),
        fluorideLevelMgL: baseline['fluoride']!,
        pHLevel: baseline['pH']!,
        rechargeStatus: _assessRechargeStatus(currentRainfall, currentDepth, lastYearDepth),
        lastMeasuredDate: DateTime.now(),
      );
      
      // Generate water supply data
      final waterSupply = _generateWaterSupplyData(
        depth: currentDepth,
        rainfall: currentRainfall,
        location: location,
      );
      
      // Analyze drought risk
      final droughtRisk = _analyzeDroughtRisk(
        depth: currentDepth,
        rainfall: currentRainfall,
        temperature: temperature,
        waterSupply: waterSupply,
      );
      
      // Generate premium insights
      final premiumInsights = _generatePremiumInsights(
        location: location,
        depth: currentDepth,
        lastYearDepth: lastYearDepth,
        rainfall: currentRainfall,
        droughtRisk: droughtRisk,
        waterSupply: waterSupply,
      );
      
      return GroundwaterBlueprintData(
        location: location,
        latitude: latitude,
        longitude: longitude,
        groundwaterLevel: gwLevel,
        waterSupply: waterSupply,
        droughtRisk: droughtRisk,
        premiumInsights: premiumInsights,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      throw GroundwaterException('Failed to fetch groundwater blueprint: ${e.toString()}');
    }
  }

  Map<String, double> _getGroundwaterBaseline(String location) {
    final normalized = location.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').split(' ').first;
    
    // Find closest match in baseline data
    for (final key in _apGroundwaterBaseline.keys) {
      if (normalized.contains(key) || key.contains(normalized)) {
        return {
          'depth': _apGroundwaterBaseline[key]!['depth']!,
          'fluoride': _apGroundwaterBaseline[key]!['fluoride']!,
          'pH': _apGroundwaterBaseline[key]!['pH']!,
        };
      }
    }
    
    // Return average if no match found
    return {
      'depth': 13.5,
      'fluoride': 1.1,
      'pH': 7.5,
    };
  }

  double _calculateCurrentDepth(
    double baselineDepth,
    double currentRainfall,
    double temperature,
  ) {
    // Rainfall reduces depth (positive effect)
    double rainfallEffect = (currentRainfall > 30) ? -2.0 : (currentRainfall > 10) ? -0.5 : 1.0;
    
    // Temperature increases depth (negative effect - more evaporation)
    double temperatureEffect = (temperature > 35) ? 2.5 : (temperature > 30) ? 1.0 : 0.0;
    
    // Random seasonal variation
    double seasonalVariation = (math.Random().nextDouble() - 0.5) * 2.0;
    
    double adjustedDepth = baselineDepth + rainfallEffect + temperatureEffect + seasonalVariation;
    return adjustedDepth.clamp(1.0, 50.0);
  }

  String _assessQualityStatus(double fluoride, double pH) {
    if (fluoride > 1.5 || pH < 6.5 || pH > 8.5) {
      return 'Poor - Treatment needed';
    } else if (fluoride > 1.0 || pH < 7.0 || pH > 8.0) {
      return 'Fair - Monitor closely';
    }
    return 'Good - Safe to use';
  }

  String _assessRechargeStatus(double rainfall, double currentDepth, double lastYearDepth) {
    if (rainfall > 50) {
      return 'Strong recharge ongoing';
    } else if (currentDepth < lastYearDepth) {
      return 'Recovering - Good trend';
    } else if (currentDepth > lastYearDepth * 1.1) {
      return 'Declining - Action needed';
    }
    return 'Stable - Monitor';
  }

  WaterSupplyData _generateWaterSupplyData({
    required double depth,
    required double rainfall,
    required String location,
  }) {
    // Calculate daily availability (liters/hectare)
    double baseAvailability = 10000; // Base capacity
    double depthMultiplier = math.max(0.2, 1.0 - (depth / 50.0)); // Deeper = less available
    double rainfallBoost = rainfall > 20 ? rainfall * 100 : 0;
    
    double dailyAvailability = (baseAvailability * depthMultiplier) + rainfallBoost;
    
    // Determine source type
    String sourceType;
    if (depth < 8) {
      sourceType = 'Shallow Groundwater + Surface';
    } else if (depth < 16) {
      sourceType = 'Mixed Groundwater';
    } else {
      sourceType = 'Deep Groundwater + Borewell';
    }
    
    // Demand satisfaction percentage
    double demandSatisfaction = math.min(100.0, (dailyAvailability / 8000) * 100);
    
    // Next week forecast (7 days)
    List<double> nextWeekAvailability = List.generate(7, (index) {
      double dayAvailability = dailyAvailability * (0.8 + (index * 0.02));
      return dayAvailability.clamp(0, dailyAvailability * 1.2);
    });
    
    // Criticality status
    String criticalityStatus;
    if (demandSatisfaction < 40) {
      criticalityStatus = 'Critical - Emergency measures needed';
    } else if (demandSatisfaction < 60) {
      criticalityStatus = 'High - Optimize usage';
    } else if (demandSatisfaction < 80) {
      criticalityStatus = 'Moderate - Plan ahead';
    } else {
      criticalityStatus = 'Adequate - Normal operations';
    }
    
    return WaterSupplyData(
      dailyAvailability: dailyAvailability,
      sourceType: sourceType,
      demandSatisfaction: demandSatisfaction,
      nextWeekAvailability: nextWeekAvailability,
      criticalityStatus: criticalityStatus,
    );
  }

  DroughtRiskAnalysis _analyzeDroughtRisk({
    required double depth,
    required double rainfall,
    required double temperature,
    required WaterSupplyData waterSupply,
  }) {
    int severityScore = 50;
    
    // Depth factor
    if (depth > 25) {
      severityScore += 30;
    } else if (depth > 18) {
      severityScore += 15;
    } else if (depth > 12) {
      severityScore += 5;
    }
    
    // Rainfall factor
    if (rainfall < 20) {
      severityScore += 25;
    } else if (rainfall < 40) {
      severityScore += 10;
    } else if (rainfall > 70) {
      severityScore -= 20;
    }

    // Temperature factor
    if (temperature > 38) {
      severityScore += 15;
    } else if (temperature > 35) {
      severityScore += 8;
    }

    // Water supply factor
    if (waterSupply.demandSatisfaction < 50) {
      severityScore += 20;
    } else if (waterSupply.demandSatisfaction > 85) {
      severityScore -= 15;
    }
    severityScore = severityScore.clamp(0, 100);
    
    String riskLevel;
    if (severityScore >= 80) {
      riskLevel = 'Critical';
    } else if (severityScore >= 60) {
      riskLevel = 'High';
    } else if (severityScore >= 40) {
      riskLevel = 'Moderate';
    } else {
      riskLevel = 'Low';
    }
    
    // Mitigation strategies
    List<String> strategies = _generateMitigationStrategies(
      riskLevel: riskLevel,
      depth: depth,
      rainfall: rainfall,
      temperature: temperature,
    );
    
    // Estimated water deficit
    double estimatedDeficit = math.max(0, 80 - (waterSupply.demandSatisfaction));
    
    // Crop suggestions
    String cropSuggestion = _suggestDroughtResistantCrops(riskLevel, depth, rainfall);
    
    // Irrigation frequency
    double irrigationFrequency = _calculateIrrigationFrequency(
      riskLevel: riskLevel,
      rainfall: rainfall,
      temperature: temperature,
    );
    
    return DroughtRiskAnalysis(
      severityScore: severityScore,
      riskLevel: riskLevel,
      mitigationStrategies: strategies,
      estimatedWaterDeficit: estimatedDeficit,
      cropSuggestion: cropSuggestion,
      irrigationFrequency: irrigationFrequency,
    );
  }

  List<String> _generateMitigationStrategies({
    required String riskLevel,
    required double depth,
    required double rainfall,
    required double temperature,
  }) {
    List<String> strategies = [
      '🌾 Switch to drip irrigation - saves 40-60% water',
      '💧 Build farm ponds to capture runoff',
      '🔄 Practice crop rotation with drought-resistant varieties',
    ];
    
    if (riskLevel == 'Critical') {
      strategies.addAll([
        '⛔ Restrict non-essential irrigation immediately',
        '🕳️ Deepen existing borewells or drill new ones strategically',
        '🌱 Mulch fields heavily to reduce evaporation',
        '📊 Install soil moisture sensors for precision irrigation',
      ]);
    } else if (riskLevel == 'High') {
      strategies.addAll([
        '⏱️ Shift to early morning irrigation (before 6 AM)',
        '🏞️ Construct check dams and recharge pits',
        '📈 Use deficit irrigation techniques',
      ]);
    } else if (riskLevel == 'Moderate') {
      strategies.addAll([
        '📅 Plan irrigation schedule based on weekly forecasts',
        '🌊 Monitor groundwater levels weekly',
        '♻️ Improve field bund efficiency',
      ]);
    } else {
      strategies.addAll([
        '✅ Continue regular maintenance of irrigation systems',
        '📢 Prepare for monsoon water harvesting',
      ]);
    }
    
    return strategies;
  }

  String _suggestDroughtResistantCrops(String riskLevel, double depth, double rainfall) {
    if (riskLevel == 'Critical' || depth > 25) {
      return 'Pulses (Pigeon pea, Chickpea), Millets, Oil seeds - minimal water needs';
    } else if (riskLevel == 'High' || depth > 18) {
      return 'Groundnuts, Chillies, Turmeric - moderate water needs';
    } else if (rainfall < 40) {
      return 'Jowar, Bajra, Cotton - semi-arid varieties';
    }
    return 'Sugarcane, Rice, Vegetables - with proper irrigation planning';
  }

  double _calculateIrrigationFrequency({
    required String riskLevel,
    required double rainfall,
    required double temperature,
  }) {
    // Base frequency
    double frequency = 5.0; // days
    
    if (riskLevel == 'Critical') {
      frequency = 2.0;
    } else if (riskLevel == 'High') {
      frequency = 3.0;
    } else if (riskLevel == 'Moderate') {
      frequency = 5.0;
    } else {
      frequency = 7.0;
    }
    
    // Adjust for rainfall
    if (rainfall > 60) {
      frequency += 2.0;
    } else if (rainfall < 20) {
      frequency -= 1.0;
    }
    
    // Adjust for temperature
    if (temperature > 38) {
      frequency -= 1.0;
    } else if (temperature < 25) {
      frequency += 1.0;
    }
    
    return frequency.clamp(1.0, 14.0);
  }

  List<Map<String, dynamic>> _generatePremiumInsights({
    required String location,
    required double depth,
    required double lastYearDepth,
    required double rainfall,
    required DroughtRiskAnalysis droughtRisk,
    required WaterSupplyData waterSupply,
  }) {
    List<Map<String, dynamic>> insights = [];
    
    // Groundwater trend
    double depthChange = lastYearDepth - depth;
    insights.add({
      'title': 'Groundwater Trend',
      'value': '${depthChange.toStringAsFixed(1)} m ${depthChange > 0 ? "↓ (declining)" : "↑ (recovering)"}',
      'icon': depthChange > 0 ? '📉' : '📈',
      'color': depthChange > 0 ? 'warning' : 'success',
      'details': 'Compared to last year at this time',
    });
    
    // Water availability status
    insights.add({
      'title': 'Water Availability',
      'value': '${waterSupply.demandSatisfaction.toStringAsFixed(0)}% satisfied',
      'icon': waterSupply.demandSatisfaction > 75 ? '✅' : '⚠️',
      'color': waterSupply.demandSatisfaction > 75 ? 'success' : 'warning',
      'details': waterSupply.criticalityStatus,
    });
    
    // Recharge potential
    String rechargeOutlook = rainfall > 50 ? 'Strong recharge expected' : 
                            rainfall > 30 ? 'Moderate recharge possible' : 
                            'Weak recharge outlook';
    insights.add({
      'title': 'Recharge Potential',
      'value': rechargeOutlook,
      'icon': '💧',
      'color': rainfall > 50 ? 'success' : 'warning',
      'details': 'Next 7-day rainfall potential',
    });
    
    // Cost optimization
    double savingSuggestion = waterSupply.demandSatisfaction > 80 ? 0 :
                             waterSupply.demandSatisfaction > 60 ? 15 :
                             waterSupply.demandSatisfaction > 40 ? 30 : 50;
    insights.add({
      'title': 'Potential Water Savings',
      'value': '${savingSuggestion.toStringAsFixed(0)}%',
      'icon': '💰',
      'color': 'info',
      'details': 'Through optimized irrigation practices',
    });
    
    // Premium recommendation
    String recommendation = '';
    if (droughtRisk.riskLevel == 'Critical') {
      recommendation = '🚨 PREMIUM ALERT: Groundwater level critical. Immediate action required. Consider deep borewell drilling or water tanker service.';
    } else if (droughtRisk.riskLevel == 'High') {
      recommendation = '⚠️ PREMIUM ALERT: High drought risk. Implement drip irrigation and water harvesting urgently.';
    } else if (depth > 18) {
      recommendation = '📌 PREMIUM TIP: Groundwater is moderately deep. Explore shallow tubewell options or farm pond construction for better irrigation resilience.';
    } else {
      recommendation = '✅ PREMIUM TIP: Groundwater conditions are favorable. Focus on efficient water management and soil moisture conservation.';
    }
    
    insights.add({
      'title': 'Premium Recommendation',
      'value': recommendation,
      'icon': '🎯',
      'color': 'primary',
      'details': 'AI-powered drought prevention strategy',
    });
    
    return insights;
  }
}
