import 'package:flutter/material.dart';
import '../../../services/groundwater_blueprint_service.dart';
import '../../../core/theme/app_colors.dart';

class InteractiveGroundwaterMap extends StatefulWidget {
  final GroundwaterBlueprintData data;

  const InteractiveGroundwaterMap({
    super.key,
    required this.data,
  });

  @override
  State<InteractiveGroundwaterMap> createState() =>
      _InteractiveGroundwaterMapState();
}

class _InteractiveGroundwaterMapState extends State<InteractiveGroundwaterMap> {
  late Offset _tapPosition;
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🗺️ Groundwater Depth Cross-Section',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            // Interactive soil cross-section
            GestureDetector(
              onTapDown: (details) {
                setState(() {
                  _tapPosition = details.localPosition;
                  _showDetails = true;
                });
              },
              child: CustomPaint(
                painter: GroundwaterCrossSectionPainter(
                  depth: widget.data.groundwaterLevel.depthInMeters,
                  qualityStatus: widget.data.groundwaterLevel.qualityStatus,
                  tapPosition: _showDetails ? _tapPosition : null,
                ),
                size: const Size(double.infinity, 260),
              ),
            ),
            const SizedBox(height: 14),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem('🌾', 'Soil', const Color(0xFF8B6F47)),
                _buildLegendItem('💧', 'Saturated', const Color(0xFF4DB8FF)),
                _buildLegendItem('⛰️', 'Bedrock', const Color(0xFF696969)),
                _buildLegendItem('🔴', 'GWL', const Color(0xFF0277BD)),
              ],
            ),
            const SizedBox(height: 14),
            // Depth details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE1F5FE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Groundwater Level (GWL): ${widget.data.groundwaterLevel.depthInMeters.toStringAsFixed(2)} meters below surface',
                    style: const TextStyle(
                      color: Color(0xFF01579B),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The blue highlighted area represents the saturated zone. Groundwater extraction happens from this layer.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String emoji, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class GroundwaterCrossSectionPainter extends CustomPainter {
  final double depth;
  final String qualityStatus;
  final Offset? tapPosition;

  GroundwaterCrossSectionPainter({
    required this.depth,
    required this.qualityStatus,
    this.tapPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Draw background sky
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 40),
      Paint()..color = const Color(0xFFE3F2FD),
    );

    // Draw surface line
    canvas.drawLine(
      const Offset(0, 40),
      Offset(size.width, 40),
      Paint()
        ..color = const Color(0xFF8B6F47)
        ..strokeWidth = 2,
    );

    // Draw soil layers (brown)
    canvas.drawRect(
      Rect.fromLTWH(0, 40, size.width, (depth / 50) * 180),
      Paint()..color = const Color(0xFFA0826D).withValues(alpha: 0.4),
    );

    // Draw water-saturated zone (light blue)
    final gwlYPosition = 40 + (depth / 50) * 180;
    canvas.drawRect(
      Rect.fromLTWH(0, gwlYPosition, size.width, 260 - gwlYPosition),
      Paint()..color = const Color(0xFF4DB8FF).withValues(alpha: 0.3),
    );

    // Draw bedrock (dark gray)
    canvas.drawRect(
      Rect.fromLTWH(0, 260 - 20, size.width, 20),
      Paint()..color = const Color(0xFF696969).withValues(alpha: 0.5),
    );

    // Draw GWL marker line
    canvas.drawLine(
      Offset(0, gwlYPosition),
      Offset(size.width, gwlYPosition),
      Paint()
        ..color = const Color(0xFF0277BD)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Draw GWL circles
    const markerRadius = 6.0;
    for (double x = markerRadius; x < size.width; x += 20) {
      canvas.drawCircle(
        Offset(x, gwlYPosition),
        markerRadius,
        Paint()
          ..color = const Color(0xFF0277BD)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Draw depth label at GWL
    textPainter.text = TextSpan(
      text: 'GWL: ${depth.toStringAsFixed(1)}m',
      style: const TextStyle(
        color: Color(0xFF01579B),
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width - 100, gwlYPosition - 20));

    // Draw depth scale on the side
    _drawDepthScale(canvas, size);

    // Draw tap details if tap position exists
    if (tapPosition != null) {
      _drawTapDetails(canvas, size, tapPosition!);
    }
  }

  void _drawDepthScale(Canvas canvas, Size size) {
    const scaleIntervals = 5;
    const maxDepth = 50.0;

    for (int i = 0; i <= scaleIntervals; i++) {
      final depthValue = (maxDepth / scaleIntervals) * i;
      final yPosition = 40 + (depthValue / maxDepth) * 180;

      // Draw tick mark
      canvas.drawLine(
        Offset(-8, yPosition),
        Offset(0, yPosition),
        Paint()
          ..color = Colors.grey.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );

      // Draw depth label
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${depthValue.toStringAsFixed(0)}m',
          style: TextStyle(
            color: Colors.grey.withValues(alpha: 0.6),
            fontSize: 9,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(-40, yPosition - 5));
    }
  }

  void _drawTapDetails(Canvas canvas, Size size, Offset tapPosition) {
    final tapDepth = ((tapPosition.dy - 40) / 180) * 50;
    final actualDepth = depth;

    String status;
    Color statusColor;

    if (tapPosition.dy < 40) {
      status = 'Surface / Sky';
      statusColor = Colors.blue;
    } else if (tapDepth < actualDepth) {
      status = 'Unsaturated Soil Zone';
      statusColor = Colors.orange;
    } else {
      status = 'Groundwater Zone ✅';
      statusColor = Colors.blue;
    }

    // Draw tap circle
    canvas.drawCircle(
      tapPosition,
      8,
      Paint()
        ..color = statusColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    canvas.drawCircle(
      tapPosition,
      8,
      Paint()..color = statusColor.withValues(alpha: 0.2),
    );

    // Draw info bubble
    const bubbleWidth = 140.0;
    const bubbleHeight = 60.0;
    final bubbleX = tapPosition.dx - (bubbleWidth / 2);
    final bubbleY = tapPosition.dy - 80;

    final bubbleRect =
        Rect.fromLTWH(bubbleX, bubbleY, bubbleWidth, bubbleHeight);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bubbleRect, const Radius.circular(8)),
      Paint()..color = statusColor.withValues(alpha: 0.9),
    );

    // Draw text in bubble
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        children: [
          TextSpan(
            text: status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const TextSpan(text: '\n'),
          TextSpan(
            text: 'Depth: ${tapDepth.toStringAsFixed(1)}m',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 10,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
    textPainter.layout(maxWidth: 130);
    textPainter.paint(canvas, Offset(bubbleX + 5, bubbleY + 8));
  }

  @override
  bool shouldRepaint(GroundwaterCrossSectionPainter oldDelegate) {
    return oldDelegate.depth != depth || oldDelegate.tapPosition != tapPosition;
  }
}

class WaterAvailabilityTimeline extends StatelessWidget {
  final List<double> nextWeekAvailability;
  final double dailyAvailability;

  const WaterAvailabilityTimeline({
    super.key,
    required this.nextWeekAvailability,
    required this.dailyAvailability,
  });

  @override
  Widget build(BuildContext context) {
    final maxAvailability = dailyAvailability * 1.2;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 Water Availability Timeline',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Next 7 days water supply forecast',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            // Chart
            SizedBox(
              height: 200,
              child: CustomPaint(
                painter: AvailabilityChartPainter(
                  data: nextWeekAvailability,
                  maxValue: maxAvailability,
                ),
                size: const Size(double.infinity, 200),
              ),
            ),
            const SizedBox(height: 20),
            // Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    'Highest',
                    '${(nextWeekAvailability.reduce((a, b) => a > b ? a : b) / 1000).toStringAsFixed(1)}k L/ha',
                    const Color(0xFF4CAF50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    'Lowest',
                    '${(nextWeekAvailability.reduce((a, b) => a < b ? a : b) / 1000).toStringAsFixed(1)}k L/ha',
                    const Color(0xFFF57C00),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    'Average',
                    '${(nextWeekAvailability.fold(0.0, (a, b) => a + b) / nextWeekAvailability.length / 1000).toStringAsFixed(1)}k L/ha',
                    const Color(0xFF1976D2),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class AvailabilityChartPainter extends CustomPainter {
  final List<double> data;
  final double maxValue;

  AvailabilityChartPainter({
    required this.data,
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1976D2)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = const Color(0xFF1976D2).withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    // Draw grid lines
    for (int i = 0; i <= 4; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Calculate points
    final points = <Offset>[];
    final xStep = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * xStep;
      final percentage = (data[i] / maxValue).clamp(0, 1);
      final y = size.height - (percentage * size.height);
      points.add(Offset(x, y));
    }

    // Draw filled area
    final path = Path();
    path.moveTo(0, size.height);
    for (final point in points) {
      path.lineTo(point.dx, point.dy);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, fillPaint);

    // Draw line
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }

    // Draw points
    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(
        points[i],
        4,
        Paint()
          ..color = const Color(0xFF1976D2)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );

      canvas.drawCircle(
        points[i],
        4,
        Paint()..color = Colors.white,
      );

      // Draw day labels
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'D${i + 1}',
          style: TextStyle(
            color: Colors.grey.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(points[i].dx - 10, size.height + 8),
      );
    }
  }

  @override
  bool shouldRepaint(AvailabilityChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.maxValue != maxValue;
  }
}
