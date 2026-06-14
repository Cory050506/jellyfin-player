part of '../../main.dart';

class AppSettingsStore {
  static const _settingsKey = 'appSettings';

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_settingsKey);
    if (value == null) {
      return AppSettings.defaults;
    }
    return AppSettings.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  static Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  static Future<void> reset() => save(AppSettings.defaults);
}
