import 'package:flutter/material.dart';
import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_local_datasource.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDataSource _localDataSource;

  SettingsRepositoryImpl(this._localDataSource);

  @override
  Future<Either<Failure, ThemeMode>> getThemeMode() async {
    try {
      final mode = await _localDataSource.getThemeMode();
      return Right(mode);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setThemeMode(ThemeMode mode) async {
    try {
      await _localDataSource.setThemeMode(mode);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> getNotificationsEnabled() async {
    try {
      final enabled = await _localDataSource.getNotificationsEnabled();
      return Right(enabled);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setNotificationsEnabled(bool enabled) async {
    try {
      await _localDataSource.setNotificationsEnabled(enabled);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> getLanguage() async {
    try {
      final result = await _localDataSource.getLanguage();
      return Right(result);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setLanguage(String language) async {
    try {
      await _localDataSource.setLanguage(language);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> getDataRefreshRate() async {
    try {
      final result = await _localDataSource.getDataRefreshRate();
      return Right(result);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setDataRefreshRate(String rate) async {
    try {
      await _localDataSource.setDataRefreshRate(rate);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> getNewsAlertsEnabled() async {
    try {
      final result = await _localDataSource.getNewsAlertsEnabled();
      return Right(result);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setNewsAlertsEnabled(bool enabled) async {
    try {
      await _localDataSource.setNewsAlertsEnabled(enabled);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> getAiInsightsEnabled() async {
    try {
      final result = await _localDataSource.getAiInsightsEnabled();
      return Right(result);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setAiInsightsEnabled(bool enabled) async {
    try {
      await _localDataSource.setAiInsightsEnabled(enabled);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
