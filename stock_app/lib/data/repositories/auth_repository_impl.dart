import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl(this._remoteDataSource);

  @override
  Stream<UserEntity?> get authStateChanges => _remoteDataSource.authStateChanges;

  @override
  UserEntity? get currentUser => _remoteDataSource.currentUser;

  @override
  Future<Either<Failure, UserEntity>> signIn(String email, String password) async {
    try {
      final user = await _remoteDataSource.signIn(email, password);
      return Right(user);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return const Left(ServerFailure('An unexpected error occurred'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signUp(String email, String password, String fullName) async {
    try {
      final user = await _remoteDataSource.signUp(email, password, fullName);
      return Right(user);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return const Left(ServerFailure('An unexpected error occurred'));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await _remoteDataSource.signOut();
      return const Right(null);
    } on Failure catch (e) {
      return Left(e);
    }
  }

  // The user's requested _mapFirebaseUser function is typically found in the AuthRemoteDataSource
  // where Firebase User objects are converted to UserEntity.
  // Placing it here as a private method of the repository, though less common,
  // makes the file syntactically correct as per the instruction.
  // Note: 'User' and 'UserRole' would need to be imported if this method were to be used here.
  // For now, it's just added as a placeholder method.
  // UserEntity _mapFirebaseUser(User user, [Map<String, dynamic>? userData]) {
  //   UserRole role = UserRole.user;
  //   if (userData != null && userData['role'] == 'admin') {
  //     role = UserRole.admin;
  //   }
  //   return UserEntity(
  //     id: user.uid,
  //     email: user.email ?? '',
  //     displayName: user.displayName,
  //     role: role,
  //   );
  // }

  @override
  Future<Either<Failure, void>> sendPasswordResetEmail(String email) async {
    try {
      await _remoteDataSource.sendPasswordResetEmail(email);
      return const Right(null);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return const Left(ServerFailure('An unexpected error occurred'));
    }
  }
}
