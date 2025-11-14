// migration_helper.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MigrationHelper {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Merge local prefs into user doc
  static Future<void> migrateLocalToUser({
    required String uid,
    Map<String, dynamic>? localData,
  }) async {
    final ref = _db.collection('users').doc(uid);

    final Map<String, dynamic> toWrite = {};
    if (localData != null && localData.isNotEmpty) {
      toWrite.addAll(localData);
    }

    // Example: read local onboarding/obSelected values from prefs if you used them
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done');
    if (onboardingDone != null) toWrite['onboarding_done'] = onboardingDone;

    // Add device id mapping or other metadata
    toWrite['migratedAt'] = FieldValue.serverTimestamp();

    if (toWrite.isNotEmpty) {
      await ref.set(toWrite, SetOptions(merge: true));
    }
  }
}
