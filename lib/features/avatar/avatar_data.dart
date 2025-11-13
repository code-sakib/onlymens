import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Cloud-first Avatar Manager with compressed models (3MB each)
/// Only Level 1 is bundled, Levels 2-4 are fetched from Firebase Storage
class AvatarManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final Dio _dio = Dio();

  // Configuration
  static const int MAX_DOWNLOADS_PER_DAY = 4;
  static const String BUNDLED_LEVEL_1 = 'assets/3d/av_lv1_comp.glb';

  // Cache to prevent repeated download limit messages
  static DateTime? _lastDownloadLimitShown;
  static const Duration _downloadLimitCooldown = Duration(hours: 1);

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
          currentPath: BUNDLED_LEVEL_1,
          wasUpdated: false,
          message: 'Avatar system initialized',
        );
      }

      final int currentLevel = modelData['current_level'] ?? 1;
      final bool hasPendingUpdate = modelData['pending_update'] ?? false;

      print(
        '📊 Current: Level $currentLevel | Required: Level $requiredLevel | Pending: $hasPendingUpdate',
      );

      // Check if we need to DOWNGRADE (streak decreased)
      if (requiredLevel < currentLevel) {
        print('📉 Downgrading from Level $currentLevel to Level $requiredLevel');
        
        // Delete higher level files
        for (int level = currentLevel; level > requiredLevel; level--) {
          await _deleteLevel(level);
        }

        // Update Firestore
        await _updateFirestoreLevel(uid, currentMonth, requiredLevel, clearPending: true);

        final downgradePath = await _getAvatarPath(requiredLevel);
        return AvatarCheckResult(
          success: true,
          currentLevel: requiredLevel,
          currentPath: downgradePath,
          wasUpdated: true,
          message: 'Avatar updated to Level $requiredLevel',
        );
      }

      // Check if update is needed (upgrade or pending)
      if (requiredLevel > currentLevel || hasPendingUpdate) {
        final targetLevel = requiredLevel > currentLevel ? requiredLevel : currentLevel;
        
        // Check download limit
        final limitCheck = await _checkDownloadLimit(uid, currentMonth, modelData);
        
        if (!limitCheck.canDownload) {
          // Only show message if cooldown has passed
          final shouldShowMessage = _shouldShowDownloadLimitMessage();
          
          return AvatarCheckResult(
            success: false,
            currentLevel: currentLevel,
            currentPath: await _getAvatarPath(currentLevel),
            wasUpdated: false,
            error: shouldShowMessage ? 'Download limit exceeded (3/day). Try tomorrow!' : null,
            downloadLimitExceeded: true,
            showLimitMessage: shouldShowMessage,
            downloadsToday: limitCheck.downloadsToday,
            lastDownloadDate: limitCheck.lastDownloadDate,
          );
        }

        // Perform update
        final String newPath = await _downloadAndUpdateModel(
          uid: uid,
          currentMonth: currentMonth,
          oldLevel: currentLevel,
          newLevel: targetLevel,
        );

        // Verify the downloaded file exists and is valid
        final bool fileValid = await _verifyModelFile(newPath);
        
        if (!fileValid && targetLevel > 1) {
          print('⚠️ Downloaded file invalid, falling back to level 1');
          return AvatarCheckResult(
            success: false,
            currentLevel: 1,
            currentPath: BUNDLED_LEVEL_1,
            wasUpdated: false,
            error: 'Failed to load Level $targetLevel model',
          );
        }

        return AvatarCheckResult(
          success: true,
          currentLevel: targetLevel,
          currentPath: newPath,
          wasUpdated: true,
          message: '🎉 Unlocked Level $targetLevel Avatar!',
        );
      }

      // No update needed - return current state
      final currentPath = await _getAvatarPath(currentLevel);
      
      // Verify current file exists
      if (currentLevel > 1) {
        final fileValid = await _verifyModelFile(currentPath);
        if (!fileValid) {
          print('⚠️ Current level file missing, falling back to level 1');
          await _updateFirestoreLevel(uid, currentMonth, 1);
          return AvatarCheckResult(
            success: true,
            currentLevel: 1,
            currentPath: BUNDLED_LEVEL_1,
            wasUpdated: false,
          );
        }
      }

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
        currentPath: BUNDLED_LEVEL_1,
        wasUpdated: false,
        error: e.toString(),
      );
    }
  }

  /// Called when user updates streak (Done/Skip/Relapse)
  /// Returns whether model needs update (show "Update Later" option)
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
      final limitCheck = await _checkDownloadLimit(uid, currentMonth, modelData);

      return ModelUpdateStatus(
        needsUpdate: requiredLevel != currentLevel,
        currentLevel: currentLevel,
        requiredLevel: requiredLevel,
        canDownloadNow: limitCheck.canDownload,
        isUpgrade: requiredLevel > currentLevel,
        downloadsToday: limitCheck.downloadsToday,
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

  /// User chooses "Update Now" from UI
  static Future<AvatarUpdateResult> updateModelNow({
    required String uid,
    required int streakDays,
  }) async {
    try {
      final String currentMonth = _getCurrentMonth();
      final int requiredLevel = getLevelFromDays(streakDays);

      final modelDoc = await _getModelDoc(uid, currentMonth);
      final Map<String, dynamic>? modelData =
          modelDoc.data() as Map<String, dynamic>?;
      final int currentLevel = modelData?['current_level'] ?? 1;

      // Handle downgrade (no download needed)
      if (requiredLevel < currentLevel) {
        for (int level = currentLevel; level > requiredLevel; level--) {
          await _deleteLevel(level);
        }
        await _updateFirestoreLevel(uid, currentMonth, requiredLevel, clearPending: true);
        
        return AvatarUpdateResult(
          success: true,
          level: requiredLevel,
          path: await _getAvatarPath(requiredLevel),
          message: 'Avatar updated to Level $requiredLevel',
        );
      }

      // Handle upgrade (download needed)
      final limitCheck = await _checkDownloadLimit(uid, currentMonth, modelData ?? {});

      if (!limitCheck.canDownload) {
        return AvatarUpdateResult(
          success: false,
          level: currentLevel,
          path: await _getAvatarPath(currentLevel),
          error: 'Download limit reached (3/day)',
          downloadLimitExceeded: true,
          downloadsToday: limitCheck.downloadsToday,
        );
      }

      // Download and update
      final String newPath = await _downloadAndUpdateModel(
        uid: uid,
        currentMonth: currentMonth,
        oldLevel: currentLevel,
        newLevel: requiredLevel,
      );

      // Verify downloaded file
      final bool fileValid = await _verifyModelFile(newPath);
      
      if (!fileValid && requiredLevel > 1) {
        return AvatarUpdateResult(
          success: false,
          level: currentLevel,
          path: await _getAvatarPath(currentLevel),
          error: 'Failed to download avatar. Please try again.',
        );
      }

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
        path: BUNDLED_LEVEL_1,
        error: e.toString(),
      );
    }
  }

  /// User chooses "Update Later"
  static Future<void> markPendingUpdate({required String uid}) async {
    try {
      final String currentMonth = _getCurrentMonth();
      final docRef = _getModelDocRef(uid, currentMonth);

      await docRef.update({
        'pending_update': true,
        'pending_since': FieldValue.serverTimestamp(),
      });

      print('✅ Marked pending update for later');
    } catch (e) {
      print('❌ Mark pending error: $e');
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
        return BUNDLED_LEVEL_1;
      }

      final int currentLevel = modelData['current_level'] ?? 1;
      final path = await _getAvatarPath(currentLevel);
      
      // Verify file exists
      if (currentLevel > 1) {
        final valid = await _verifyModelFile(path);
        if (!valid) {
          return BUNDLED_LEVEL_1;
        }
      }
      
      return path;
    } catch (e) {
      print('❌ Get path error: $e');
      return BUNDLED_LEVEL_1;
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

  /// Check if we should show download limit message (cooldown logic)
  static bool _shouldShowDownloadLimitMessage() {
    if (_lastDownloadLimitShown == null) {
      _lastDownloadLimitShown = DateTime.now();
      return true;
    }

    final timeSinceLastShown = DateTime.now().difference(_lastDownloadLimitShown!);
    if (timeSinceLastShown > _downloadLimitCooldown) {
      _lastDownloadLimitShown = DateTime.now();
      return true;
    }

    return false;
  }

  /// Initialize model document for new month
  static Future<void> _initializeModelForMonth(String uid, String month) async {
    final docRef = _getModelDocRef(uid, month);

    await docRef.set({
      'current_level': 1,
      'current_model': 'av_lv1_comp.glb',
      'last_updated': FieldValue.serverTimestamp(),
      'downloads_today': 0,
      'last_download_date': null,
      'pending_update': false,
      'created_at': FieldValue.serverTimestamp(),
    });

    print('✅ Initialized model document for $month');
  }

  /// Check if user can download (under limit)
  static Future<DownloadLimitCheck> _checkDownloadLimit(
    String uid,
    String month,
    Map<String, dynamic> modelData,
  ) async {
    final int downloadsToday = modelData['downloads_today'] ?? 0;
    final String? lastDownloadDate = modelData['last_download_date'];
    final String today = _getTodayString();

    // Reset counter if new day
    if (lastDownloadDate != today) {
      return DownloadLimitCheck(
        canDownload: true,
        downloadsToday: 0,
        lastDownloadDate: today,
      );
    }

    // Check limit
    if (downloadsToday >= MAX_DOWNLOADS_PER_DAY) {
      print(
        '⛔ Download limit exceeded: $downloadsToday/$MAX_DOWNLOADS_PER_DAY',
      );
      return DownloadLimitCheck(
        canDownload: false,
        downloadsToday: downloadsToday,
        lastDownloadDate: lastDownloadDate,
      );
    }

    return DownloadLimitCheck(
      canDownload: true,
      downloadsToday: downloadsToday,
      lastDownloadDate: lastDownloadDate,
    );
  }

  /// Download new model, delete old, update Firestore
  static Future<String> _downloadAndUpdateModel({
    required String uid,
    required String currentMonth,
    required int oldLevel,
    required int newLevel,
  }) async {
    print('📥 Downloading Level $newLevel compressed model...');

    // Download new level
    final String newPath = await _downloadLevel(newLevel);

    // Verify download succeeded
    final bool downloadValid = await _verifyModelFile(newPath);
    if (!downloadValid && newLevel > 1) {
      throw Exception('Downloaded file verification failed');
    }

    // Delete old model (except level 1 which is bundled)
    if (oldLevel > 1 && oldLevel != newLevel) {
      await _deleteLevel(oldLevel);
    }

    // Update Firestore with transaction (atomic operation)
    final docRef = _getModelDocRef(uid, currentMonth);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data() as Map<String, dynamic>? ?? {};

      final String today = _getTodayString();
      final String? lastDownloadDate = data['last_download_date'];
      final int currentDownloads = lastDownloadDate == today
          ? (data['downloads_today'] ?? 0)
          : 0;

      transaction.update(docRef, {
        'current_level': newLevel,
        'current_model': 'av_lv${newLevel}_comp.glb',
        'last_updated': FieldValue.serverTimestamp(),
        'downloads_today': currentDownloads + 1,
        'last_download_date': today,
        'pending_update': false,
      });
    });

    print('✅ Model updated to Level $newLevel');
    return newPath;
  }

  /// Update Firestore level without download
  static Future<void> _updateFirestoreLevel(
    String uid,
    String month,
    int level, {
    bool clearPending = false,
  }) async {
    final docRef = _getModelDocRef(uid, month);
    final updateData = {
      'current_level': level,
      'current_model': 'av_lv${level}_comp.glb',
      'last_updated': FieldValue.serverTimestamp(),
    };
    
    if (clearPending) {
      updateData['pending_update'] = false;
    }
    
    await docRef.update(updateData);
  }

  /// Verify model file exists and is valid
  static Future<bool> _verifyModelFile(String filePath) async {
    try {
      // Level 1 is bundled asset, always valid
      if (filePath == BUNDLED_LEVEL_1) {
        return true;
      }

      final File file = File(filePath);
      
      // Check if file exists
      if (!await file.exists()) {
        print('⚠️ File not found: $filePath');
        return false;
      }

      // Check file size (should be at least 500KB for compressed models)
      final fileSize = await file.length();
      if (fileSize < 500000) {
        print('⚠️ File too small: ${(fileSize / 1024).toStringAsFixed(2)} KB');
        await file.delete(); // Delete corrupted file
        return false;
      }

      print('✅ File verified: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
      return true;
    } catch (e) {
      print('❌ File verification error: $e');
      return false;
    }
  }

  /// Get avatar file path (local or bundled)
  static Future<String> _getAvatarPath(int level) async {
    if (level == 1) {
      return BUNDLED_LEVEL_1;
    }

    final Directory appDocs = await getApplicationDocumentsDirectory();
    final String filePath = '${appDocs.path}/avatars/av_lv${level}_comp.glb';
    final File file = File(filePath);

    if (await file.exists()) {
      final fileSize = await file.length();
      
      // Verify file is valid size
      if (fileSize < 500000) {
        print('⚠️ Level $level file corrupted, deleting...');
        await file.delete();
        return BUNDLED_LEVEL_1;
      }
      
      print('✅ Found level $level file (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');
      return filePath;
    }

    // Fallback to level 1
    print('⚠️ Level $level not found, falling back to level 1');
    return BUNDLED_LEVEL_1;
  }

  /// Download model from Firebase Storage
  static Future<String> _downloadLevel(int level) async {
    final Directory appDocs = await getApplicationDocumentsDirectory();
    final Directory avatarDir = Directory('${appDocs.path}/avatars');

    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
      print('📁 Created avatar directory');
    }

    final String fileName = 'av_lv${level}_comp.glb';
    final String filePath = '${avatarDir.path}/$fileName';
    final File file = File(filePath);

    // Skip if already exists and valid
    if (await file.exists()) {
      final fileSize = await file.length();
      if (fileSize > 500000) { // At least 500KB
        print('✅ Level $level already downloaded (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');
        return filePath;
      } else {
        print('⚠️ Existing file is corrupted, re-downloading');
        await file.delete();
      }
    }

    try {
      // Get download URL from Firebase Storage
      final ref = _storage.ref('avatars/$fileName');
      final String downloadUrl = await ref.getDownloadURL();

      print('📥 Downloading from Firebase Storage...');

      // Download with progress and timeout
      await _dio.download(
        downloadUrl,
        filePath,
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 5),
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toInt();
            if (progress % 10 == 0) { // Log every 10%
              print('📊 Download: $progress% (${(received / 1024 / 1024).toStringAsFixed(1)} MB / ${(total / 1024 / 1024).toStringAsFixed(1)} MB)');
            }
          }
        },
      );

      // Verify download
      if (await file.exists()) {
        final fileSize = await file.length();
        
        if (fileSize < 500000) {
          await file.delete();
          throw Exception('Downloaded file is corrupted (too small)');
        }
        
        print('✅ Downloaded: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
        return filePath;
      } else {
        throw Exception('File not found after download');
      }
    } catch (e) {
      print('❌ Download failed: $e');
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  /// Delete model from local storage
  static Future<void> _deleteLevel(int level) async {
    if (level == 1) return; // Don't delete bundled asset

    try {
      final Directory appDocs = await getApplicationDocumentsDirectory();
      final String filePath = '${appDocs.path}/avatars/av_lv${level}_comp.glb';
      final File file = File(filePath);

      if (await file.exists()) {
        await file.delete();
        print('🗑️ Deleted level $level');
      }
    } catch (e) {
      print('⚠️ Delete failed (non-critical): $e');
    }
  }

  static String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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

      final Directory appDocs = await getApplicationDocumentsDirectory();
      final Directory avatarDir = Directory('${appDocs.path}/avatars');

      List<Map<String, dynamic>> files = [];
      if (await avatarDir.exists()) {
        final entities = avatarDir.listSync();
        for (var entity in entities) {
          if (entity is File) {
            final stat = await entity.stat();
            final isValid = stat.size > 500000;
            files.add({
              'name': entity.path.split('/').last,
              'size_mb': (stat.size / (1024 * 1024)).toStringAsFixed(2),
              'path': entity.path,
              'valid': isValid,
            });
          }
        }
      }

      return {
        'current_month': currentMonth,
        'current_level': modelData?['current_level'] ?? 1,
        'downloads_today': modelData?['downloads_today'] ?? 0,
        'last_download_date': modelData?['last_download_date'],
        'pending_update': modelData?['pending_update'] ?? false,
        'avatar_directory': avatarDir.path,
        'directory_exists': await avatarDir.exists(),
        'local_files': files,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Clean up old storage locations and files
  static Future<void> cleanupOldStorage(String uid) async {
    try {
      // Clean up old uncompressed files
      final Directory appDocs = await getApplicationDocumentsDirectory();
      final Directory avatarDir = Directory('${appDocs.path}/avatars');

      if (await avatarDir.exists()) {
        final entities = avatarDir.listSync();
        for (var entity in entities) {
          if (entity is File) {
            final name = entity.path.split('/').last;
            // Delete old uncompressed files (level_X.glb) and corrupted files
            if ((name.startsWith('level_') && name.endsWith('.glb')) ||
                (await entity.length()) < 500000) {
              await entity.delete();
              print('🗑️ Cleaned up old/corrupted file: $name');
            }
          }
        }
      }

      print('✅ Cleanup complete');
    } catch (e) {
      print('⚠️ Cleanup error: $e');
    }
  }

  /// Reset for testing
  static Future<void> resetForTesting(String uid) async {
    try {
      final String currentMonth = _getCurrentMonth();

      // Delete Firestore doc
      await _getModelDocRef(uid, currentMonth).delete();

      // Delete local files
      for (int level = 2; level <= 4; level++) {
        await _deleteLevel(level);
      }

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
  final bool downloadLimitExceeded;
  final bool showLimitMessage;
  final int downloadsToday;
  final String? lastDownloadDate;

  AvatarCheckResult({
    required this.success,
    required this.currentLevel,
    required this.currentPath,
    required this.wasUpdated,
    this.message,
    this.error,
    this.downloadLimitExceeded = false,
    this.showLimitMessage = false,
    this.downloadsToday = 0,
    this.lastDownloadDate,
  });
}

class AvatarUpdateResult {
  final bool success;
  final int level;
  final String path;
  final String? message;
  final String? error;
  final bool downloadLimitExceeded;
  final int downloadsToday;

  AvatarUpdateResult({
    required this.success,
    required this.level,
    required this.path,
    this.message,
    this.error,
    this.downloadLimitExceeded = false,
    this.downloadsToday = 0,
  });
}

class ModelUpdateStatus {
  final bool needsUpdate;
  final int currentLevel;
  final int requiredLevel;
  final bool canDownloadNow;
  final bool isUpgrade;
  final int downloadsToday;

  ModelUpdateStatus({
    required this.needsUpdate,
    required this.currentLevel,
    required this.requiredLevel,
    this.canDownloadNow = true,
    this.isUpgrade = true,
    this.downloadsToday = 0,
  });
}

class DownloadLimitCheck {
  final bool canDownload;
  final int downloadsToday;
  final String? lastDownloadDate;

  DownloadLimitCheck({
    required this.canDownload,
    required this.downloadsToday,
    this.lastDownloadDate,
  });
}