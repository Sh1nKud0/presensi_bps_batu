import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appThemeController = AppThemeController();

class AppThemeController extends ValueNotifier<ThemeMode> {
  AppThemeController() : super(ThemeMode.light);

  static const _darkModeKey = 'dark_mode_enabled';
  SharedPreferences? _preferences;

  Future<void> load() async {
    _preferences = await SharedPreferences.getInstance();
    value = _preferences!.getBool(_darkModeKey) == true
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  Future<void> setDarkMode(bool enabled) async {
    final preferences = _preferences ??= await SharedPreferences.getInstance();
    final saved = await preferences.setBool(_darkModeKey, enabled);
    if (!saved) throw StateError('Pilihan tema tidak berhasil disimpan');
    value = enabled ? ThemeMode.dark : ThemeMode.light;
  }
}
