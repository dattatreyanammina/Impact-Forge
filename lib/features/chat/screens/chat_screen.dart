import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../core/theme/app_colors.dart';
import '../../../services/ai_service.dart';
import '../../../utils/image_picker_helper.dart';
import 'package:easy_localization/easy_localization.dart';

// ─── Providers ───────────────────────────────────────────────────────────────
final chatHistoryProvider =
    StateProvider<List<Map<String, dynamic>>>((ref) => []);
final isProcessingProvider = StateProvider<bool>((ref) => false);

const _suggestedQuestions = [
  'What fertilizer to use for groundnut?',
  'Green worms on my tomatoes, what to do?',
  'When will it rain this week?',
  'Kurnool mandi groundnut price today?',
];

// ─── Screen ───────────────────────────────────────────────────────────────────
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isListening = false;
  bool _voiceEnabled = true;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _configureTts();
  }

  @override
  void dispose() {
    _tts.stop();
    _controller.dispose();
    _scrollController.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _configureTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  Future<void> _speakResponse(String text) async {
    if (!_voiceEnabled) return;
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;
    await _tts.stop();
    await _tts.speak(cleaned);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage([String? overrideText]) async {
    final text = (overrideText ?? _controller.text).trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    _controller.clear();

    ref.read(chatHistoryProvider.notifier).update(
          (s) => [...s, {'text': text, 'isUser': true, 'time': _now()}],
        );
    _scrollToBottom();

    ref.read(isProcessingProvider.notifier).state = true;
    final response = await ref.read(aiServiceProvider).sendMessage(text);
    ref.read(isProcessingProvider.notifier).state = false;

    HapticFeedback.selectionClick();
    ref.read(chatHistoryProvider.notifier).update(
          (s) => [...s, {'text': response, 'isUser': false, 'time': _now()}],
        );
    _scrollToBottom();
    _speakResponse(response);
  }

  void _pickImage() async {
    final image = await pickImageFromCamera(imageQuality: 80);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    ref.read(chatHistoryProvider.notifier).update(
          (s) => [
            ...s,
            {
              'text': 'Analyzing the crop...',
              'isUser': true,
              'image': bytes,
              'time': _now()
            }
          ],
        );
    _scrollToBottom();

    ref.read(isProcessingProvider.notifier).state = true;
    final response = await ref.read(aiServiceProvider).sendMessage(
          'Identify this plant/crop and any diseases. Give advice in English for a Kurnool farmer.',
          images: [image],
        );
    ref.read(isProcessingProvider.notifier).state = false;

    ref.read(chatHistoryProvider.notifier).update(
          (s) => [...s, {'text': response, 'isUser': false, 'time': _now()}],
        );
    _scrollToBottom();
    _speakResponse(response);
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onError: (_) => setState(() => _isListening = false),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            _controller.text = val.recognizedWords;
          },
          localeId: 'en_IN',
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(chatHistoryProvider);
    final isProcessing = ref.watch(isProcessingProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F0),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: history.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: history.length,
                    itemBuilder: (context, index) =>
                        _ChatBubble(msg: history[index]),
                  ),
          ),
          if (isProcessing) _buildTypingIndicator(),
          if (history.isEmpty) _buildSuggestedQuestions(),
          _buildInputArea(),
        ],
      ),
    );
  }

  // ─── Custom Header ───────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                child: Text('🌱', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ai_saathi'.tr(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    Text('kisan_saathi_online'.tr(), // Need to add this key
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _voiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: Colors.white,
                ),
                onPressed: () async {
                  setState(() => _voiceEnabled = !_voiceEnabled);
                  if (!_voiceEnabled) {
                    await _tts.stop();
                  }
                },
                tooltip: _voiceEnabled ? 'Mute voice' : 'Enable voice',
              ),
              IconButton(
                icon: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white),
                onPressed: _pickImage,
                tooltip: 'scan_crop'.tr(),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.white70),
                onPressed: () {
                  ref.read(chatHistoryProvider.notifier).state = [];
                },
                tooltip: 'clear_chat'.tr(), // Need to add this key
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Empty state ─────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌱', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text('hello_saathi'.tr(),
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark)),
          const SizedBox(height: 6),
          Text(
            'ask_anything'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ─── Suggested questions ──────────────────────────────────────────────────
  Widget _buildSuggestedQuestions() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: _suggestedQuestions
            .map((q) => GestureDetector(
                  onTap: () => _sendMessage(q),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4)
                      ],
                    ),
                    child: Text(q,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.primaryDark)),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ─── Typing Indicator ─────────────────────────────────────────────────────
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary,
            child: Text('🌱', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          FadeTransition(
            opacity: _pulseCtrl,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: AppColors.primary),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Input Area ───────────────────────────────────────────────────────────
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -3))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Mic button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: _isListening
                    ? Colors.red.shade50
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _listen,
                icon: Icon(
                  _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: _isListening ? Colors.red : Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Text field
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 100),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'type_message'.tr(),
                    hintStyle: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            GestureDetector(
              onTap: () => _sendMessage(),
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _now() {
    final t = TimeOfDay.now();
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}

// ─── Chat Bubble ──────────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg['isUser'] as bool;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary,
              child: Text('🌱', style: TextStyle(fontSize: 10)),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(
                            colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                          )
                        : null,
                    color: isUser ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft:
                          Radius.circular(isUser ? 18 : 4),
                      bottomRight:
                          Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (msg['image'] != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(msg['image'] as Uint8List,
                              height: 180, fit: BoxFit.cover),
                        ),
                      if (msg['image'] != null) const SizedBox(height: 6),
                      Text(
                        msg['text'] as String,
                        style: TextStyle(
                            color: isUser
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontSize: 14,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                if (msg['time'] != null)
                  Text(
                    msg['time'] as String,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 6),
        ],
      ),
    );
  }
}
