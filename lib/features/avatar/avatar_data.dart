import 'package:cloud_firestore/cloud_firestore.dart';

/// Simplified Avatar Manager - All models bundled in assets
class AvatarManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // All avatar models bundled in assets
  static const String LEVEL_1_PATH = 'assets/3d/av_lv1_comp.glb';
  static const String LEVEL_2_PATH = 'assets/3d/av_lv2_comp.glb';
  static const String LEVEL_3_PATH = 'assets/3d/av_lv3_comp.glb';
  static const String LEVEL_4_PATH = 'assets/3d/av_lv4_comp.glb';

  static const Map<int, String> LEVEL_PATHS = {
    1: LEVEL_1_PATH,
    2: LEVEL_2_PATH,
    3: LEVEL_3_PATH,
    4: LEVEL_4_PATH,
  };

  // ============================================================
  // PUBLIC API
  // ============================================================

  /// Main check: Called after StreaksData.fetchData()
  /// Returns current avatar info and updates if needed
  static Future<AvatarCheckResult> checkAndUpdateModelAfterFetch({
    required String uid,
    required int currentStreakDays,
  }) async {
    try {
      print('🎭 Avatar Check: uid=$uid, days=$currentStreakDays');

      final String currentMonth = _getCurrentMonth();
      final int requiredLevel = getLevelFromDays(currentStreakDays);

      // Get current model data from Firestore
      final modelDoc = await _getModelDoc(uid, currentMonth);
      final Map<String, dynamic>? modelData =
          modelDoc.data() as Map<String, dynamic>?;

      // First time setup
      if (modelData == null) {
        await _initializeModelForMonth(uid, currentMonth);
        return AvatarCheckResult(
          success: true,
          currentLevel: 1,
          currentPath: LEVEL_1_PATH,
          wasUpdated: false,
          message: 'Avatar system initialized',
        );
      }

      final int currentLevel = modelData['current_level'] ?? 1;

      print('📊 Current: Level $currentLevel | Required: Level $requiredLevel');

      // Check if level changed (upgrade or downgrade)
      if (requiredLevel != currentLevel) {
        print('🔄 Updating from Level $currentLevel to Level $requiredLevel');

        // Update Firestore
        await _updateFirestoreLevel(uid, currentMonth, requiredLevel);

        final newPath = LEVEL_PATHS[requiredLevel] ?? LEVEL_1_PATH;
        return AvatarCheckResult(
          success: true,
          currentLevel: requiredLevel,
          currentPath: newPath,
          wasUpdated: true,
          message: requiredLevel > currentLevel
              ? '🎉 Unlocked Level $requiredLevel Avatar!'
              : 'Avatar updated to Level $requiredLevel',
        );
      }

      // No update needed - return current state
      final currentPath = LEVEL_PATHS[currentLevel] ?? LEVEL_1_PATH;

      return AvatarCheckResult(
        success: true,
        currentLevel: currentLevel,
        currentPath: currentPath,
        wasUpdated: false,
      );
    } catch (e) {
      print('❌ Avatar check error: $e');
      return AvatarCheckResult(
        success: false,
        currentLevel: 1,
        currentPath: LEVEL_1_PATH,
        wasUpdated: false,
        error: e.toString(),
      );
    }
  }

  /// Called when user updates streak (Done/Skip/Relapse)
  /// Returns whether model needs update
  static Future<ModelUpdateStatus> checkIfUpdateNeeded({
    required String uid,
    required int newStreakDays,
  }) async {
    try {
      final String currentMonth = _getCurrentMonth();
      final int requiredLevel = getLevelFromDays(newStreakDays);

      final modelDoc = await _getModelDoc(uid, currentMonth);
      final Map<String, dynamic>? modelData =
          modelDoc.data() as Map<String, dynamic>?;

      if (modelData == null) {
        return ModelUpdateStatus(
          needsUpdate: false,
          currentLevel: 1,
          requiredLevel: 1,
        );
      }

      final int currentLevel = modelData['current_level'] ?? 1;

      return ModelUpdateStatus(
        needsUpdate: requiredLevel != currentLevel,
        currentLevel: currentLevel,
        requiredLevel: requiredLevel,
        isUpgrade: requiredLevel > currentLevel,
      );
    } catch (e) {
      print('❌ Update check error: $e');
      return ModelUpdateStatus(
        needsUpdate: false,
        currentLevel: 1,
        requiredLevel: 1,
      );
    }
  }

  /// User updates avatar level (instant - no downloads)
  static Future<AvatarUpdateResult> updateModelNow({
    required String uid,
    required int streakDays,
  }) async {
    try {
      final String currentMonth = _getCurrentMonth();
      final int requiredLevel = getLevelFromDays(streakDays);

      // Update Firestore
      await _updateFirestoreLevel(uid, currentMonth, requiredLevel);

      final newPath = LEVEL_PATHS[requiredLevel] ?? LEVEL_1_PATH;

      return AvatarUpdateResult(
        success: true,
        level: requiredLevel,
        path: newPath,
        message: '🎉 Avatar upgraded to Level $requiredLevel!',
      );
    } catch (e) {
      print('❌ Update now error: $e');
      return AvatarUpdateResult(
        success: false,
        level: 1,
        path: LEVEL_1_PATH,
        error: e.toString(),
      );
    }
  }

  /// Get current avatar path for display
  static Future<String> getCurrentAvatarPath(String uid) async {
    try {
      final String currentMonth = _getCurrentMonth();
      final modelDoc = await _getModelDoc(uid, currentMonth);
      final Map<String, dynamic>? modelData =
          modelDoc.data() as Map<String, dynamic>?;

      if (modelData == null) {
        return LEVEL_1_PATH;
      }

      final int currentLevel = modelData['current_level'] ?? 1;
      return LEVEL_PATHS[currentLevel] ?? LEVEL_1_PATH;
    } catch (e) {
      print('❌ Get path error: $e');
      return LEVEL_1_PATH;
    }
  }

  /// Get level from streak days
  static int getLevelFromDays(int streakDays) {
    if (streakDays < 8) return 1;
    if (streakDays < 15) return 2;
    if (streakDays < 23) return 3;
    return 4;
  }

  // ============================================================
  // PRIVATE HELPERS
  // ============================================================

  static DocumentReference _getModelDocRef(String uid, String month) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('models')
        .doc(month);
  }

  static Future<DocumentSnapshot> _getModelDoc(String uid, String month) {
    return _getModelDocRef(uid, month).get();
  }

  static String _getCurrentMonth() {
    final now = DateTime.now();
    const months = [
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'october',
      'november',
      'december',
    ];
    return '${months[now.month - 1]}-${now.year}';
  }

  /// Initialize model document for new month
  static Future<void> _initializeModelForMonth(String uid, String month) async {
    final docRef = _getModelDocRef(uid, month);

    await docRef.set({
      'current_level': 1,
      'last_updated': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
    });

    print('✅ Initialized model document for $month');
  }

  /// Update Firestore level
  static Future<void> _updateFirestoreLevel(
    String uid,
    String month,
    int level,
  ) async {
    final docRef = _getModelDocRef(uid, month);

    await docRef.set({
      'current_level': level,
      'last_updated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print('✅ Updated level to $level');
  }

  // ============================================================
  // DEBUG & UTILITY
  // ============================================================

  /// Get storage info for debugging
  static Future<Map<String, dynamic>> getStorageInfo(String uid) async {
    try {
      final String currentMonth = _getCurrentMonth();
      final modelDoc = await _getModelDoc(uid, currentMonth);
      final Map<String, dynamic>? modelData =
          modelDoc.data() as Map<String, dynamic>?;

      return {
        'current_month': currentMonth,
        'current_level': modelData?['current_level'] ?? 1,
        'last_updated': modelData?['last_updated'],
        'storage_type': 'bundled_assets',
        'available_levels': LEVEL_PATHS.keys.toList(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Reset for testing
  static Future<void> resetForTesting(String uid) async {
    try {
      final String currentMonth = _getCurrentMonth();

      // Delete Firestore doc
      await _getModelDocRef(uid, currentMonth).delete();

      print('🔄 Reset complete');
    } catch (e) {
      print('❌ Reset error: $e');
    }
  }
}

// ============================================================
// RESULT CLASSES
// ============================================================

class AvatarCheckResult {
  final bool success;
  final int currentLevel;
  final String currentPath;
  final bool wasUpdated;
  final String? message;
  final String? error;

  AvatarCheckResult({
    required this.success,
    required this.currentLevel,
    required this.currentPath,
    required this.wasUpdated,
    this.message,
    this.error,
  });
}

class AvatarUpdateResult {
  final bool success;
  final int level;
  final String path;
  final String? message;
  final String? error;

  AvatarUpdateResult({
    required this.success,
    required this.level,
    required this.path,
    this.message,
    this.error,
  });
}

class ModelUpdateStatus {
  final bool needsUpdate;
  final int currentLevel;
  final int requiredLevel;
  final bool isUpgrade;

  ModelUpdateStatus({
    required this.needsUpdate,
    required this.currentLevel,
    required this.requiredLevel,
    this.isUpgrade = true,
  });
}
