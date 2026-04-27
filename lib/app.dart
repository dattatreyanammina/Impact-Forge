import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/dashboard/screens/home_screen.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/scan/screens/scan_screen.dart';
import 'features/market/screens/market_screen.dart';
import 'features/climate/screens/climate_screen.dart';
import 'features/community/screens/community_screen.dart';
import 'features/field/screens/field_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'services/auth_service.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final isGuest = ref.watch(bypassAuthProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: null, // For simplicity in this demo, let ref.watch do the work.
    redirect: (context, state) {
      final isLoggedIn = authState.value != null || isGuest;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatScreen(),
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) => const ScanScreen(),
      ),
      GoRoute(
        path: '/market',
        builder: (context, state) => const MarketScreen(),
      ),
      GoRoute(
        path: '/climate',
        builder: (context, state) => const ClimateScreen(),
      ),
      GoRoute(
        path: '/community',
        builder: (context, state) => const CommunityScreen(),
      ),
      GoRoute(
        path: '/field',
        builder: (context, state) => const FieldScreen(),
      ),
    ],
  );
});
