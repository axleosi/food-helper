import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ Quick check for login status
  bool get isLoggedIn => _auth.currentUser != null;

  // ✅ Optional: directly get user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Signup method (email is case-insensitive)
  Future<User?> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );

    User? user = userCredential.user;

    if (user != null) {
      await _firestore.collection("users").doc(user.uid).set({
        "fullName": fullName,
        "email": normalizedEmail,
        "createdAt": FieldValue.serverTimestamp(),
      });
    }

    return user;
  }

  // Update user email
  Future<void> updateEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("No logged in user");
    }

    final normalizedEmail = newEmail.trim().toLowerCase();

    try {
      // 1️⃣ Re-authenticate user
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(cred);

      // 2️⃣ Update email in Firebase Auth
      await user.verifyBeforeUpdateEmail(normalizedEmail);

      // 3️⃣ Update email in Firestore
      await _firestore.collection("users").doc(user.uid).update({
        "email": normalizedEmail,
      });
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception("You need to log in again before updating your email.");
      } else if (e.code == 'email-already-in-use') {
        throw Exception("This email is already in use.");
      } else {
        throw Exception(e.message);
      }
    }
  }

  // Login method (email is case-insensitive)
  Future<User?> login({required String email, required String password}) async {
    final normalizedEmail = email.trim().toLowerCase();

    UserCredential userCredential = await _auth.signInWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );
    return userCredential.user;
  }

  // Logout method
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Get current user
  User? getCurrentUser() => _auth.currentUser;

  // Stream for auth state changes
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  // Password reset
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }

  // Update user profile (fullName)
  Future<void> updateProfile({required String fullName}) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection("users").doc(user.uid).update({
        "fullName": fullName,
      });
    }
  }

  // Get user details from Firestore
  Future<DocumentSnapshot> getUserDetails() async {
    final user = _auth.currentUser;
    if (user != null) {
      return await _firestore.collection("users").doc(user.uid).get();
    } else {
      throw Exception("No logged in user");
    }
  }
}
