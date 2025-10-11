import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:onlymens/core/globals.dart';
import 'package:onlymens/features/onboarding_pgs/onboarding_pgs.dart';

/// Clean authentication service for production use
class AuthService {
  AuthService._();

  /// Stream of authentication state changes
  static Stream<User?> get authStateChanges => auth.authStateChanges();

  /// Current authenticated user
  static User? get currentUser => auth.currentUser;

  /// Check if user is currently signed in
  static bool get isSignedIn => auth.currentUser != null;

  /// Get current user's UID
  static String? get currentUserId => auth.currentUser?.uid;

  /// Get current user's email
  static String? get currentUserEmail => auth.currentUser?.email;

  /// Get current user's phone number
  static String? get currentUserPhone => auth.currentUser?.phoneNumber;

  /// Sign up with email and password
  /// Throws FirebaseAuthException with built-in error messages
  static Future<void> signUpWithEmail(String email, String password) async {
    auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sign in with email and password
  /// Throws FirebaseAuthException with built-in error messages
  static Future<User> signInWithEmail(String email, String password) async {
    final result = await auth
        .signInWithEmailAndPassword(email: email.trim(), password: password)
        .then((_) async {
          await cloudDB.collection('users').doc('fj').set({
            '1': 1,
          }, SetOptions(merge: true));
        });
    return result.user!;
  }

  /// Sign in with Google
  /// Throws FirebaseAuthException with built-in error messages
  static Future<User> signInWithGoogle() async {
    final gUser = await GoogleSignIn.instance.authenticate().then((_) async {
      await cloudDB
          .collection('users')
          .doc(auth.currentUser!.uid)
          .set({'obvalues': obSelectedValues}, SetOptions(merge: true))
          .onError((error, stackTrace) {
            print('Error onboarding user: $error');
          });
    });

    final gAuth = gUser.authentication;
    final credential = GoogleAuthProvider.credential(idToken: gAuth.idToken);
    final result = await auth.signInWithCredential(credential);
    return result.user!;
  }
}
