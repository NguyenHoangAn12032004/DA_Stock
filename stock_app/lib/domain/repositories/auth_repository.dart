import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Stream<UserEntity?> get authStateChanges;
  
  Future<Either<Failure, UserEntity>> signIn(String email, String password);
  
  Future<Either<Failure, UserEntity>> signUp(String email, String password, String fullName);
  
  Future<Either<Failure, void>> signOut();
  
  Future<Either<Failure, void>> sendPasswordResetEmail(String email);
  
  UserEntity? get currentUser;
}
