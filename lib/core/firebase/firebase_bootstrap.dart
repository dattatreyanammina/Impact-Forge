import 'package:firebase_core/firebase_core.dart';

class FirebaseBootstrap {
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDMnDA_lUVXl8oqmmjTZAyNzNYSGKNmc8s",
        appId: "1:937705200109:web:8265f895c9ec2f7a46efe4",
        messagingSenderId: "937705200109",
        projectId: "hack-a10bb",
        authDomain: "hack-a10bb.firebaseapp.com",
        storageBucket: "hack-a10bb.appspot.com",
      ),
    );

    print("🔥 FIREBASE WORKING");
  }
}