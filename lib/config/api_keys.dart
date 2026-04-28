class ApiKeys {
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyA29GgB_B1Lcu-aUkugTD9lvdk4XjKvLmQ',
  );

  // Optional backward-compatible alias for older build commands.
  static const String geminiLegacyApiKey = String.fromEnvironment(
    'GEMINI_API',
    defaultValue: '',
  );
}