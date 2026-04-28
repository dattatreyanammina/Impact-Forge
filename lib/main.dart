import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'core/theme/app_theme.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'app.dart';
import 'services/image_cache_service.dart';
import 'services/cache_aware_http_client.dart';

class AppInitializer extends StatelessWidget {
  const AppInitializer({super.key});

  @override
  Widget build(BuildContext context) {
    return EasyLocalization(
      path: 'assets/translations',
      supportedLocales: const [Locale('en'), Locale('te')],
      fallbackLocale: const Locale('en'),
      child: const ProviderScope(
        child: KisanSaathiApp(),
      ),
    );
  }
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 CRITICAL FIX
  await FirebaseBootstrap.initialize();

  await EasyLocalization.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('cache');

  await ImageCacheService.initialize();
  await CacheAwareHttpClient.initialize();

  // 🔥 Wrap with FutureBuilder boot app
  runApp(const AppInitializer());
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
