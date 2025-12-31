import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign Up
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      // 1. Create user in Firebase Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;

      if (user != null) {
        // 2. Update Display Name
        await user.updateDisplayName(fullName);

        // 3. Create User Document in Firestore (Virtual Wallet)
        // Sử dụng try-catch riêng cho Firestore để nếu lỗi DB thì vẫn cho đăng ký thành công
        try {
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': email,
            'fullName': fullName,
            'createdAt': FieldValue.serverTimestamp(),
            'balance': 100000000, // Tặng 100 triệu VNĐ tiền ảo
            'portfolio_value': 0,
            'total_assets': 100000000,
          });
        } catch (e) {
          print("⚠️ Lỗi tạo ví Firestore: $e");
          // Có thể bỏ qua hoặc xử lý sau, quan trọng là Auth đã thành công
        }
      }

      return result;
    } catch (e) {
      throw e;
    }
  }

  // Sign In
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw e;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
