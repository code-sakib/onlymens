// auth_service.dart
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AuthService {
  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseFirestore db = FirebaseFirestore.instance;

  static User? get currentUser => auth.currentUser;

  /// ----------------------
  /// Google Sign-In
  /// ----------------------
  static Future<User?> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn.instance;
    final googleUser = await googleSignIn.authenticate();

    // In your google_sign_in variant `authentication` is synchronous / non-Future.
    final gAuth = googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: gAuth.idToken,
      accessToken: gAuth.idToken, // kept exactly as your original flow
    );
    final userCred = await auth.signInWithCredential(credential);
    await _ensureUserDoc(userCred.user);
    return userCred.user;
  }

  /// ----------------------
  /// Apple Sign-In
  /// ----------------------
  static Future<User?> signInWithApple() async {
    final appleCred = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final oauth = OAuthProvider("apple.com").credential(
      idToken: appleCred.identityToken,
      accessToken: appleCred.authorizationCode,
    );

    final userCred = await auth.signInWithCredential(oauth);
    await _ensureUserDoc(userCred.user);

    return userCred.user;
  }

  /// ----------------------
  /// Ensure user document
  /// ----------------------
  static Future<void> _ensureUserDoc(User? user) async {
    if (user == null) return;

    final ref = db.collection('users').doc(user.uid);

    await ref.set({
      'email': user.email,
      'name': user.displayName,
      'lastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// ----------------------
  /// Fetch subscription
  /// ----------------------
  static Future<Map<String, dynamic>?> fetchSubscriptionForCurrentUser() async {
    final user = currentUser;
    if (user == null) return null;

    final snap = await db.collection('users').doc(user.uid).get();
    final d = snap.data();
    return d?['subscription'];
  }

  /// ----------------------
  /// Validate + attach receipt
  /// ----------------------
  static Future<bool> claimReceiptForCurrentUser({
    required String receiptData,
    required String productId,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) return false;

    final callable = FirebaseFunctions.instance.httpsCallable(
      'validateAppleReceipt',
    );

    final result = await callable.call({
      'receiptData': receiptData,
      'productId': productId,
      'userId': uid,
    });

    return result.data['isValid'] == true;
  }

  /// ----------------------
  /// Re-authenticate before deleting account
  /// ----------------------
  static Future<bool> reauthenticateBeforeDelete() async {
    final user = auth.currentUser;
    if (user == null) return false;

    final provider = user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : null;

    try {
      // ----------------------
      // GOOGLE re-auth
      // ----------------------
      if (provider == 'google.com') {
        final GoogleSignIn googleSignIn = GoogleSignIn.instance;

        // Keep your original authenticate() flow (no null-check here; authenticate() doesn't return null).
        final googleUser = await googleSignIn.authenticate();

        // authentication is synchronous in your google_sign_in version.
        final gAuth = googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          idToken: gAuth.idToken,
          accessToken: gAuth.idToken, // preserved as in your original code
        );

        await user.reauthenticateWithCredential(credential);
        return true;
      }

      // ----------------------
      // APPLE re-auth
      // ----------------------
      if (provider == 'apple.com') {
        final appleCred = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );

        final oauth = OAuthProvider("apple.com").credential(
          idToken: appleCred.identityToken,
          accessToken: appleCred.authorizationCode,
        );

        await user.reauthenticateWithCredential(oauth);
        return true;
      }
    } catch (e, st) {
      developer.log("❌ Re-auth error: $e", stackTrace: st);
      return false;
    }

    return false;
  }

  /// ----------------------
  /// Full delete: Firestore + Auth
  /// ----------------------
  static Future<bool> deleteAccountCompletely() async {
    final user = auth.currentUser;
    if (user == null) return false;

    try {
      // Delete Firestore doc
      await db.collection('users').doc(user.uid).delete();

      // Re-auth before deleting
      final ok = await reauthenticateBeforeDelete();
      if (!ok) return false;

      // Delete auth user
      await user.delete();

      return true;
    } catch (e, st) {
      developer.log("❌ Delete account error: $e", stackTrace: st);
      return false;
    }
  }
}
