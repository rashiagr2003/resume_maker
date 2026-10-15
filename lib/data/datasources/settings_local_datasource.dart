import 'package:shared_preferences/shared_preferences.dart';

/// Manages non-sensitive application settings.
/// Note: API keys are securely managed by the server-side proxy service
/// and are NEVER persisted in browser localStorage or compiled client binaries.
class SettingsLocalDataSource {
  static const _keyBackendUrl = 'settings_backend_url';
  static const _keySelectedModel = 'settings_selected_model';

  static const String defaultBackendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// Returns the configured backend URL. In production, defaults to backend proxy.
  Future<String> getBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_keyBackendUrl);
    if (url != null && url.trim().isNotEmpty) {
      return url.trim();
    }
    return defaultBackendUrl;
  }

  Future<void> saveBackendUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBackendUrl, url.trim());
  }

  Future<void> saveModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedModel, model);
  }

  Future<String> getSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySelectedModel) ?? 'gemini-1.5-flash';
  }

  /// Purges all application preferences and cached entries
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Ephemeral in-memory development key (NEVER persisted to browser localStorage)
  String? _ephemeralKey;
  Future<void> saveApiKey(String apiKey) async {
    _ephemeralKey = apiKey.trim().isEmpty ? null : apiKey.trim();
  }

  Future<String?> getApiKey() async {
    return _ephemeralKey;
  }
}
