import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AffirmationData {
  static const int MAX_AFFIRMATIONS = 3;

  /// Get current user's affirmations collection reference
  static CollectionReference _getUserAffirmationsRef() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('affirmations');
  }

  /// Fetch all affirmations for current user
  static Future<List<Map<String, dynamic>>> fetchAffirmations() async {
    try {
      final snapshot = await _getUserAffirmationsRef()
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Untitled',
          'subtitle': data['content'] ?? '',
          'createdAt': data['createdAt'],
          'isDefault': false, // User-created affirmations are never default
        };
      }).toList();
    } catch (e) {
      print('Error fetching affirmations: $e');
      return [];
    }
  }

  /// Add a new affirmation
  static Future<bool> addAffirmation(String title, String content) async {
    try {
      await _getUserAffirmationsRef().add({
        'title': title,
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error adding affirmation: $e');
      rethrow;
    }
  }

  /// Delete an affirmation
  static Future<bool> deleteAffirmation(String affirmationId) async {
    try {
      await _getUserAffirmationsRef().doc(affirmationId).delete();
      return true;
    } catch (e) {
      print('Error deleting affirmation: $e');
      rethrow;
    }
  }

  /// Generate affirmation using Cloud Function
  static Future<Map<String, dynamic>> generateAffirmationWithAI() async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('generateAffirmation');
      final result = await callable.call();

      return {
        'affirmation': result.data['affirmation'] ?? '',
        'remainingToday': result.data['remainingToday'] ?? 0,
      };
    } catch (e) {
      print('Error generating affirmation with AI: $e');
      
      // Handle specific Firebase errors
      if (e.toString().contains('resource-exhausted')) {
        throw Exception('Daily generation limit reached (3/day). Try tomorrow!');
      }
      
      rethrow;
    }
  }

  /// Get remaining generations for today (from Cloud Function)
  static Future<int> getRemainingGenerations() async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('checkAffirmationLimit');
      final result = await callable.call();

      return result.data['remainingToday'] ?? 0;
    } catch (e) {
      print('Error getting remaining generations: $e');
      return 0;
    }
  }
}