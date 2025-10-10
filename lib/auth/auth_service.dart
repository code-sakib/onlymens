import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Clean authentication service for production use
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthService._();

  /// Stream of authentication state changes
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Current authenticated user
  static User? get currentUser => _auth.currentUser;

  /// Check if user is currently signed in
  static bool get isSignedIn => _auth.currentUser != null;

  /// Get current user's UID
  static String? get currentUserId => _auth.currentUser?.uid;

  /// Get current user's email
  static String? get currentUserEmail => _auth.currentUser?.email;

  /// Get current user's phone number
  static String? get currentUserPhone => _auth.currentUser?.phoneNumber;

  /// Sign up with email and password
  /// Throws FirebaseAuthException with built-in error messages
  static Future<User> signUpWithEmail(String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return result.user!;
  }

  /// Sign in with email and password
  /// Throws FirebaseAuthException with built-in error messages
  static Future<User> signInWithEmail(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return result.user!;
  }

  /// Sign in with Google
  /// Throws FirebaseAuthException with built-in error messages
  static Future<User> signInWithGoogle() async {
    final gUser = await GoogleSignIn.instance.authenticate();

    final gAuth = gUser.authentication;
    final credential = GoogleAuthProvider.credential(idToken: gAuth.idToken);
    final result = await _auth.signInWithCredential(credential);
    return result.user!;
  }
}
