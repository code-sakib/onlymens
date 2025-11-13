// ignore_for_file: constant_identifier_names

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:onlymens/core/data_state.dart';
import 'package:onlymens/core/globals.dart';
import 'package:onlymens/features/avatar/avatar_data.dart';
import 'package:onlymens/profile_page.dart';

class StreaksData {
  // Cloud Firestore reference
  static CollectionReference get _streaksRef =>
      cloudDB.collection('users').doc(currentUser.uid).collection('streaks');

  // Core data properties
  static DateTime? originalStartDate;
  static DateTime? lastUpdateDate;
  static int currentStreakDays = 0;
  static int monthDoneDays = 0;
  static int totalDoneDays = 0; // Total count of all BOTH_TILES days
  static int bestStreakDays = 0; // Longest consecutive streak
  static int monthSkipsUsed = 0;
  static Map<String, int> dailyData = {};

  // Status codes
  static const int RELAPSED = 0;
  static const int NOT_OPENED = 1;
  static const int SKIPPED = 2;
  static const int BOTH_TILES = 3;

  // Configuration
  static const int MAX_SKIPS_PER_MONTH = 3;

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
        totalDoneDays = data['totalDoneDays'] ?? 0;
        bestStreakDays = data['bestStreakDays'] ?? 0;
        monthSkipsUsed = data['monthSkipsUsed'] ?? 0;

        // Convert dailyData map
        final cloudDailyData = data['dailyData'] as Map<String, dynamic>?;
        dailyData = {};
        cloudDailyData?.forEach((key, value) {
          dailyData[key] = value as int;
        });

        // Fill gaps for days when app wasn't opened
        bool hasGaps = _fillMissingDays();

        // CORRECT ORDER:
        // 1. Recalculate streaks (using gap-filled data)
        _recalculateAllStreaks();

        // 2. If gaps were filled, push updated data to cloud
        if (hasGaps) {
          await _pushToCloud();
          print('☁️ Pushed gap-filled data to cloud');
        }

        // 3. Get current timer duration
        currentDuration = getCurrentStreak();

        // 🎯 NEW: Check and update avatar after fetch
        final avatarResult = await AvatarManager.checkAndUpdateModelAfterFetch(
          uid: currentUser.uid,
          currentStreakDays: currentStreakDays,
        );

        if (avatarResult.wasUpdated) {
          print('🎉 Avatar auto-updated to Level ${avatarResult.currentLevel}');
        }

        print(
          '✅ Data fetched - Current: $currentStreakDays | Best Streak: $bestStreakDays | Total Done: $totalDoneDays | Month: $monthDoneDays | Skips: $monthSkipsUsed/$MAX_SKIPS_PER_MONTH',
        );
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
    totalDoneDays = 0;
    bestStreakDays = 0;
    monthSkipsUsed = 0;
    dailyData = {};

    await _streaksRef.doc('total').set({
      'originalStartDate': originalStartDate!.toIso8601String(),
      'lastUpdateDate': lastUpdateDate!.toIso8601String(),
      'currentStreakDays': 0,
      'monthDoneDays': 0,
      'totalDoneDays': 0,
      'bestStreakDays': 0,
      'monthSkipsUsed': 0,
      'dailyData': {},
    });

    print('✅ User initialized with start date: $originalStartDate');
  }

  // ============================================================
  // RECALCULATION ENGINE
  // ============================================================

  /// Recalculates all streak data from dailyData
  static void _recalculateAllStreaks() {
    DateTime now = DateTime.now();

    // 1. Calculate current streak (consecutive days from today backwards)
    currentStreakDays = _calculateCurrentStreak();

    // 2. Calculate best streak ever (longest consecutive streak)
    bestStreakDays = _calculateBestStreak();

    // 3. Calculate total done days (count of all BOTH_TILES)
    totalDoneDays = _calculateTotalDoneDays();

    // 4. Calculate this month's stats
    final monthStats = _calculateMonthStats(now.year, now.month);
    monthDoneDays = monthStats['doneDays']!;
    monthSkipsUsed = monthStats['skipsUsed']!;

    // Update globals
    glbCurrentStreakDays = currentStreakDays;
    glbTotalDoneDays = totalDoneDays;
    glbCurrentStreakDaysNotifier.value = currentStreakDays;
    dailyData = dailyData;

    ProfileData.updateFields(currentStreakDays, totalDoneDays);



    print(
      '🔄 Recalculated - Current: $glbCurrentStreakDays | Best: $bestStreakDays | Total Done: $totalDoneDays | Month Done: $monthDoneDays | Skips: $monthSkipsUsed',
    );
  }

  /// Calculate current consecutive streak from today backwards
  static int _calculateCurrentStreak() {
    DateTime today = DateTime.now();
    DateTime current = DateTime(today.year, today.month, today.day);

    int streakDays = 0;
    int currentMonthSkips = 0;
    int lastMonth = current.month;

    // Sort dates in reverse chronological order
    List<String> sortedDates = dailyData.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    for (String dateKey in sortedDates) {
      DateTime date = DateTime.parse(dateKey);
      int status = dailyData[dateKey]!;

      // Only process dates up to today
      if (date.isAfter(current)) continue;

      // Reset skip counter when month changes
      if (date.month != lastMonth) {
        currentMonthSkips = 0;
        lastMonth = date.month;
      }

      if (status == BOTH_TILES) {
        streakDays++;
      } else if (status == SKIPPED) {
        currentMonthSkips++;
        if (currentMonthSkips <= MAX_SKIPS_PER_MONTH) {
          streakDays++;
        } else {
          break;
        }
      } else if (status == RELAPSED) {
        break;
      } else if (status == NOT_OPENED) {
        break;
      }
    }

    return streakDays;
  }

  /// Calculate the longest consecutive streak ever
  static int _calculateBestStreak() {
    if (dailyData.isEmpty) return 0;

    List<String> sortedDates = dailyData.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    int bestStreak = 0;
    int currentStreak = 0;
    int currentMonthSkips = 0;
    int lastMonth = -1;

    for (String dateKey in sortedDates) {
      DateTime date = DateTime.parse(dateKey);
      int status = dailyData[dateKey]!;

      if (date.month != lastMonth) {
        currentMonthSkips = 0;
        lastMonth = date.month;
      }

      if (status == BOTH_TILES) {
        currentStreak++;
      } else if (status == SKIPPED) {
        currentMonthSkips++;
        if (currentMonthSkips <= MAX_SKIPS_PER_MONTH) {
          currentStreak++;
        } else {
          bestStreak = currentStreak > bestStreak ? currentStreak : bestStreak;
          currentStreak = 0;
          currentMonthSkips = 1;
        }
      } else {
        bestStreak = currentStreak > bestStreak ? currentStreak : bestStreak;
        currentStreak = 0;
        currentMonthSkips = 0;
      }
    }

    bestStreak = currentStreak > bestStreak ? currentStreak : bestStreak;
    return bestStreak;
  }

  /// Calculate total done days (count of all BOTH_TILES status)
  static int _calculateTotalDoneDays() {
    int total = 0;

    dailyData.forEach((dateKey, status) {
      if (status == BOTH_TILES) {
        total++;
      }
    });

    return total;
  }

  /// Calculate month statistics
  static Map<String, int> _calculateMonthStats(int year, int month) {
    int doneDays = 0;
    int skipsUsed = 0;

    DateTime monthStart = DateTime(year, month, 1);
    DateTime monthEnd = DateTime(year, month + 1, 0);
    DateTime today = DateTime.now();
    DateTime endDate = today.isBefore(monthEnd)
        ? DateTime(today.year, today.month, today.day)
        : monthEnd;

    for (
      DateTime date = monthStart;
      !date.isAfter(endDate);
      date = date.add(Duration(days: 1))
    ) {
      String dateKey = DateFormat('yyyy-MM-dd').format(date);
      int? status = dailyData[dateKey];

      if (status == BOTH_TILES) {
        doneDays++;
      } else if (status == SKIPPED) {
        skipsUsed++;
      }
    }

    return {'doneDays': doneDays, 'skipsUsed': skipsUsed};
  }

  // ============================================================
  // DATA UPDATE METHODS
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

  static Future<void> _pushToCloud() async {
    try {
      await _streaksRef.doc('total').update({
        'lastUpdateDate': lastUpdateDate!.toIso8601String(),
        'currentStreakDays': currentStreakDays,
        'monthDoneDays': monthDoneDays,
        'totalDoneDays': totalDoneDays,
        'bestStreakDays': bestStreakDays,
        'monthSkipsUsed': monthSkipsUsed,
        'dailyData': dailyData,
      });

      print('☁️ Pushed to cloud');
    } catch (e) {
      print('❌ Error pushing to cloud: $e');
      rethrow;
    }
  }

  // ============================================================
  // GAP FILLING - FIXED
  // ============================================================

  static bool _fillMissingDays() {
    if (dailyData.isEmpty) return false;

    DateTime today = DateTime.now();
    DateTime todayNormalized = DateTime(today.year, today.month, today.day);

    // Fill only up to YESTERDAY, not today (user decides for today)
    DateTime yesterday = todayNormalized.subtract(Duration(days: 1));

    // Find the last date in dailyData
    List<String> sortedDates = dailyData.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    String lastDateKey = sortedDates.last;
    DateTime lastDate = DateTime.parse(lastDateKey);
    DateTime lastDateNormalized = DateTime(
      lastDate.year,
      lastDate.month,
      lastDate.day,
    );

    bool hasGaps = false;

    // Fill gaps from the day after last recorded date to YESTERDAY (not today)
    DateTime startFilling = lastDateNormalized.add(Duration(days: 1));

    // Only fill if there are dates between last date and yesterday
    if (startFilling.isBefore(todayNormalized)) {
      for (
        DateTime date = startFilling;
        date.isBefore(todayNormalized); // Fill up to yesterday only
        date = date.add(Duration(days: 1))
      ) {
        String dateKey = DateFormat('yyyy-MM-dd').format(date);

        // Fill missing date with NOT_OPENED status
        if (!dailyData.containsKey(dateKey)) {
          dailyData[dateKey] = NOT_OPENED;
          hasGaps = true;
          print('📅 Filled gap: $dateKey with NOT_OPENED');
        }
      }
    }

    if (hasGaps) {
      print(
        '✅ Filled missing days from ${DateFormat('yyyy-MM-dd').format(lastDateNormalized)} to ${DateFormat('yyyy-MM-dd').format(yesterday)}',
      );
    } else {
      print(
        '✅ No gaps found. Last date: $lastDateKey, Yesterday: ${DateFormat('yyyy-MM-dd').format(yesterday)}',
      );
    }

    return hasGaps;
  }

  // ============================================================
  // TIMER CALCULATIONS
  // ============================================================

  /// Get current streak as Duration
  static Duration getCurrentStreak() {
    final now = DateTime.now();
    String todayKey = DateFormat('yyyy-MM-dd').format(now);
    int? todayStatus = dailyData[todayKey];

    if (todayStatus == RELAPSED) {
      if (lastUpdateDate != null) {
        Duration timeSinceRelapse = now.difference(lastUpdateDate!);
        return Duration(
          hours: timeSinceRelapse.inHours % 24,
          minutes: timeSinceRelapse.inMinutes % 60,
          seconds: timeSinceRelapse.inSeconds % 60,
        );
      } else {
        return Duration(
          hours: now.hour,
          minutes: now.minute,
          seconds: now.second,
        );
      }
    } else {
      return Duration(
        days: currentStreakDays,
        hours: now.hour,
        minutes: now.minute,
        seconds: now.second,
      );
    }
  }

  /// Get total done days as Duration with current time
  static Duration getTotalDoneDaysAsDuration() {
    final now = DateTime.now();

    return Duration(
      days: totalDoneDays,
      hours: now.hour,
      minutes: now.minute,
      seconds: now.second,
    );
  }

  static Duration getTimerDuration() {
    if (lastUpdateDate == null) return Duration.zero;
    return DateTime.now().difference(lastUpdateDate!);
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  static int getRemainingSkips() {
    return MAX_SKIPS_PER_MONTH - monthSkipsUsed;
  }

  static bool canSkipToday() {
    return monthSkipsUsed < MAX_SKIPS_PER_MONTH;
  }

  // Replace the getHeatmapData() method in streaks_data.dart with this:

  // Replace the getHeatmapData() method in streaks_data.dart with this:

  // Replace the getHeatmapData() method in streaks_data.dart with this:

  static Map<DateTime, int> getHeatmapData() {
    Map<DateTime, int> heatmapData = {};

    dailyData.forEach((dateString, status) {
      try {
        heatmapData[DateTime.parse(dateString)] = status;
      } catch (e) {
        print('❌ Error parsing date: $dateString');
      }
    });

    // Debug: Print sample data to verify format
    if (heatmapData.isNotEmpty) {
      final today = DateTime.now();
      final todayNormalized = DateTime(today.year, today.month, today.day);
      final todayStatus = heatmapData[todayNormalized];
      print(
        '🗓️ HeatMap Data: ${heatmapData.length} entries | Today status: $todayStatus',
      );

      // Print first 3 entries
      int count = 0;
      heatmapData.forEach((date, status) {
        if (count < 3) {
          print('  📅 $date => $status');
          count++;
        }
      });
    }

    return heatmapData;
  }

  static int? getStatusForDate(DateTime date) {
    String dateKey = DateFormat('yyyy-MM-dd').format(date);
    return dailyData[dateKey];
  }

  static bool canUpdateDate(DateTime date) {
    DateTime today = DateTime.now();
    DateTime todayNormalized = DateTime(today.year, today.month, today.day);
    DateTime dateNormalized = DateTime(date.year, date.month, date.day);

    return dateNormalized.isAtSameMomentAs(todayNormalized);
  }

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
        if (status == BOTH_TILES || status == SKIPPED) {
          successDays++;
        }
      }
    }

    if (totalDays == 0) return 0.0;
    return (successDays / totalDays) * 100;
  }

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
        if (status == BOTH_TILES || status == SKIPPED) {
          successDays++;
        }
      }
    }

    if (totalDays == 0) return 0.0;
    return (successDays / totalDays) * 100;
  }
  static Future<void> updateStatusForDate(DateTime date, int status) async {
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(date);

      // Validate status
      if (!(status == BOTH_TILES ||
          status == SKIPPED ||
          status == RELAPSED ||
          status == NOT_OPENED)) {
        throw Exception('Invalid status: $status');
      }

      // Apply change locally
      dailyData[dateKey] = status;

      // Update lastUpdateDate only if we're changing TODAY
      final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (dateKey == todayKey) {
        lastUpdateDate = DateTime.now();
      }

      // Recalculate after mutation
      _recalculateAllStreaks();

      // Persist and WAIT for cloud write to finish
      await _pushToCloud();

      print('✅ updateStatusForDate -> $dateKey = $status');
    } catch (e) {
      print('❌ updateStatusForDate error: $e');
      rethrow;
    }
  }

  /// Update today's relapse (keeps semantics)
  static Future<void> updateRelapsed() async {
    try {
      DateTime today = DateTime.now();
      String todayKey = DateFormat('yyyy-MM-dd').format(today);

      dailyData[todayKey] = RELAPSED;
      // update lastUpdateDate to now for relapse
      lastUpdateDate = DateTime.now();

      _recalculateAllStreaks();
      await _pushToCloud();

      print('❌ Relapsed on $todayKey - Streak reset');
    } catch (e) {
      print('❌ Error updating relapse: $e');
      rethrow;
    }
  }

  /// Update today with DONE or SKIPPED. Validates skips limit.
  /// This method mutates today's entry and persists.
  static Future<void> updateDoneAndSkip(int status) async {
    try {
      DateTime today = DateTime.now();
      String todayKey = DateFormat('yyyy-MM-dd').format(today);

      if (status != BOTH_TILES && status != SKIPPED) {
        throw Exception('Invalid status: $status');
      }

      // Validate skip quotas (counting existing recorded skips in month)
      if (status == SKIPPED) {
        final monthStats = _calculateMonthStats(today.year, today.month);
        final currentSkips = monthStats['skipsUsed']!;
        final existingStatus = dailyData[todayKey];
        // if not already skipped and already used limit -> throw
        if (existingStatus != SKIPPED && currentSkips >= MAX_SKIPS_PER_MONTH) {
          throw Exception(
            'You have already used all $MAX_SKIPS_PER_MONTH skips this month',
          );
        }
      }

      // Apply locally
      dailyData[todayKey] = status;
      lastUpdateDate = DateTime.now();

      _recalculateAllStreaks();
      await _pushToCloud();

      String statusText = status == BOTH_TILES ? 'DONE' : 'SKIPPED';
      print('✅ Updated $todayKey with $statusText');
    } catch (e) {
      print('❌ Error updating status: $e');
      rethrow;
    }
  }
}

// Global data for streaks counting
int glbCurrentStreakDays = 0;
ValueNotifier<int> glbCurrentStreakDaysNotifier = ValueNotifier(0);
int glbTotalDoneDays = 0;
Map<DateTime, int> dailyData = {};
