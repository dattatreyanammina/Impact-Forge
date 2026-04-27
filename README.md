# kisan_saathi_ai

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Gemini Setup for AI Saathi

AI Saathi uses the Gemini API through the official Dart SDK.

1. Create an API key in Google AI Studio.
2. Run the app with a dart-define key:

```bash
flutter run --dart-define=GEMINI_API_KEY=YOUR_GEMINI_API_KEY
```

Notes:
- The app uses free-tier-friendly Gemini model fallbacks by default.
- Free tier has provider-side rate and quota limits. If the limit is reached, the app shows a retry message and fallback advice.

## Firebase Web Setup (Required for Community Tips)

Community Tips uses Cloud Firestore. For web runs, pass Firebase web config using dart-defines so the app connects to the intended Firebase project.

Example:

```bash
flutter run -d chrome \
	--dart-define=FIREBASE_WEB_API_KEY=YOUR_API_KEY \
	--dart-define=FIREBASE_WEB_APP_ID=YOUR_APP_ID \
	--dart-define=FIREBASE_WEB_MESSAGING_SENDER_ID=YOUR_SENDER_ID \
	--dart-define=FIREBASE_WEB_PROJECT_ID=YOUR_PROJECT_ID \
	--dart-define=FIREBASE_WEB_AUTH_DOMAIN=YOUR_PROJECT_ID.firebaseapp.com \
	--dart-define=FIREBASE_WEB_STORAGE_BUCKET=YOUR_PROJECT_ID.firebasestorage.app \
	--dart-define=FIREBASE_WEB_MEASUREMENT_ID=YOUR_MEASUREMENT_ID \
	--dart-define=GEMINI_API_KEY=YOUR_GEMINI_API_KEY
```

Tip:
- Use values from Firebase Console -> Project Settings -> Your Apps -> Web app config snippet.
