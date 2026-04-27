import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/weather_service.dart';
import '../../../services/market_service.dart';
import '../../../services/auth_service.dart';
import 'package:easy_localization/easy_localization.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late final TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController(
      text: ref.read(weatherLocationProvider),
    );
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weatherAsync = ref.watch(weatherProvider);
    final marketAsync = ref.watch(marketPreviewProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeIn,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ─── Premium App Bar ────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 320,
              collapsedHeight: 70,
              pinned: true,
              stretch: true,
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: _buildHeroHeader(weatherAsync),
                title: Opacity(
                  opacity: 0.0, // We hide the default title to use our custom one in collapsed mode if needed
                  child: _buildCollapsedTitle(),
                ),
              ),
              title: _buildCollapsedTitle(),
              actions: [
                IconButton(
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    ref.read(bypassAuthProvider.notifier).state = false;
                    ref.read(authServiceProvider).signOut();
                  },
                  icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 20),
                  tooltip: 'Logout',
                ),
                const SizedBox(width: 8),
              ],
            ),

            // ─── Content ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOfflineBanner(weatherAsync),
                  _buildQuickActions(context),
                  _buildSectionTitle('Market Updates', 'Today\'s Mandi Prices',
                      Icons.trending_up_rounded),
                  _buildMarketStrip(marketAsync),
                  _buildSectionTitle(
                      'AI Suggestions', 'Recent Advice', Icons.history_rounded),
                  _buildRecentActivity(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ─── Hero Header (weather) ───────────────────────────────────────────
  Widget _buildHeroHeader(AsyncValue<WeatherData> weatherAsync) {
    return weatherAsync.when(
      data: (w) => _heroContainerV2(w),
      loading: () => _heroContainerV2(WeatherData.demo()),
      error: (error, _) => _heroErrorContainer(error.toString()),
    );
  }

  // ignore: unused_element
  Widget _heroContainer(WeatherData w) {
    final icon = _weatherIcon(w.icon);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -40,
            right: -40,
            child: _glowCircle(140, Colors.white.withValues(alpha: 0.05)),
          ),
          Positioned(
            bottom: 0,
            left: -60,
            child: _glowCircle(200, Colors.white.withValues(alpha: 0.04)),
          ),
          // Content
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10), // Guard against the App Bar title overlap
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white24,
                          backgroundImage: (ref.watch(authStateProvider).value?.photoURL != null) 
                            ? NetworkImage(ref.watch(authStateProvider).value!.photoURL!) 
                            : null,
                          child: (ref.watch(authStateProvider).value?.photoURL == null) 
                            ? const Icon(Icons.person_rounded, color: Colors.white, size: 22) 
                            : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ref.watch(bypassAuthProvider)
                                  ? 'hi_guest'.tr()
                                  : 'hi_name'.tr(args: [ref.watch(authStateProvider).value?.displayName?.split(' ').first ?? 'Farmer']),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              w.location,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 13),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (w.isFromCache)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Cached'.tr(),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildLocationSearch(),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${w.tempC.toStringAsFixed(0)}°C',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 52,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                              ),
                            ),
                            Text(
                              w.condition,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.water_drop_outlined,
                                    color: Colors.white70, size: 14),
                                Text(' ${w.humidity}%  ',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                                const Icon(Icons.air_rounded,
                                    color: Colors.white70, size: 14),
                                Text(' ${w.windSpeed.toStringAsFixed(1)} km/h',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(icon, style: const TextStyle(fontSize: 72)),
                      ],
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

  Widget _buildLocationSearch() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: TextField(
              controller: _locationController,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                hintText: 'Search city or state',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
              onSubmitted: (_) => _applyWeatherLocation(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: _applyWeatherLocation,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF4B400),
            foregroundColor: const Color(0xFF1B5E20),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: const Text(
            'Go',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _heroContainerV2(WeatherData w) {
    final icon = _weatherIcon(w.icon);
    final authState = ref.watch(authStateProvider).value;
    final displayName = authState?.displayName?.split(' ').first ?? 'Farmer';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: _glowCircle(140, Colors.white.withValues(alpha: 0.05)),
          ),
          Positioned(
            bottom: 0,
            left: -60,
            child: _glowCircle(200, Colors.white.withValues(alpha: 0.04)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white24,
                        backgroundImage: authState?.photoURL != null
                            ? NetworkImage(authState!.photoURL!)
                            : null,
                        child: authState?.photoURL == null
                            ? const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 22,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ref.watch(bypassAuthProvider)
                                  ? 'hi_guest'.tr()
                                  : 'hi_name'.tr(args: [displayName]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              w.location,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (w.isFromCache)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Cached'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildLocationSearch(),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${w.tempC.toStringAsFixed(0)}°C',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              w.condition,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                _weatherMetaChip(
                                  Icons.water_drop_outlined,
                                  '${w.humidity}%',
                                ),
                                _weatherMetaChip(
                                  Icons.air_rounded,
                                  '${w.windSpeed.toStringAsFixed(1)} km/h',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(icon, style: const TextStyle(fontSize: 68)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weatherMetaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroErrorContainer(String message) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              const Text(
                'Live Andhra Pradesh Weather',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              _buildLocationSearch(),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applyWeatherLocation() {
    final nextLocation = _locationController.text.trim();
    if (nextLocation.isEmpty) return;
    HapticFeedback.selectionClick();
    ref.read(weatherLocationProvider.notifier).state = nextLocation;
    WeatherService.instance.savePreferredLocation(nextLocation);
  }

  Widget _glowCircle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  // ─── Collapsed Title ─────────────────────────────────────────────────
  Widget _buildCollapsedTitle() {
    return Text(
      'app_title'.tr(),
      style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
    );
  }

  // ─── Offline banner ──────────────────────────────────────────────────
  Widget _buildOfflineBanner(AsyncValue<WeatherData> weatherAsync) {
    final isOffline = weatherAsync.maybeWhen(
      data: (w) => w.isFromCache,
      orElse: () => false,
    );
    if (!isOffline) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: Colors.orange.shade100,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 14, color: Colors.orange),
          const SizedBox(width: 8),
          Text('offline_cached'.tr(),
              style: TextStyle(color: Colors.orange.shade800, fontSize: 12)),
        ],
      ),
    );
  }

  // ─── Quick Actions Grid ───────────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {
        'titleTe': 'Scan',
        'title': 'Scan Plant',
        'icon': Icons.camera_enhance_rounded,
        'color': const Color(0xFFE65100),
        'bg': const Color(0xFFFFF3E0),
        'route': '/scan',
      },
      {
        'titleTe': 'Chat',
        'title': 'Talk to Saathi',
        'icon': Icons.smart_toy_rounded,
        'color': AppColors.primary,
        'bg': const Color(0xFFE8F5E9),
        'route': '/chat',
      },
      {
        'titleTe': 'Prices',
        'title': 'Market Prices',
        'icon': Icons.storefront_rounded,
        'color': const Color(0xFF1565C0),
        'bg': const Color(0xFFE3F2FD),
        'route': '/market',
      },
      {
        'titleTe': 'Weather',
        'title': 'Climate Tips',
        'icon': Icons.water_drop_rounded,
        'color': const Color(0xFF00838F),
        'bg': const Color(0xFFE0F7FA),
        'route': '/climate',
      },
      {
        'titleTe': 'Social',
        'title': 'Community',
        'icon': Icons.groups_rounded,
        'color': const Color(0xFF6A1B9A),
        'bg': const Color(0xFFF3E5F5),
        'route': '/community',
      },
      {
        'titleTe': 'Profile',
        'title': 'My Field',
        'icon': Icons.landscape_rounded,
        'color': const Color(0xFF4E342E),
        'bg': const Color(0xFFEFEBE9),
        'route': '/field',
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('platform_tools'.tr(), 'quick_actions'.tr(), Icons.apps_rounded),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: kIsWeb ? 10 : 12,
              crossAxisSpacing: kIsWeb ? 10 : 12,
              // Doubling web aspect ratio halves card height while keeping width stable.
              childAspectRatio: kIsWeb ? 2.9 : 0.95,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final a = actions[index];
              return _QuickActionCard(
                titleEn: a['title'] as String, // Still used as keys? No, better to use tr() directly if possible.
                titleTe: (a['title'] as String).toLowerCase().replaceAll(' ', '_').tr(), // Hacky but works if we match keys.
                icon: a['icon'] as IconData,
                color: a['color'] as Color,
                bgColor: a['bg'] as Color,
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push(a['route'] as String);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Market Strip ────────────────────────────────────────────────────
  Widget _buildMarketStrip(AsyncValue<List<CropPrice>> marketAsync) {
    return marketAsync.when(
      data: (prices) => SizedBox(
        height: kIsWeb ? 210 : 130,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: prices.length,
          itemBuilder: (context, i) => _MarketChip(price: prices[i]),
        ),
      ),
      loading: () => const Center(
          child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator())),
      error: (_, __) => const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Could not load prices.'),
      ),
    );
  }

  // ─── Recent Activity ─────────────────────────────────────────────────
  Widget _buildRecentActivity() {
    final items = [
      {
        'icon': Icons.eco_rounded,
        'color': Colors.green,
        'title': 'Tomato Leaf Spot detected',
        'time': '2h ago',
        'sub': 'Neem oil spray advised'
      },
      {
        'icon': Icons.water_drop_rounded,
        'color': Colors.blue,
        'title': 'Watering schedule updated',
        'time': 'Yesterday',
        'sub': 'Next watering in 3 days'
      },
      {
        'icon': Icons.trending_up_rounded,
        'color': Colors.orange,
        'title': 'Groundnut price ↑ 3.2%',
        'time': '2 days ago',
        'sub': 'Good time to sell'
      },
    ];

    return Column(
      children: items
          .map((item) => Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        (item['color'] as Color).withValues(alpha: 0.12),
                    child: Icon(item['icon'] as IconData,
                        color: item['color'] as Color, size: 20),
                  ),
                  title: Text(item['title'] as String,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(item['sub'] as String,
                      style: const TextStyle(fontSize: 12)),
                  trailing: Text(item['time'] as String,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ),
              ))
          .toList(),
    );
  }

  // ─── Section Title ────────────────────────────────────────────────────
  Widget _buildSectionTitle(String te, String en, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(en.tr(),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark)),
              Text(te.tr(),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Bottom Nav ───────────────────────────────────────────────────────
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -4))
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.transparent,
        elevation: 0,
        currentIndex: 0,
        onTap: (index) {
          HapticFeedback.selectionClick();
          if (index == 1) context.push('/scan');
          if (index == 2) context.push('/chat');
          if (index == 3) context.push('/market');
        },
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.home_rounded), label: 'home'.tr()),
          BottomNavigationBarItem(
              icon: const Icon(Icons.qr_code_scanner_rounded), label: 'scan'.tr()),
          BottomNavigationBarItem(
              icon: const Icon(Icons.smart_toy_rounded), label: 'ai_saathi'.tr()),
          BottomNavigationBarItem(
              icon: const Icon(Icons.storefront_rounded), label: 'market'.tr()),
        ],
      ),
    );
  }

  String _weatherIcon(String code) {
    if (code.startsWith('01')) return '☀️';
    if (code.startsWith('02') || code.startsWith('03')) return '⛅';
    if (code.startsWith('04')) return '☁️';
    if (code.startsWith('09') || code.startsWith('10')) return '🌧️';
    if (code.startsWith('11')) return '⛈️';
    if (code.startsWith('13')) return '❄️';
    return '🌫️';
  }
}

// ─── Quick Action Card (Animated) ────────────────────────────────────────────
class _QuickActionCard extends StatefulWidget {
  final String titleEn;
  final String titleTe;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.titleEn,
    required this.titleTe,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
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
          decoration: BoxDecoration(
            color: widget.bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.color.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                  color: widget.color.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, color: widget.color, size: 26),
              ),
              const SizedBox(height: 8),
              Text(widget.titleEn,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: widget.color),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(widget.titleTe,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Market Chip Card ─────────────────────────────────────────────────────────
class _MarketChip extends StatelessWidget {
  final CropPrice price;
  const _MarketChip({required this.price});

  String _cleanMarketText(String text) {
    final markdownStripped = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
      (m) => m.group(1) ?? '',
    );

    final urlStripped = markdownStripped
        .replaceAll(RegExp(r'https?://\S+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return urlStripped.isEmpty ? 'Live Market' : urlStripped;
  }

  @override
  Widget build(BuildContext context) {
    final isUp = price.trend == PriceTrend.up;
    final isDown = price.trend == PriceTrend.down;
    final cropText = _cleanMarketText(price.crop);
    final mandiText = _cleanMarketText(price.mandi).replaceAll('/', ' / ');
    final trendColor = isUp
        ? Colors.green.shade700
        : isDown
            ? Colors.red.shade700
            : Colors.grey.shade600;
    final trendIcon =
        isUp ? Icons.arrow_upward_rounded : isDown ? Icons.arrow_downward_rounded : Icons.remove_rounded;

    return Container(
      width: kIsWeb ? 190 : 130,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(kIsWeb ? 14 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(price.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            cropText,
            maxLines: kIsWeb ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            mandiText,
            maxLines: kIsWeb ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Text(price.formattedPrice,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: trendColor)),
              const Spacer(),
              Icon(trendIcon, size: 14, color: trendColor),
            ],
          ),
        ],
      ),
    );
  }
}
