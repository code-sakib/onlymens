import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cleanmind/core/globals.dart';

class FeedbackService {
  static Future<void> sendFeedback({
    required String message,
    Uint8List? screenshot,
  }) async {
    final uid = auth.currentUser?.uid ?? 'anonymous';
    final email = auth.currentUser?.email;
    final username = auth.currentUser?.displayName ?? 'User';
    final timestamp = DateTime.now();

    String? screenshotUrl;

    // 1️⃣ Upload screenshot if available
    if (screenshot != null) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('feedback_screenshots')
          .child('$uid-${timestamp.millisecondsSinceEpoch}.png');
      await ref.putData(screenshot);
      screenshotUrl = await ref.getDownloadURL();
    }

    // 2️⃣ Store all feedback data in one collection
    await FirebaseFirestore.instance.collection('feedback_reports').add({
      'uid': uid,
      'email': email,
      'username': username,
      'message': message,
      'screenshotUrl': screenshotUrl,
      'platform': Platform.operatingSystem,
      'appVersion': '1.0.0',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
