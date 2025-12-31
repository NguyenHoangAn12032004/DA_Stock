import 'package:flutter/material.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';

abstract class SettingsRepository {
  Future<Either<Failure, ThemeMode>> getThemeMode();
  Future<Either<Failure, void>> setThemeMode(ThemeMode mode);

  Future<Either<Failure, bool>> getNotificationsEnabled();
  Future<Either<Failure, void>> setNotificationsEnabled(bool enabled);

  Future<Either<Failure, String>> getLanguage();
  Future<Either<Failure, void>> setLanguage(String language);

  Future<Either<Failure, String>> getDataRefreshRate();
  Future<Either<Failure, void>> setDataRefreshRate(String rate);

  Future<Either<Failure, bool>> getNewsAlertsEnabled();
  Future<Either<Failure, void>> setNewsAlertsEnabled(bool enabled);

  Future<Either<Failure, bool>> getAiInsightsEnabled();
  Future<Either<Failure, void>> setAiInsightsEnabled(bool enabled);
}
