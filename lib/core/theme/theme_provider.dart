import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns the light/dark/system choice. Defaults to Ghost (light); an explicit
/// choice, including "follow system", is remembered across launches.
///
/// Persistence is deliberately behind a small interface so swapping in
/// SharedPreferences (or any store) does not touch the widget tree.
abstract interface class ThemeStore {
  Future<String?> read();
  Future<void> write(String? value);
}

class InMemoryThemeStore implements ThemeStore {
  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String? value) async => _value = value;
}

/// Persists the choice on the device so it survives an app restart.
class SharedPreferencesThemeStore implements ThemeStore {
  static const _key = 'theme_mode';
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  @override
  Future<String?> read() => _prefs.getString(_key);

  @override
  Future<void> write(String? value) =>
      value == null ? _prefs.remove(_key) : _prefs.setString(_key, value);
}

class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this._store);

  final ThemeStore _store;
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get followsSystem => _mode == ThemeMode.system;

  bool isDark(BuildContext context) => switch (_mode) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system =>
          MediaQuery.platformBrightnessOf(context) == Brightness.dark,
      };

  Future<void> load() async {
    final saved = await _store.read();
    _mode = switch (saved) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    await _store.write(switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    });
  }

  Future<void> toggle(BuildContext context) =>
      setMode(isDark(context) ? ThemeMode.light : ThemeMode.dark);

  Future<void> followSystem() => setMode(ThemeMode.system);
}
