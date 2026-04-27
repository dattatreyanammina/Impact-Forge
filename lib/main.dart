import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'core/theme/app_theme.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'app.dart';
import 'services/image_cache_service.dart';
import 'services/cache_aware_http_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase initialization:
  // - Web can use --dart-define keys (see FirebaseBootstrap)
  // - Android/iOS can use platform config files from Firebase console
  try {
    await FirebaseBootstrap.initialize();
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // Localization
  await EasyLocalization.ensureInitialized();

  // Initialize Hive for offline support
  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('cache');

  // Initialize image cache service
  await ImageCacheService.initialize();

  // Initialize cache-aware HTTP client
  await CacheAwareHttpClient.initialize();

  runApp(
    EasyLocalization(
      path: 'assets/translations',
      supportedLocales: const [Locale('en'), Locale('te')],
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      child: const ProviderScope(
        child: KisanSaathiApp(),
      ),
    ),
  );
}

class KisanSaathiApp extends ConsumerWidget {
  const KisanSaathiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Kisan Saathi AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}
