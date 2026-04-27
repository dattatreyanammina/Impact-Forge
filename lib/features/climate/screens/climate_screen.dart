import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/weather_service.dart';
import 'package:easy_localization/easy_localization.dart';

class ClimateScreen extends ConsumerWidget {
  const ClimateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(weatherProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ─── Gradient AppBar ────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFF0277BD),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('climate_advisor'.tr(),
                      style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.normal)),
                  Text('weather_forecast'.tr(),
                      style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF01579B), Color(0xFF0288D1), Color(0xFF29B6F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Stack(
                  children: [
                    Positioned(
                      right: 20,
                      bottom: 10,
                      child: Opacity(
                        opacity: 0.15,
                        child: Text('🌤️', style: TextStyle(fontSize: 90)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Body ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: weatherAsync.when(
              data: (w) => _buildContent(context, w),
              loading: () => const Padding(
                padding: EdgeInsets.all(60),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => _buildErrorState(error.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WeatherData w) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (w.isFromCache) _offlineBanner(),
          _buildCurrentConditions(w),
          const SizedBox(height: 16),
          _buildForecastCard(w),
          const SizedBox(height: 16),
          _buildWaterAlert(w),
          const SizedBox(height: 16),
          _buildSoilMoistureCard(),
          const SizedBox(height: 16),
          _buildCropSeasonCard(),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          message,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  // ─── Offline banner ─────────────────────────────────────────────────
  Widget _offlineBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 15, color: Colors.orange),
          const SizedBox(width: 8),
          Text('offline_cached_short'.tr(),
              style: TextStyle(color: Colors.orange.shade800, fontSize: 12)),
        ],
      ),
    );
  }

  // ─── Current Conditions ──────────────────────────────────────────────
  Widget _buildCurrentConditions(WeatherData w) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(const Color(0xFF0288D1)),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('now'.tr(),
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                w.location,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text('${w.tempC.toStringAsFixed(0)}°C',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      height: 1.1)),
              Text(w.condition,
                  style: const TextStyle(color: Colors.white, fontSize: 15)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _conditionChip(Icons.water_drop_outlined, '${w.humidity}%'),
                  const SizedBox(width: 8),
                  _conditionChip(Icons.air_rounded,
                      '${w.windSpeed.toStringAsFixed(1)} km/h'),
                ],
              ),
            ],
          ),
          const Spacer(),
          Text(_icon(w.icon), style: const TextStyle(fontSize: 80)),
        ],
      ),
    );
  }

  Widget _conditionChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  // ─── Forecast Card ────────────────────────────────────────────────────
  Widget _buildForecastCard(WeatherData w) {
    return _sectionCard(
      title: 'forecast_7day'.tr(),
      subtitle: '${'forecast_7day'.tr()} (${w.location})',
      icon: Icons.calendar_month_rounded,
      child: SizedBox(
        height: 90,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: w.forecast
              .map((day) => _ForecastDayCard(day: day))
              .toList(),
        ),
      ),
    );
  }

  // ─── Water Alert ──────────────────────────────────────────────────────
  Widget _buildWaterAlert(WeatherData w) {
    final isRain = w.condition.toLowerCase().contains('rain') ||
        w.condition.toLowerCase().contains('drizzle');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isRain
              ? [const Color(0xFF0D47A1), const Color(0xFF1976D2)]
              : [const Color(0xFFE65100), const Color(0xFFFF6D00)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
              isRain ? Icons.umbrella_rounded : Icons.wb_sunny_rounded,
              color: Colors.white,
              size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRain ? 'rain_expected'.tr() : 'water_scarcity_alert'.tr(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  isRain
                      ? 'rain_expected_desc'.tr()
                      : 'water_scarcity_desc'.tr(),
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Soil Moisture ────────────────────────────────────────────────────
  Widget _buildSoilMoistureCard() {
    const moisture = 0.45;
    const status = moisture < 0.3
        ? ('Dry – Water Now!', Colors.red)
        : moisture < 0.6
            ? ('Medium – Water in 3 days', Colors.orange)
            : ('Good – No watering needed', Colors.green);

    return _sectionCard(
      title: 'soil_moisture'.tr(),
      subtitle: 'soil_moisture'.tr(),
      icon: Icons.grass_rounded,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(moisture * 100).toInt()}%',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: status.$2)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Kurnool District (Est.)',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                  Text(status.$1,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: status.$2)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: moisture,
              minHeight: 10,
              color: status.$2,
              backgroundColor: Colors.grey.shade200,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Crop Season Recommendation ───────────────────────────────────────
  Widget _buildCropSeasonCard() {
    final recommendations = [
      {'crop': 'Groundnut', 'reason': 'High drought resistance + good MSP', 'emoji': '🥜'},
      {'crop': 'Red Chilli', 'reason': 'Rising demand, suits Kurnool black soil', 'emoji': '🌶️'},
      {'crop': 'Marigold', 'reason': 'Low water, high margin for temple season', 'emoji': '🌼'},
    ];

    return _sectionCard(
      title: 'crop_recommendations'.tr(),
      subtitle: '${'crop_recommendations'.tr()} (Kharif/Rabi)',
      icon: Icons.eco_rounded,
      child: Column(
        children: recommendations
            .map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Text(r['emoji']!,
                          style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r['crop']!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.primaryDark)),
                            Text(r['reason']!,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.primary),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────
  Widget _sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF0288D1), size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.primaryDark)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const Divider(height: 20),
          child,
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration(Color color) => BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(red: (color.r * 255 - 30).clamp(0, 255) / 255)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6))
        ],
      );

  String _icon(String code) {
    if (code.startsWith('01')) return '☀️';
    if (code.startsWith('02') || code.startsWith('03')) return '⛅';
    if (code.startsWith('04')) return '☁️';
    if (code.startsWith('09') || code.startsWith('10')) return '🌧️';
    if (code.startsWith('11')) return '⛈️';
    return '🌫️';
  }
}

// ─── Forecast Day Card ────────────────────────────────────────────────────────
class _ForecastDayCard extends StatelessWidget {
  final ForecastDay day;
  const _ForecastDayCard({required this.day});

  @override
  Widget build(BuildContext context) {
    const iconMap = {
      '01d': '☀️',
      '02d': '⛅',
      '03d': '☁️',
      '04d': '☁️',
      '09d': '🌧️',
      '10d': '🌧️',
      '11d': '⛈️',
    };
    return Container(
      width: 75,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(day.day,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.primaryDark)),
          const SizedBox(height: 4),
          Text(iconMap[day.icon] ?? '⛅', style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text('${day.tempC.toStringAsFixed(0)}°',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF01579B))),
        ],
      ),
    );
  }
}
