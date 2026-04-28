import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';

class FirebaseBootstrap {
  static bool _initialized = false;
  static Object? _initializationError;

  // Only rely on our internal flag to determine initialization state.
  // Accessing `Firebase.apps` can throw on web if the JS interop isn't ready,
  // so provide a safe accessor for callers that need to know if any apps
  // are available without throwing.
  static bool get isInitialized => _initialized;
  static bool get appsAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Object? get initializationError => _initializationError;

  static Future<void> initialize() async {
    // Avoid direct `Firebase.apps` calls that may throw when the web
    // firebase JS bindings are not yet available. Use `appsAvailable`.
    if (_initialized || appsAvailable) {
      _initialized = true;
      return;
    }

    if (!appsAvailable) {
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