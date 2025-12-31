import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/datasources/settings_local_datasource.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/repositories/settings_repository.dart';

part 'settings_provider.g.dart';

// --- Dependency Injection ---

@riverpod
SettingsLocalDataSource settingsLocalDataSource(SettingsLocalDataSourceRef ref) {
  final box = Hive.box('settings'); // Make sure this box is opened @ main.dart
  return SettingsLocalDataSourceImpl(box);
}

@riverpod
SettingsRepository settingsRepository(SettingsRepositoryRef ref) {
  return SettingsRepositoryImpl(ref.watch(settingsLocalDataSourceProvider));
}

// --- Providers ---

@riverpod
class ThemeModeController extends _$ThemeModeController {
  @override
  Future<ThemeMode> build() async {
    final result = await ref.read(settingsRepositoryProvider).getThemeMode();
    return result.fold(
      (failure) => ThemeMode.system,
      (mode) => mode,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncData(mode); // Optimistic update
    await ref.read(settingsRepositoryProvider).setThemeMode(mode);
  }
}

@riverpod
class NotificationsController extends _$NotificationsController {
  @override
  Future<bool> build() async {
    final result = await ref.read(settingsRepositoryProvider).getNotificationsEnabled();
    return result.fold(
      (failure) => true,
      (enabled) => enabled,
    );
  }

  Future<void> toggle(bool enabled) async {
    state = AsyncData(enabled); // Optimistic update
    await ref.read(settingsRepositoryProvider).setNotificationsEnabled(enabled);
  }
}

@riverpod
class LanguageController extends _$LanguageController {
  @override
  Future<String> build() async {
    final result = await ref.read(settingsRepositoryProvider).getLanguage();
    return result.fold((l) => 'English', (r) => r);
  }

  Future<void> setLanguage(String language) async {
    state = AsyncData(language);
    await ref.read(settingsRepositoryProvider).setLanguage(language);
  }
}

@riverpod
class DataRefreshController extends _$DataRefreshController {
  @override
  Future<String> build() async {
    final result = await ref.read(settingsRepositoryProvider).getDataRefreshRate();
    return result.fold((l) => 'Auto', (r) => r);
  }

  Future<void> setRate(String rate) async {
    state = AsyncData(rate);
    await ref.read(settingsRepositoryProvider).setDataRefreshRate(rate);
  }
}

@riverpod
class NewsAlertsController extends _$NewsAlertsController {
  @override
  Future<bool> build() async {
    final result = await ref.read(settingsRepositoryProvider).getNewsAlertsEnabled();
    return result.fold((l) => true, (r) => r);
  }

  Future<void> toggle(bool enabled) async {
    state = AsyncData(enabled);
    await ref.read(settingsRepositoryProvider).setNewsAlertsEnabled(enabled);
  }
}

@riverpod
class AiInsightsController extends _$AiInsightsController {
  @override
  Future<bool> build() async {
    final result = await ref.read(settingsRepositoryProvider).getAiInsightsEnabled();
    return result.fold((l) => false, (r) => r);
  }

  Future<void> toggle(bool enabled) async {
    state = AsyncData(enabled);
    await ref.read(settingsRepositoryProvider).setAiInsightsEnabled(enabled);
  }
}
