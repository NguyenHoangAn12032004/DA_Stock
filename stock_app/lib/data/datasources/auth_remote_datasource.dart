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
    return _firebaseAuth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      
      // Fetch Role from Firestore
      UserRole role = UserRole.user;
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (data['role'] == 'admin') {
            role = UserRole.admin;
          }
        }
      } catch (e) {
        print("Error fetching user role: $e");
      }

      return UserEntity(
        id: user.uid,
        email: user.email!,
        displayName: user.displayName,
        role: role,
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
      
      // Fetch Role
      UserRole role = UserRole.user;
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
         if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (data['role'] == 'admin') {
            role = UserRole.admin;
          }
        }
      } catch (e) { 
         // Ignore role fetch error, default to user
      }

      return UserEntity(
        id: user.uid,
        email: user.email!,
        displayName: user.displayName,
        role: role,
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

      // Create Wallet in Firestore with default role 'user'
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'fullName': fullName,
        'role': 'user', // Default role
        'createdAt': FieldValue.serverTimestamp(),
        'balance': 100000000, 
        'portfolio_value': 0,
        'total_assets': 100000000,
      });

      return UserEntity(
        id: user.uid,
        email: email,
        displayName: fullName,
        role: UserRole.user,
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
    
    // NOTE: currentUser is synchronous, so we cannot await Firestore here.
    // It will return UserRole.user by default until authStateChanges updates it.
    // This is a known limitation of having synchronous getter for Async data.
    // The App should rely on authStateChanges (Stream) for accurate Role.
    return UserEntity(
      id: user.uid,
      email: user.email!,
      displayName: user.displayName,
      role: UserRole.user, // Default, will update via Listeners
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
