import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';
import '../repositories/auth_repository.dart';

class PasswordResetUseCase {
  final AuthRepository _repository;

  PasswordResetUseCase(this._repository);

  Future<Either<Failure, void>> call(String email) async {
    return _repository.sendPasswordResetEmail(email);
  }
}
