import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/errors/failures.dart';
import '../../core/services/notification_service.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/password_reset_usecase.dart';
import '../../domain/usecases/register_usecase.dart';

part 'auth_provider.g.dart';

// --- Dependency Injection via Riverpod ---

@riverpod
AuthRemoteDataSource authRemoteDataSource(AuthRemoteDataSourceRef ref) {
  return AuthRemoteDataSourceImpl();
}

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider));
}

@riverpod
LoginUseCase loginUseCase(LoginUseCaseRef ref) {
  return LoginUseCase(ref.watch(authRepositoryProvider));
}

@riverpod
RegisterUseCase registerUseCase(RegisterUseCaseRef ref) {
  return RegisterUseCase(ref.watch(authRepositoryProvider));
}

@riverpod
LogoutUseCase logoutUseCase(LogoutUseCaseRef ref) {
  return LogoutUseCase(ref.watch(authRepositoryProvider));
}

@riverpod
PasswordResetUseCase passwordResetUseCase(PasswordResetUseCaseRef ref) {
  return PasswordResetUseCase(ref.watch(authRepositoryProvider));
}

@riverpod
Stream<UserEntity?> authStateChanges(AuthStateChangesRef ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
}

// --- Auth Controller / Notifier ---

@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<UserEntity?> build() async {
    final user = await ref.watch(authRepositoryProvider).currentUser;
    if (user != null) {
      // Background sync of FCM token to ensure it's up to date
      _syncFCMToken(user.id);
    }
    return user;
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    final result = await ref.read(loginUseCaseProvider).call(email, password);
    result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
      },
      (user) {
        state = AsyncData(user);
        _syncFCMToken(user.id);
      },
    );
  }

  Future<void> signUp(String email, String password, String fullName) async {
    state = const AsyncLoading();
    final result = await ref.read(registerUseCaseProvider).call(email, password, fullName);
    result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
      },
      (user) {
        state = AsyncData(user);
        _syncFCMToken(user.id);
      },
    );
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    final result = await ref.read(logoutUseCaseProvider).call();
    result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
      },
      (success) {
        state = const AsyncData(null);
      },
    );
  }
  Future<void> resetPassword(String email) async {
    state = const AsyncLoading();
    final result = await ref.read(passwordResetUseCaseProvider)(email);
    result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
      },
      (success) { // Use 'success' not 'r'
        state = const AsyncData(null);
      },
    );
  }

  // Helper to sync FCM Token
  Future<void> _syncFCMToken(String uid) async {
    try {
      final token = await NotificationService().fcmToken; 
      // Note: In real app, we should use a repository.
      // Here we cheat slightly by accessing DataSource directly via ref or direct firestore, 
      // but let's stick to using the method we just added to the DataSource, 
      // accessible via the repository provider? No, Repo doesn't have it.
      // Let's just use the DataSource provider directly for this tech-debt shortcut.
      if (token != null) {
        await ref.read(authRemoteDataSourceProvider).saveFCMToken(uid, token);
      }
    } catch (e) {
      print("FCM Sync Error: $e");
    }
  }
}
