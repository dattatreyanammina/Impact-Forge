import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final bypassAuthProvider = StateProvider<bool>((ref) => false);

class AuthService {
  late final FirebaseAuth _auth;
  GoogleSignIn? _googleSignIn;
  bool _firebaseInitialized = false;

  AuthService() {
    try {
      _auth = FirebaseAuth.instance;
      _firebaseInitialized = true;
      if (!kIsWeb) {
        _googleSignIn = GoogleSignIn();
      }
    } catch (e) {
      debugPrint('AuthService: Firebase not initialized or not supported on this platform yet: $e');
    }
  }

  Stream<User?> get authStateChanges {
    if (!_firebaseInitialized) return Stream.value(null);
    return _auth.authStateChanges();
  }

  User? get currentUser {
    if (!_firebaseInitialized) return null;
    return _auth.currentUser;
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (!_firebaseInitialized) {
      throw Exception(
        'Firebase is not initialized. Configure Firebase first, then try again.',
      );
    }

    if (kIsWeb) {
      try {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..setCustomParameters({'prompt': 'select_account'});
        return await _auth.signInWithPopup(provider);
      } catch (e) {
        debugPrint('Error during Google Sign-In on web: $e');
        rethrow;
      }
    }

    if (_googleSignIn == null) {
      throw Exception(
        'Google Sign-In is not available on this platform/configuration.',
      );
    }

    try {
      // Trigger the authentication flow
      final googleUser = await _googleSignIn!.signIn();
      if (googleUser == null) return null; // The user canceled the sign-in

      // Obtain the auth details from the request
      final googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Error during Google Sign-In: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn?.signOut();
    if (_firebaseInitialized) {
      await _auth.signOut();
    }
  }
}
