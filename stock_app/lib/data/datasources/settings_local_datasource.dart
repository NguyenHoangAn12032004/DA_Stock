import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/errors/failures.dart';

abstract class SettingsLocalDataSource {
  Future<ThemeMode> getThemeMode();
  Future<void> setThemeMode(ThemeMode mode);
  Future<bool> getNotificationsEnabled();
  Future<void> setNotificationsEnabled(bool enabled);
  
  Future<String> getLanguage();
  Future<void> setLanguage(String language);
  
  Future<String> getDataRefreshRate();
  Future<void> setDataRefreshRate(String rate);
  
  Future<bool> getNewsAlertsEnabled();
  Future<void> setNewsAlertsEnabled(bool enabled);
  
  Future<bool> getAiInsightsEnabled();
  Future<void> setAiInsightsEnabled(bool enabled);
}

class SettingsLocalDataSourceImpl implements SettingsLocalDataSource {
  final Box _box;

  SettingsLocalDataSourceImpl(this._box);
  
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyNotifications = 'notifications_enabled';
  static const String _keyLanguage = 'language';
  static const String _keyDataRefresh = 'data_refresh';
  static const String _keyNewsAlerts = 'news_alerts';
  static const String _keyAiInsights = 'ai_insights';

  @override
  Future<ThemeMode> getThemeMode() async {
    final modeIndex = _box.get(_keyThemeMode);
    if (modeIndex == null) return ThemeMode.system;
    return ThemeMode.values[modeIndex as int];
  }

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    await _box.put(_keyThemeMode, mode.index);
  }

  @override
  Future<bool> getNotificationsEnabled() async {
    return _box.get(_keyNotifications, defaultValue: true);
  }

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {
    await _box.put(_keyNotifications, enabled);
  }

  @override
  Future<String> getLanguage() async {
    return _box.get(_keyLanguage, defaultValue: 'English');
  }

  @override
  Future<void> setLanguage(String language) async {
    await _box.put(_keyLanguage, language);
  }

  @override
  Future<String> getDataRefreshRate() async {
    return _box.get(_keyDataRefresh, defaultValue: 'Auto');
  }

  @override
  Future<void> setDataRefreshRate(String rate) async {
    await _box.put(_keyDataRefresh, rate);
  }

  @override
  Future<bool> getNewsAlertsEnabled() async {
    return _box.get(_keyNewsAlerts, defaultValue: true);
  }

  @override
  Future<void> setNewsAlertsEnabled(bool enabled) async {
    await _box.put(_keyNewsAlerts, enabled);
  }

  @override
  Future<bool> getAiInsightsEnabled() async {
    return _box.get(_keyAiInsights, defaultValue: false);
  }

  @override
  Future<void> setAiInsightsEnabled(bool enabled) async {
    await _box.put(_keyAiInsights, enabled);
  }
}
