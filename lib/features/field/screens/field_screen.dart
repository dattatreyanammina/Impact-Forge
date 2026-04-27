import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/field_blueprint_service.dart';

class FieldScreen extends ConsumerStatefulWidget {
  const FieldScreen({super.key});

  @override
  ConsumerState<FieldScreen> createState() => _FieldScreenState();
}

class _FieldScreenState extends ConsumerState<FieldScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(fieldLocationProvider),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blueprintAsync = ref.watch(fieldBlueprintProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.secondaryDark,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: const Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Field',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'Andhra Pradesh drought blueprint',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF0D47A1),
                      Color(0xFF0277BD),
                      Color(0xFF26A69A)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearch(),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'This blueprint uses live Andhra Pradesh place weather to estimate drought and groundwater stress. It is a field-support estimate, not a measured borewell depth report.',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  blueprintAsync.when(
                    data: _buildBlueprint,
                    loading: () => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => _buildError(error.toString()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Search Andhra Pradesh city or place',
                prefixIcon: Icon(Icons.search_rounded),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _applySearch(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: _applySearch,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.primaryDark,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: const Text(
            'Check',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildBlueprint(FieldBlueprintData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heroCard(data),
        const SizedBox(height: 16),
        _areaFlowCard(data),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                title: '7-day rain',
                value: '${data.nextSevenDayRainMm.toStringAsFixed(1)} mm',
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard(
                title: 'Stress score',
                value: '${data.groundwaterStressScore}/100',
                color: data.groundwaterStressScore >= 75
                    ? AppColors.error
                    : data.groundwaterStressScore >= 50
                        ? AppColors.warning
                        : AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                title: 'Today temp',
                value: '${data.temperatureC.toStringAsFixed(1)}°C',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard(
                title: 'Humidity',
                value: '${data.humidity}%',
                color: AppColors.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _infoCard(
          title: 'Recharge Outlook',
          subtitle: data.rechargeOutlook,
          icon: Icons.water_drop_rounded,
          color: AppColors.secondary,
        ),
        const SizedBox(height: 12),
        _infoCard(
          title: 'Groundwater Risk',
          subtitle: data.groundwaterRisk,
          icon: Icons.insights_rounded,
          color: data.groundwaterStressScore >= 75
              ? AppColors.error
              : data.groundwaterStressScore >= 50
                  ? AppColors.warning
                  : AppColors.success,
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Drought Blueprint',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ...data.blueprintActions.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroCard(FieldBlueprintData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF0EA5A4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.location,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Live Andhra Pradesh field outlook',
            style: TextStyle(
              color: Color(0xCCFFFFFF),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            data.groundwaterRisk,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Max ${data.maxTempC.toStringAsFixed(1)}°C  •  Min ${data.minTempC.toStringAsFixed(1)}°C  •  Wind ${data.windSpeedKmh.toStringAsFixed(1)} km/h',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _areaFlowCard(FieldBlueprintData data) {
    final waterScore = (100 - data.groundwaterStressScore).clamp(0, 100);
    final isGood = waterScore > 50;
    final statusColor = isGood ? AppColors.success : AppColors.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF061525), Color(0xFF0B2034)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF061525).withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Field Water Blueprint',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Live groundwater and drought-support view for ${data.location}',
                      style: const TextStyle(
                        color: Color(0xB3FFFFFF),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  isGood ? 'Stable flow' : 'Low flow',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFF93C5FD),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${data.latitude.toStringAsFixed(4)}, ${data.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const Text(
                  'Hydrology signal',
                  style: TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 920;
              final map = AndhraPradeshBlueprintView(
                latitude: data.latitude,
                longitude: data.longitude,
                location: data.location,
                stressScore: data.groundwaterStressScore,
              );
              final rail = _signalRail(
                data: data,
                waterScore: waterScore,
                isGood: isGood,
              );

              return isWide
                  ? SizedBox(
                      height: 360,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 7,
                            child: map,
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            flex: 3,
                            child: rail,
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        SizedBox(
                          height: 300,
                          width: double.infinity,
                          child: map,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: rail,
                        ),
                      ],
                    );
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'This blueprint is a planning view for drought response and recharge support across the selected Andhra Pradesh place.',
            style: TextStyle(
              color: Color(0x99FFFFFF),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _signalRail({
    required FieldBlueprintData data,
    required num waterScore,
    required bool isGood,
  }) {
    final statusColor = isGood ? AppColors.success : AppColors.warning;
    final waterPercent = waterScore / 100;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Field Signals',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _railTile(
            'Water availability',
            '${waterScore.toInt()}%',
            statusColor,
          ),
          const SizedBox(height: 12),
          _railTile(
            'Stress pressure',
            '${data.groundwaterStressScore}/100',
            _riskColor(data.groundwaterStressScore),
          ),
          const SizedBox(height: 12),
          _railTile(
            '7-day rainfall',
            '${data.nextSevenDayRainMm.toStringAsFixed(1)} mm',
            const Color(0xFF38BDF8),
          ),
          const SizedBox(height: 18),
          const Text(
            'Recharge band',
            style: TextStyle(
              color: Color(0x99FFFFFF),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: waterPercent.toDouble(),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Action cue',
                  style: TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.blueprintActions.first,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _railTile(String label, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xB3FFFFFF),
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _riskColor(int score) {
    if (score >= 75) return AppColors.error;
    if (score >= 50) return AppColors.warning;
    return AppColors.success;
  }

  Widget _metricCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          height: 1.4,
        ),
      ),
    );
  }

  void _applySearch() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    HapticFeedback.selectionClick();
    ref.read(fieldLocationProvider.notifier).state = query;
  }
}

class AndhraPradeshBlueprintView extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String location;
  final int stressScore;

  const AndhraPradeshBlueprintView({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.location,
    required this.stressScore,
  });

  @override
  State<AndhraPradeshBlueprintView> createState() =>
      _AndhraPradeshBlueprintViewState();
}

class _AndhraPradeshBlueprintViewState
    extends State<AndhraPradeshBlueprintView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flowController;
  bool _showFullState = true;

  @override
  void initState() {
    super.initState();
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _flowController.dispose();
    super.dispose();
  }

  Offset _projectPoint(double lat, double lon, Size size) {
    const minLat = 12.0;
    const maxLat = 19.0;
    const minLon = 77.0;
    const maxLon = 84.5;
    final x = ((lon - minLon) / (maxLon - minLon)).clamp(0.0, 1.0);
    final y = (1 - ((lat - minLat) / (maxLat - minLat))).clamp(0.0, 1.0);
    return Offset(
      28 + x * (size.width - 56),
      28 + y * (size.height - 56),
    );
  }

  Color get _stressColor {
    if (widget.stressScore >= 75) return AppColors.error;
    if (widget.stressScore >= 50) return AppColors.warning;
    return AppColors.success;
  }

  void _toggleView() {
    setState(() {
      _showFullState = !_showFullState;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return AnimatedBuilder(
                  animation: _flowController,
                  builder: (context, child) {
                    final selected =
                        _projectPoint(widget.latitude, widget.longitude, size);
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _BlueprintMapPainter(
                              stressColor: _stressColor,
                              animationValue: _flowController.value,
                              selectedPoint: selected,
                              showFullState: _showFullState,
                            ),
                          ),
                        ),
                        Positioned(
                          left: selected.dx - 12,
                          top: selected.dy - 12,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: _stressColor, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: _stressColor.withValues(alpha: 0.45),
                                  blurRadius: 18,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          top: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.42),
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Text(
                              widget.location,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          bottom: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(18),
                              border:
                                  Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _stressColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _showFullState
                                      ? 'Blueprint terrain view'
                                      : 'Focused field cutaway',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: _toggleView,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showFullState ? Icons.grid_4x4_rounded : Icons.layers,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _showFullState ? 'State view' : 'Field view',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlueprintMapPainter extends CustomPainter {
  final Color stressColor;
  final double animationValue;
  final Offset selectedPoint;
  final bool showFullState;

  const _BlueprintMapPainter({
    required this.stressColor,
    required this.animationValue,
    required this.selectedPoint,
    required this.showFullState,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF04111E), Color(0xFF0A2740), Color(0xFF103B57)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    const spacing = 26.0;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF38BDF8).withValues(alpha: 0.16),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.72, size.height * 0.28),
          radius: size.width * 0.4,
        ),
      );
    canvas.drawRect(Offset.zero & size, glowPaint);

    final contourPaint = Paint()
      ..color = const Color(0xFF67E8F9).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (int i = 0; i < 5; i++) {
      final baseY = size.height * (0.22 + i * 0.14);
      final path = Path()
        ..moveTo(0, baseY)
        ..quadraticBezierTo(
          size.width * 0.20,
          baseY - 18,
          size.width * 0.48,
          baseY + 14,
        )
        ..quadraticBezierTo(
          size.width * 0.76,
          baseY + 24,
          size.width,
          baseY - 8,
        );
      canvas.drawPath(path, contourPaint);
    }

    final apPath = Path()
      ..moveTo(size.width * 0.16, size.height * 0.80)
      ..lineTo(size.width * 0.22, size.height * 0.60)
      ..lineTo(size.width * 0.30, size.height * 0.24)
      ..lineTo(size.width * 0.52, size.height * 0.15)
      ..lineTo(size.width * 0.70, size.height * 0.30)
      ..lineTo(size.width * 0.78, size.height * 0.52)
      ..lineTo(size.width * 0.72, size.height * 0.70)
      ..lineTo(size.width * 0.62, size.height * 0.84)
      ..lineTo(size.width * 0.46, size.height * 0.88)
      ..lineTo(size.width * 0.34, size.height * 0.86)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF22C55E).withValues(alpha: showFullState ? 0.16 : 0.10),
          const Color(0xFF38BDF8).withValues(alpha: showFullState ? 0.24 : 0.14),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(apPath, fillPaint);
    canvas.drawPath(apPath, borderPaint);

    final apInnerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (int i = 1; i <= 3; i++) {
      final shift = i * 14.0;
      final inner = Path()
        ..moveTo(size.width * 0.20, size.height * 0.78 - shift * 0.1)
        ..quadraticBezierTo(
          size.width * 0.38,
          size.height * (0.22 + i * 0.03),
          size.width * 0.67,
          size.height * (0.34 + i * 0.05),
        )
        ..quadraticBezierTo(
          size.width * 0.72,
          size.height * 0.56,
          size.width * 0.50,
          size.height * (0.82 - i * 0.02),
        );
      canvas.drawPath(inner, apInnerPaint);
    }

    final flowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF38BDF8).withValues(alpha: 0.10),
          const Color(0xFF22D3EE),
          Colors.white,
        ],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final flowStart = Offset(size.width * 0.20, size.height * 0.76);
    final flowMid = Offset(size.width * 0.44, size.height * 0.56);
    final flowEnd = selectedPoint;
    final flowPath = Path()
      ..moveTo(flowStart.dx, flowStart.dy)
      ..quadraticBezierTo(
        flowMid.dx,
        flowMid.dy,
        flowEnd.dx,
        flowEnd.dy,
      );
    canvas.drawPath(flowPath, flowPaint);

    final flowParticlePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9);
    final t = animationValue;
    final particle = Offset.lerp(
      Offset.lerp(flowStart, flowMid, t)!,
      Offset.lerp(flowMid, flowEnd, t)!,
      t,
    )!;
    canvas.drawCircle(particle, 4, flowParticlePaint);

    final pulse = 8 + 10 * math.sin(animationValue * math.pi * 2).abs();
    final pulsePaint = Paint()
      ..color = stressColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(selectedPoint, 14 + pulse, pulsePaint);

    final terrainShade = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.16),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, terrainShade);
  }

  @override
  bool shouldRepaint(covariant _BlueprintMapPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.selectedPoint != selectedPoint ||
        oldDelegate.showFullState != showFullState ||
        oldDelegate.stressColor != stressColor;
  }
}
