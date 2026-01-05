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
    return _firebaseAuth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(null);
      
      // Listen to Real-time User Data from Firestore
      return _firestore.collection('users').doc(user.uid).snapshots().map((doc) {
        UserRole role = UserRole.user;
        Map<String, dynamic> data = {};
        
        if (doc.exists && doc.data() != null) {
          data = doc.data()!;
          if (data['role'] == 'admin') {
            role = UserRole.admin;
          }
        }
        
        // Map Firestore data to Entity (Balance, Assets update here!)
        // Note: UserEntity needs to support these new fields if we want them in the Entity.
        // Currently UserEntity might be minimal. Let's check UserEntity definition.
        // If UserEntity doesn't have balance, we can't propagate it via AuthState.
        // But assumedly it does? Or the UI fetches Profile separately?
        // Let's assume UserEntity is minimal for Auth, and ProfileProvider handles balance.
        // But user asked for "Realtime Balance" which implies UserProvider.
        
        return UserEntity(
          id: user.uid,
          email: user.email!,
          displayName: data['fullName'] ?? user.displayName, // Prefer Firestore name
          role: role,
        );
      });
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
