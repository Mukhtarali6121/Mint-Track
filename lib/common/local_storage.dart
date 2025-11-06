import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static final LocalStorage _instance = LocalStorage._internal();
  factory LocalStorage() => _instance;
  LocalStorage._internal();

  SharedPreferences? _prefs;

  /// Initialize SharedPreferences (call this once in main)
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Save boolean
  Future<void> setBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  /// Get boolean
  bool getBool(String key, {bool defaultValue = false}) {
    return _prefs?.getBool(key) ?? defaultValue;
  }

  /// Save String
  Future<void> setString(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  /// Get String
  String getString(String key, {String defaultValue = ''}) {
    return _prefs?.getString(key) ?? defaultValue;
  }

  /// Save int
  Future<void> setInt(String key, int value) async {
    await _prefs?.setInt(key, value);
  }

  /// Get int
  int getInt(String key, {int defaultValue = 0}) {
    return _prefs?.getInt(key) ?? defaultValue;
  }

  /// Remove a key
  Future<void> remove(String key) async {
    await _prefs?.remove(key);
  }

  /// Clear all
  Future<void> clear() async {
    await _prefs?.clear();
  }
}
