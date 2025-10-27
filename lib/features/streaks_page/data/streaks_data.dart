// ignore_for_file: constant_identifier_names

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:onlymens/core/data_state.dart';
import 'package:onlymens/core/globals.dart';

class StreaksData {
  // Cloud Firestore reference
  static CollectionReference get _streaksRef =>
      cloudDB.collection('users').doc(currentUser.uid).collection('streaks');

  // Core data properties - SIMPLIFIED
  static DateTime? originalStartDate;
  static DateTime? lastUpdateDate;
  static int currentStreakDays = 0; // Simple counter
  static int monthDoneDays = 0; // Simple counter for current month
  static int bestStreak = 0;
  static Map<String, int> dailyData = {};

  //fetch currentstreakDays
  //hours ..resets, openeed and 4 - lastupate(1)  = 3;
  //if skip then fill gaps to fill reset streaks, checks, show hours with current time,
  //

  // Status codes
  static const int RELAPSED = 0;
  static const int NOT_OPENED = 1;
  static const int SKIPPED = 2;
  static const int BOTH_TILES = 3;

  // ============================================================
  // INITIALIZATION & FETCH
  // ============================================================

  static Future<Duration> fetchData() async {
    Duration currentDuration = Duration.zero;
    await DataState.run(() async {
      final doc = await _streaksRef.doc('total').get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;

        originalStartDate = DateTime.parse(data['originalStartDate']);
        lastUpdateDate = DateTime.parse(data['lastUpdateDate']);
        currentStreakDays = data['currentStreakDays'] ?? 0;
        monthDoneDays = data['monthDoneDays'] ?? 0;
        bestStreak = data['bestStreak'] ?? 0;

        // Convert dailyData map
        final cloudDailyData = data['dailyData'] as Map<String, dynamic>?;
        dailyData = {};
        cloudDailyData?.forEach((key, value) {
          dailyData[key] = value as int;
        });

        // Fill gaps for days when app wasn't opened
        await _fillMissingDays();

        //getting current timer
        currentDuration = getCurrentStreak();
        print('in fetch $currentDuration');

        // Validate month counter (in case month changed)
        _validateMonthCounter();
      } else {
        // First time user - initialize
        await _initializeUser();
        currentDuration = Duration.zero;
      }
    });
    return currentDuration;
  }

  static Future<void> _initializeUser() async {
    originalStartDate = DateTime.now();
    lastUpdateDate = DateTime.now();
    currentStreakDays = 0;
    monthDoneDays = 0;
    bestStreak = 0;
    dailyData = {};

    await _streaksRef.doc('total').set({
      'originalStartDate': originalStartDate!.toIso8601String(),
      'lastUpdateDate': lastUpdateDate!.toIso8601String(),
      'currentStreakDays': 0,
      'monthDoneDays': 0,
      'bestStreak': 0,
      'dailyData': {},
    });

    print('✅ User initialized with start date: $originalStartDate');
  }

  // ============================================================
  // DATA UPDATE
  // ============================================================

  static Future<void> updateData(int status) async {
    try {
      DateTime today = DateTime.now();
      String todayKey = DateFormat('yyyy-MM-dd').format(today);

      // Handle status changes
      if (status == RELAPSED) {
        // Reset streak
        currentStreakDays = 0;
        // Update local data
        dailyData[todayKey] = status;
        lastUpdateDate = DateTime.now();
      } else if (status == BOTH_TILES) {
        // Check if this is first BOTH_TILES update today
        int? previousStatus = dailyData[todayKey];

        // Only increment if not already BOTH_TILES today
        if (previousStatus != BOTH_TILES) {
          currentStreakDays++;
          monthDoneDays++;

          // Update best streak if needed
          if (currentStreakDays > bestStreak) {
            bestStreak = currentStreakDays;
          }
        }
        // Update local data
        dailyData[todayKey] = status;
        lastUpdateDate = today;
      }

      // Push to cloud
      await _streaksRef.doc('total').update({
        'lastUpdateDate': today.toIso8601String(),
        'currentStreakDays': currentStreakDays,
        'monthDoneDays': monthDoneDays,
        'bestStreak': bestStreak,
        'dailyData.$todayKey': status,
      });

      print('✅ Updated $todayKey with status $status');
      print(
        '📊 Streak Days: $currentStreakDays | Month Done: $monthDoneDays | Best: $bestStreak',
      );
    } catch (e) {
      print('❌ Error updating streak data: $e');
      rethrow;
    }
  }

  // ============================================================
  // RESET TIMER
  // ============================================================

  static Future<void> resetTimer() async {
    try {
      DateTime now = DateTime.now();
      lastUpdateDate = now;

      await _streaksRef.doc('total').update({
        'lastUpdateDate': now.toIso8601String(),
      });

      print('✅ Timer reset to: $now');
    } catch (e) {
      print('❌ Error resetting timer: $e');
      rethrow;
    }
  }

  // ============================================================
  // GAP FILLING
  // ============================================================

  static Future<void> _fillMissingDays() async {
    if (originalStartDate == null) return;

    DateTime today = DateTime.now();
    DateTime todayNormalized = DateTime(today.year, today.month, today.day);
    DateTime startNormalized = DateTime(
      originalStartDate!.year,
      originalStartDate!.month,
      originalStartDate!.day,
    );

    Map<String, int> gapsToFill = {};
    bool hasGaps = false;

    for (
      DateTime date = startNormalized;
      !date.isAfter(todayNormalized);
      date = date.add(Duration(days: 1))
    ) {
      String dateKey = DateFormat('yyyy-MM-dd').format(date);

      if (!dailyData.containsKey(dateKey)) {
        dailyData[dateKey] = NOT_OPENED;
        gapsToFill[dateKey] = NOT_OPENED;
        hasGaps = true;
        print('📅 Filled gap: $dateKey (app not opened)');
      }
    }

    if (hasGaps) {
      try {
        Map<String, dynamic> updates = {};
        gapsToFill.forEach((dateKey, status) {
          updates['dailyData.$dateKey'] = status;
        });

        await _streaksRef.doc('total').update(updates);
        print('✅ Pushed ${gapsToFill.length} gap(s) to Firebase');
      } catch (e) {
        print('❌ Error pushing gaps to Firebase: $e');
      }
    }
  }

  // ============================================================
  // MONTH VALIDATION
  // ============================================================

  static void _validateMonthCounter() {
    DateTime now = DateTime.now();

    // Recalculate monthDoneDays from dailyData
    int calculatedMonthDays = 0;
    DateTime monthStart = DateTime(now.year, now.month, 1);

    for (
      DateTime date = monthStart;
      !date.isAfter(DateTime(now.year, now.month, now.day));
      date = date.add(Duration(days: 1))
    ) {
      String dateKey = DateFormat('yyyy-MM-dd').format(date);
      int? status = dailyData[dateKey];

      if (status == BOTH_TILES) {
        calculatedMonthDays++;
      }
    }

    // Update if mismatch (e.g., month changed)
    if (calculatedMonthDays != monthDoneDays) {
      monthDoneDays = calculatedMonthDays;
      print('📅 Month counter validated: $monthDoneDays');
    }
  }

  // ============================================================
  // TIMER CALCULATIONS
  // ============================================================

  /// Get duration since last update (for timer display)
  static Duration getTimerDuration() {
    if (lastUpdateDate == null) return Duration.zero;
    return DateTime.now().difference(lastUpdateDate!);
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Get heatmap data for calendar widget
  static Map<DateTime, int> getHeatmapData() {
    Map<DateTime, int> heatmapData = {};

    dailyData.forEach((dateString, status) {
      try {
        DateTime date = DateTime.parse(dateString);

        if (status == NOT_OPENED) {
          heatmapData[date] = 1; // Grey
        } else if (status == RELAPSED) {
          heatmapData[date] = 0; // Red
        } else if (status == SKIPPED) {
          heatmapData[date] = 1; // Light grey
        } else {
          heatmapData[date] = 3; // Purple (success)
        }
      } catch (e) {
        print('❌ Error parsing date: $dateString');
      }
    });

    return heatmapData;
  }

  /// Get status for specific date
  static int? getStatusForDate(DateTime date) {
    String dateKey = DateFormat('yyyy-MM-dd').format(date);
    return dailyData[dateKey];
  }

  /// Check if date can be updated (today only)
  static bool canUpdateDate(DateTime date) {
    DateTime today = DateTime.now();
    DateTime todayNormalized = DateTime(today.year, today.month, today.day);
    DateTime dateNormalized = DateTime(date.year, date.month, date.day);

    return dateNormalized.isAtSameMomentAs(todayNormalized);
  }

  /// Get success rate for current month
  static double getMonthSuccessRate() {
    DateTime now = DateTime.now();
    DateTime monthStart = DateTime(now.year, now.month, 1);

    int successDays = 0;
    int totalDays = 0;

    for (
      DateTime date = monthStart;
      !date.isAfter(DateTime(now.year, now.month, now.day));
      date = date.add(Duration(days: 1))
    ) {
      String dateKey = DateFormat('yyyy-MM-dd').format(date);
      int? status = dailyData[dateKey];

      if (status != null && status != NOT_OPENED) {
        totalDays++;
        if (status != RELAPSED) {
          successDays++;
        }
      }
    }

    if (totalDays == 0) return 0.0;
    return (successDays / totalDays) * 100;
  }

  /// Get overall success rate since start
  static double getTotalSuccessRate() {
    if (originalStartDate == null) return 0.0;

    int successDays = 0;
    int totalDays = 0;

    DateTime start = originalStartDate!;
    DateTime today = DateTime.now();
    DateTime todayNormalized = DateTime(today.year, today.month, today.day);

    for (
      DateTime date = start;
      !date.isAfter(todayNormalized);
      date = date.add(Duration(days: 1))
    ) {
      String dateKey = DateFormat('yyyy-MM-dd').format(date);
      int? status = dailyData[dateKey];

      if (status != null && status != NOT_OPENED) {
        totalDays++;
        if (status != RELAPSED) {
          successDays++;
        }
      }
    }

    if (totalDays == 0) return 0.0;
    return (successDays / totalDays) * 100;
  }

  static Duration getCurrentStreak() {
    late Duration returnHMS;

    dailyData = Map.fromEntries(
      dailyData.entries.toList()
        ..sort((a, b) => b.key.compareTo(a.key)), // reverse date order
    );

    int streakCount = 0;
    final todayStatus = dailyData.values.first;

    // Getting streak days
    for (var entry in dailyData.entries) {
      final status = entry.value;

      if (status == 3 || status == 2) {
        streakCount++;
      } else {
        break;
      }
    }

    print('todays : $todayStatus');

    // Getting streak hours/mins/secs
    if (todayStatus == 0) {
      if (lastUpdateDate != null) {
        // Calculate how long it's been since the last update
        returnHMS = DateTime.now().difference(lastUpdateDate!);
      } else {
        returnHMS = Duration.zero;
      }
    } else {
      // normal case
      returnHMS = Duration(
        seconds:
            DateTime.now().second +
            DateTime.now().minute * 60 +
            DateTime.now().hour * 3600,
      );
    }

    // Combine days + current HMS streak
    return Duration(
      days: streakCount == 0 ? 0 : streakCount - 1,
      hours: returnHMS.inHours % 24,
      minutes: returnHMS.inMinutes % 60,
      seconds: returnHMS.inSeconds % 60,
    );
  }

  static pushToCloud(int status) async {
    DataState.run(() async {
      DateTime today = DateTime.now();
      String todayKey = DateFormat('yyyy-MM-dd').format(today);
      // Push to cloud
      await DataState.run(() async {
        _streaksRef.doc('total').update({
          'lastUpdateDate': today.toIso8601String(),
          'currentStreakDays': currentStreakDays,
          'monthDoneDays': monthDoneDays,
          'bestStreak': bestStreak,
          'dailyData.$todayKey': status,
        });
      });
    });
  }

  static Future<void> updateRelapsed() async {
    lastUpdateDate = DateTime.now();
    await pushToCloud(0);
  }

  static Future<void> updateDoneAndSkip(int status) async {
    await pushToCloud(status);
  }
}
