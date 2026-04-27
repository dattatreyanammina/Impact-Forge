import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static Future<void> initialize() async {
    if (Firebase.apps.isNotEmpty) {
      return;
    }

    final webOptions = _webOptionsFromDartDefine();
    if (kIsWeb) {
      if (webOptions == null) {
        throw StateError(
          'Missing Firebase web configuration. Pass FIREBASE_WEB_* dart-defines for web runs.',
        );
      }
      await Firebase.initializeApp(options: webOptions);
      return;
    }

    await Firebase.initializeApp();
  }

  static FirebaseOptions? _webOptionsFromDartDefine() {
    const apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
    const messagingSenderId = String.fromEnvironment('FIREBASE_WEB_MESSAGING_SENDER_ID');
    const projectId = String.fromEnvironment('FIREBASE_WEB_PROJECT_ID');
    const authDomain = String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN');
    const storageBucket = String.fromEnvironment('FIREBASE_WEB_STORAGE_BUCKET');
    const measurementId = String.fromEnvironment('FIREBASE_WEB_MEASUREMENT_ID');

    final required = <String, String>{
      'FIREBASE_WEB_API_KEY': apiKey,
      'FIREBASE_WEB_APP_ID': appId,
      'FIREBASE_WEB_MESSAGING_SENDER_ID': messagingSenderId,
      'FIREBASE_WEB_PROJECT_ID': projectId,
      'FIREBASE_WEB_AUTH_DOMAIN': authDomain, 
      'FIREBASE_WEB_STORAGE_BUCKET': storageBucket,
    };

    final hasMissing = required.values.any((value) => value.isEmpty);
    if (hasMissing) {
      return null;
    }

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain,
      storageBucket: storageBucket,
      measurementId: measurementId.isEmpty ? null : measurementId,
    );
  }
}
