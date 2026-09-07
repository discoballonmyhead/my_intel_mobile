import 'package:flutter/material.dart';

/// Owns the light/dark/system choice. Mirrors `useTheme.jsx`: an explicit
/// choice is remembered, otherwise the app follows the platform setting.
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

class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this._store);

  final ThemeStore _store;
  ThemeMode _mode = ThemeMode.system;

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
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
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
      ThemeMode.system => null,
    });
  }

  Future<void> toggle(BuildContext context) =>
      setMode(isDark(context) ? ThemeMode.light : ThemeMode.dark);

  Future<void> followSystem() => setMode(ThemeMode.system);
}
