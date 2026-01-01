import 'package:equatable/equatable.dart';

enum UserRole { user, admin }

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String? displayName;
  final UserRole role;

  const UserEntity({
    required this.id,
    required this.email,
    this.displayName,
    this.role = UserRole.user,
  });

  @override
  List<Object?> get props => [id, email, displayName, role];
}
