import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository _repository;

  RegisterUseCase(this._repository);

  Future<Either<Failure, UserEntity>> call(String email, String password, String fullName) async {
    return await _repository.signUp(email, password, fullName);
  }
}
