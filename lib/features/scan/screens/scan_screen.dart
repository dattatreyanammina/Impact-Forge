import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/ai_service.dart';
import '../../../services/tflite_service.dart';
import '../../../utils/image_picker_helper.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with SingleTickerProviderStateMixin {
  XFile? _image;
  Uint8List? _imageBytes;
  String? _verdict;
  String? _confidence;
  String? _summary;
  String? _analysisResult;
  String? _mlLabel;
  bool _isAnalyzing = false;
  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndAnalyze(ImageSource source) async {
    final image = source == ImageSource.camera
        ? await pickImageFromCamera(imageQuality: 85, maxWidth: 1200)
        : await pickImageFromGallery(imageQuality: 85, maxWidth: 1200);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    setState(() {
      _image = image;
      _imageBytes = bytes;
      _isAnalyzing = true;
      _mlLabel = null;
      _verdict = null;
      _confidence = null;
      _summary = null;
      _analysisResult = null;
    });

    try {
      if (!kIsWeb) {
        final labels = await ref.read(tfliteServiceProvider).detectFromImage(image);
        if (labels.isNotEmpty) {
          setState(() {
            _mlLabel =
                '${labels.first.label} (${(labels.first.confidence * 100).toStringAsFixed(0)}% confidence)';
          });
        }
      }
    } catch (_) {}

    final geminiResponse = await ref.read(aiServiceProvider).sendMessage(
          'You are an agricultural crop health inspector for farmers in the Kurnool/Rayalaseema region. '
          'Inspect the image and return a concise assessment in this exact format:\n'
          'VERDICT: HEALTHY or DEFECT DETECTED\n'
          'CONFIDENCE: low/medium/high\n'
          'SUMMARY: one short sentence explaining why\n'
          'ADVICE: one short sentence with the next best action\n'
          'If you cannot tell, say VERDICT: UNCLEAR. '
          'Do not add extra headings. Keep it short and practical.',
          images: [_image!],
        );

    setState(() {
      _analysisResult = geminiResponse;
      _parseVerdict(geminiResponse);
      _isAnalyzing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFFE65100),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'scan_crop'.tr(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  Text(
                    'scan_and_detect'.tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFBF360C), Color(0xFFE64A19), Color(0xFFFF7043)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 20),
                    child: Opacity(
                      opacity: 0.15,
                      child: Text('??', style: TextStyle(fontSize: 80)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildImageBox(),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                  const SizedBox(height: 20),
                  if (_mlLabel != null) _buildMLLabel(),
                  if (_isAnalyzing) _buildAnalyzingCard(),
                  if (_analysisResult != null && !_isAnalyzing) _buildResultCard(),
                  if (_image == null) _buildTipsCard(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageBox() {
    return Container(
      width: double.infinity,
      height: 280,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isAnalyzing ? AppColors.primary : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _imageBytes != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(_imageBytes!, fit: BoxFit.cover),
                if (_isAnalyzing)
                  Container(
                    color: Colors.black.withValues(alpha: 0.38),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 12),
                          Text(
                            'analyzing'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'analyzing_gemini'.tr(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE65100).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_enhance_rounded,
                    size: 50,
                    color: Color(0xFFE65100),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'take_photo'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'photo_tips_desc'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: 'camera'.tr(),
            sublabel: 'camera_sub'.tr(),
            icon: Icons.camera_alt_rounded,
            color: const Color(0xFFE65100),
            onTap: () => _pickAndAnalyze(ImageSource.camera),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            label: 'gallery'.tr(),
            sublabel: 'gallery_sub'.tr(),
            icon: Icons.photo_library_rounded,
            color: const Color(0xFF1565C0),
            onTap: () => _pickAndAnalyze(ImageSource.gallery),
          ),
        ),
      ],
    );
  }

  Widget _buildMLLabel() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.memory_rounded, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${'on_device_detection'.tr()}: $_mlLabel',
              style: const TextStyle(fontSize: 12, color: AppColors.primaryDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: [
          const LinearProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 12),
          Text('analyzing'.tr(), style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVerdictBanner(),
          if (_summary != null && _summary!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _summary!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.psychology_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'expert_advice'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  Text(
                    'ai_powered'.tr(),
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 20),
          Text(_analysisResult!, style: const TextStyle(fontSize: 14, height: 1.6)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _image = null;
                _imageBytes = null;
                _analysisResult = null;
                _mlLabel = null;
              });
            },
            icon: const Icon(Icons.refresh_rounded),
            label: Text('scan_again'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildVerdictBanner() {
    final verdict = (_verdict ?? 'UNCLEAR').toUpperCase();
    final isHealthy = verdict.contains('HEALTHY');
    final isDefect = verdict.contains('DEFECT');
    final isUnclear = !isHealthy && !isDefect;

    final Color bgColor = isHealthy
        ? Colors.green.shade50
        : isDefect
            ? Colors.orange.shade50
            : Colors.grey.shade100;
    final Color borderColor = isHealthy
        ? Colors.green.shade200
        : isDefect
            ? Colors.orange.shade200
            : Colors.grey.shade300;
    final Color textColor = isHealthy
        ? Colors.green.shade800
        : isDefect
            ? Colors.orange.shade800
            : Colors.grey.shade800;
    final IconData icon = isHealthy
        ? Icons.verified_rounded
        : isDefect
            ? Icons.warning_amber_rounded
            : Icons.help_outline_rounded;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHealthy
                      ? 'Plant looks healthy'
                      : isDefect
                          ? 'Possible defect detected'
                          : 'Assessment unclear',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _confidence == null
                      ? (isUnclear ? 'Please retake the photo with better light and closer focus.' : '')
                      : 'Confidence: $_confidence',
                  style: TextStyle(color: textColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    final tips = [
      {'icon': '??', 'tip': 'tip_light'.tr()},
      {'icon': '??', 'tip': 'tip_close'.tr()},
      {'icon': '??', 'tip': 'tip_steady'.tr()},
      {'icon': '??', 'tip': 'tip_offline'.tr()},
    ];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'tips_title'.tr(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
          Text(
            'tips_subtitle'.tr(),
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ...tips.map(
            (t) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Text(t['icon']!, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Text(
                    t['tip']!,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _parseVerdict(String response) {
    final lines = response.split(RegExp(r'\r?\n'));
    String? verdict;
    String? confidence;
    String? summary;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      final upper = line.toUpperCase();
      if (upper.startsWith('VERDICT:')) {
        verdict = line.substring(8).trim();
      } else if (upper.startsWith('CONFIDENCE:')) {
        confidence = line.substring(11).trim();
      } else if (upper.startsWith('SUMMARY:')) {
        summary = line.substring(8).trim();
      }
    }

    final normalized = response.toLowerCase();
    verdict ??= normalized.contains('healthy') && !normalized.contains('defect')
        ? 'HEALTHY'
        : normalized.contains('defect') ||
                normalized.contains('disease') ||
                normalized.contains('pest') ||
                normalized.contains('infection') ||
                normalized.contains('nutrient deficiency')
            ? 'DEFECT DETECTED'
            : 'UNCLEAR';

    _verdict = verdict;
    _confidence = confidence;
    _summary = summary;
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.94)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.color,
                widget.color.withValues(red: (widget.color.r * 255 + 30).clamp(0, 255) / 255),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    widget.sublabel,
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
