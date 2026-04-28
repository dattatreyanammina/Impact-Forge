import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';

class FirebaseBootstrap {
  static bool _initialized = false;
  static Object? _initializationError;

  static bool get isInitialized => _initialized || Firebase.apps.isNotEmpty;
  static Object? get initializationError => _initializationError;

  static Future<void> initialize() async {
    if (_initialized || Firebase.apps.isNotEmpty) {
      _initialized = true;
      return;
    }

    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        _initialized = true;
        _initializationError = null;
      } catch (e, st) {
        if (kIsWeb) {
          try {
            await Firebase.initializeApp();
            _initialized = true;
            _initializationError = null;
            debugPrint(
              'Firebase initialized via fallback web config after options-based init failure.',
            );
            return;
          } catch (_) {
            // Fall through to the original error details.
          }
        }

        _initialized = false;
        _initializationError = e;
        debugPrint('Firebase initialization failed: $e');
        debugPrintStack(stackTrace: st);
      }
    }
  }
}