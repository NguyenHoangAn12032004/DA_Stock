import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/user_entity.dart';

abstract class AuthRemoteDataSource {
  Stream<UserEntity?> get authStateChanges;
  Future<UserEntity> signIn(String email, String password);
  Future<UserEntity> signUp(String email, String password, String fullName);
  Future<void> signOut();
  Future<void> sendPasswordResetEmail(String email);
  Future<void> saveFCMToken(String uid, String token);
  UserEntity? get currentUser;
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRemoteDataSourceImpl({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<UserEntity?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map((user) {
      if (user == null) return null;
      return UserEntity(
        id: user.uid,
        email: user.email!,
        displayName: user.displayName,
      );
    });
  }

  @override
  Future<UserEntity> signIn(String email, String password) async {
    try {
      final result = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = result.user!;
      return UserEntity(
        id: user.uid,
        email: user.email!,
        displayName: user.displayName,
      );
    } on FirebaseAuthException catch (e) {
      throw ServerFailure(e.message ?? 'Authentication failed');
    } catch (e) {
      throw const ServerFailure('An unknown error occurred');
    }
  }

  @override
  Future<UserEntity> signUp(String email, String password, String fullName) async {
    try {
      final result = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = result.user!;
      
      // Update display name
      await user.updateDisplayName(fullName);

      // Create Wallet in Firestore (Legacy Logic)
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'fullName': fullName,
        'createdAt': FieldValue.serverTimestamp(),
        'balance': 100000000, 
        'portfolio_value': 0,
        'total_assets': 100000000,
      });

      return UserEntity(
        id: user.uid,
        email: email,
        displayName: fullName,
      );
    } on FirebaseAuthException catch (e) {
      throw ServerFailure(e.message ?? 'Registration failed');
    } catch (e) {
      throw const ServerFailure('An unknown error occurred');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw const ServerFailure('Logout failed');
    }
  }
  
  @override
  UserEntity? get currentUser {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    return UserEntity(
      id: user.uid,
      email: user.email!,
      displayName: user.displayName,
    );
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw ServerFailure('Email not registered');
      } else if (e.code == 'invalid-email') {
        throw ServerFailure('Invalid email format');
      } else {
        throw ServerFailure(e.message ?? 'Failed to send reset email');
      }
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> saveFCMToken(String uid, String token) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'fcm_token': token,
        'fcm_updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error saving FCM Token: $e");
    }
  }
}
