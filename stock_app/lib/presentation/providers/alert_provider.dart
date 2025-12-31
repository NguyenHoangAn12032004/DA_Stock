import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/network/dio_client.dart';
import '../../data/datasources/alert_remote_datasource.dart';
import '../../data/repositories/alert_repository_impl.dart';
import '../../domain/entities/alert_entity.dart';
import '../../domain/repositories/alert_repository.dart';
import '../../domain/usecases/alert_usecases.dart';
import '../../domain/usecases/update_alert_usecase.dart';
import 'auth_provider.dart';

part 'alert_provider.g.dart';

// --- Dependencies ---

@riverpod
AlertRemoteDataSource alertRemoteDataSource(AlertRemoteDataSourceRef ref) {
  return AlertRemoteDataSourceImpl(DioClient.instance);
}

@riverpod
AlertRepository alertRepository(AlertRepositoryRef ref) {
  return AlertRepositoryImpl(ref.watch(alertRemoteDataSourceProvider));
}

@riverpod
CreateAlertUseCase createAlertUseCase(CreateAlertUseCaseRef ref) {
  return CreateAlertUseCase(ref.watch(alertRepositoryProvider));
}

@riverpod
GetAlertsUseCase getAlertsUseCase(GetAlertsUseCaseRef ref) {
  return GetAlertsUseCase(ref.watch(alertRepositoryProvider));
}

@riverpod
DeleteAlertUseCase deleteAlertUseCase(DeleteAlertUseCaseRef ref) {
  return DeleteAlertUseCase(ref.watch(alertRepositoryProvider));
}

@riverpod
UpdateAlertUseCase updateAlertUseCase(UpdateAlertUseCaseRef ref) {
  return UpdateAlertUseCase(ref.watch(alertRepositoryProvider));
}

// --- Controller ---

@riverpod
class AlertController extends _$AlertController {
  @override
  FutureOr<List<AlertEntity>> build() async {
    final user = await ref.watch(authRepositoryProvider).currentUser;
    if (user != null) {
      return _fetchAlerts(user.id);
    }
    return [];
  }

  Future<List<AlertEntity>> _fetchAlerts(String userId) async {
    final result = await ref.read(getAlertsUseCaseProvider)(userId);
    return result.fold(
      (l) => [], 
      (r) => r
    );
  }

  Future<void> createAlert(String symbol, double value, String condition) async {
     final user = await ref.read(authRepositoryProvider).currentUser;
     if (user == null) return;

     state = const AsyncLoading();
     
     final alert = AlertEntity(
       id: '', 
       userId: user.id,
       symbol: symbol,
       value: value,
       condition: condition,
       createdAt: 0, 
     );

     final result = await ref.read(createAlertUseCaseProvider)(alert);
     
     result.fold(
       (l) => state = AsyncError(l.message, StackTrace.current),
       (r) {
         ref.invalidateSelf();
       }
     );
  }

  Future<void> deleteAlert(String alertId) async {
    final user = await ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    
    state = const AsyncLoading();
    final result = await ref.read(deleteAlertUseCaseProvider)(user.id, alertId);
    
    result.fold(
      (l) => state = AsyncError(l.message, StackTrace.current),
      (r) => ref.invalidateSelf()
    );
  }

  Future<void> toggleAlert(String alertId, bool isActive) async {
    final user = await ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;

    final previousState = state;
    if (previousState.hasValue) {
       final alerts = previousState.value!;
       final updatedAlerts = alerts.map((a) => a.id == alertId ? a.copyWith(isActive: isActive) : a).toList();
       state = AsyncData(updatedAlerts);
    }

    final result = await ref.read(updateAlertUseCaseProvider)(user.id, alertId, isActive);

    result.fold(
      (l) {
         // Revert on failure
         state = previousState;
         // Optionally show error via a separate provider or snackbar controller
         print("Toggle Alert Failed: ${l.message}");
      },
      (r) {
        // Success: Already optimistic updated.
      }
    );
  }
}

