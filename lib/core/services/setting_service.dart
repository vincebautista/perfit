import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingService {
  Future<Map<String, int>> loadRest() async {
    final prefs = await SharedPreferences.getInstance();

    return {"rest": prefs.getInt("rest") ?? 60};
  }

  Future<Map<String, int>> loadCountdown() async {
    final prefs = await SharedPreferences.getInstance();

    return {"countdown": prefs.getInt("countdown") ?? 3};
  }

  Future<Map<String, int>> loadReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt("hour") ?? 6;
    final minute = prefs.getInt("minute") ?? 0;

    return {"hour": hour, "minute": minute};
  }

  Future<void> saveRest(int rest) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt("rest", rest);
  }

  Future<void> saveCountdown(int countdown) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt("countdown", countdown);
  }

  Future<void> saveReminder(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt("hour", hour);
    await prefs.setInt("minute", minute);
  }

  Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool("isDarkMode") ?? true;
    return isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> saveThemeMode(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("isDarkMode", isDarkMode);
  }
}
