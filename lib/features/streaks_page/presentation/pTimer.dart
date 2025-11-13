import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:onlymens/core/apptheme.dart';
import 'package:onlymens/core/globals.dart';
import 'package:onlymens/features/avatar/avatar_data.dart';
import 'package:onlymens/features/streaks_page/data/streaks_data.dart';
import 'package:onlymens/utilis/page_indicator.dart';
import 'package:onlymens/utilis/size_config.dart';
import 'package:onlymens/utilis/snackbar.dart';

// ✅ GLOBAL: Single source of truth for data state
ValueNotifier<Duration?> currentTimer = ValueNotifier(Duration.zero);
ValueNotifier<bool> dataLoadedNotifier = ValueNotifier(false);
ValueNotifier<int> refreshTrigger = ValueNotifier(0);

class TimerComponents extends StatefulWidget {
  const TimerComponents({super.key});

  @override
  State<TimerComponents> createState() => _TimerComponentsState();
}

// paste into your TimerComponents file (replace the existing state implementation)
class _TimerComponentsState extends State<TimerComponents> {
  bool _showSmallHeatmap = false;
  String _currentAvatarPath = AvatarManager.BUNDLED_LEVEL_1;
  bool _isLoadingAvatar = false;
  String _loadingMessage = '';
  bool _hasPendingUpdate = false; // show small reload icon
  int? _pendingRequiredLevel;
  int? _pendingCurrentLevel;
  int _avatarKeySalt = 0; // force RepaintBoundary / 3D viewer rebuild
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _bootAvatarLogic();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-run check whenever refreshTrigger notifies new streak data (e.g. backend sync)
    refreshTrigger.addListener(_onGlobalRefresh);
  }

  void _onGlobalRefresh() {
    // Timer/streak data refreshed → check avatar state again
    _initializeAvatar();
    _checkAvatarUpdate();
  }

  @override
  void dispose() {
    refreshTrigger.removeListener(_onGlobalRefresh);
    _confettiController.dispose();
    super.dispose();
  }

  /// Boot sequence: display current avatar quickly, then check for updates.
  Future<void> _bootAvatarLogic() async {
    // 1) Show whatever local/bundled avatar we have first (fast)
    final initialPath = await AvatarManager.getCurrentAvatarPath(
      currentUser.uid,
    );
    if (mounted) {
      setState(() {
        _currentAvatarPath = initialPath;
        _avatarKeySalt++;
      });
    }

    // 2) Then run the check & auto-update flow
    await _initializeAvatar(); // this checks & may auto-update
    await _checkAvatarUpdate(); // second-check to set pending flags / messages
  }

  // rest of your helpers (heatmap toggles)
  void _toggleSmallHeatmap() =>
      setState(() => _showSmallHeatmap = !_showSmallHeatmap);
  void _hideSmallHeatmap() {
    if (_showSmallHeatmap) setState(() => _showSmallHeatmap = false);
  }

  Widget _buildAvatarLoadingState() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const CupertinoActivityIndicator(color: Colors.white, radius: 12),
      const SizedBox(height: 16),
      Text(
        _loadingMessage,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );

  // --- helper: run upgrade effects (confetti + snackbar)
  void _onUpgrade(int newLevel) {
    // short confetti burst and snackbar
    _confettiController.play();
    Utilis.showSnackBar(
      "🎉 Congrats! Avatar upgraded to Level $newLevel!",
      isErr: false,
    );
  }

  /// Initialize avatar: determine previous level, then run cloud check/update,
  /// update UI and set pending flags correctly.
  Future<void> _initializeAvatar() async {
    if (!mounted) return;

    setState(() {
      _isLoadingAvatar = true;
      _loadingMessage = 'Checking avatar...';
    });

    try {
      // Get previous (current) level from Firestore doc so we can detect upgrades
      final info = await AvatarManager.getStorageInfo(currentUser.uid);
      final int previousLevel = info['current_level'] ?? 1;

      // This call may auto-download if allowed
      final result = await AvatarManager.checkAndUpdateModelAfterFetch(
        uid: currentUser.uid,
        currentStreakDays: StreaksData.currentStreakDays,
      );

      if (!mounted) return;

      // Update displayed path (always set whatever path the manager reports)
      setState(() {
        _currentAvatarPath = result.currentPath;
        _avatarKeySalt++;
        _isLoadingAvatar = false;
        _loadingMessage = '';
      });

      // If manager performed an update, check whether it's an upgrade (level up)
      if (result.wasUpdated) {
        final int newLevel = result.currentLevel;
        if (newLevel > previousLevel) {
          // Only play confetti/snackbar for upgrades
          _onUpgrade(newLevel);
        } else {
          // If it's not an upgrade (e.g., fallback/downgrade), show the message as toast
          if (result.message != null) Utilis.showToast(result.message!);
        }
        // clear pending flag on any successful update
        setState(() => _hasPendingUpdate = false);
      }

      // If the manager couldn't download because of limit -> show pending
      if (result.downloadLimitExceeded) {
        _pendingRequiredLevel = AvatarManager.getLevelFromDays(
          StreaksData.currentStreakDays,
        );
        _pendingCurrentLevel = result.currentLevel;
        setState(() => _hasPendingUpdate = true);
        // show one toast if allowed
        if (result.showLimitMessage && result.error != null) {
          Utilis.showToast(result.error!);
        }
      }
    } catch (e) {
      print('❌ Avatar init error: $e');
      if (mounted) {
        setState(() {
          _isLoadingAvatar = false;
          _loadingMessage = '';
        });
      }
    }
  }

  /// Secondary check: ensure UI shows pending state and current path is valid.
  /// This keeps the viewer in sync without forcing an update.
  Future<void> _checkAvatarUpdate() async {
    try {
      final result = await AvatarManager.checkAndUpdateModelAfterFetch(
        uid: currentUser.uid,
        currentStreakDays: StreaksData.currentStreakDays,
      );

      if (!mounted) return;

      if (result.success && result.currentPath.isNotEmpty) {
        setState(() {
          _currentAvatarPath = result.currentPath;
          _avatarKeySalt++;
          _hasPendingUpdate = result.downloadLimitExceeded;
        });
      }

      if (result.downloadLimitExceeded) {
        _pendingRequiredLevel = AvatarManager.getLevelFromDays(
          StreaksData.currentStreakDays,
        );
        _pendingCurrentLevel = result.currentLevel;
        setState(() => _hasPendingUpdate = true);
      }
    } catch (e) {
      print('❌ Avatar check failed: $e');
    }
  }

  /// Called when streak changes (Done/Skip/Relapse). If an update is needed:
  /// - If canDownloadNow => perform update automatically and refresh UI.
  /// - If cannot => mark pending and show hint (handled on Avatar page).
  Future<void> _handleStreakUpdate() async {
    try {
      final status = await AvatarManager.checkIfUpdateNeeded(
        uid: currentUser.uid,
        newStreakDays: StreaksData.currentStreakDays,
      );

      // No update needed, but still re-check to ensure UI path is current.
      if (!status.needsUpdate) {
        await _checkAvatarUpdate();
        return;
      }

      // If update is possible immediately, perform it automatically (no dialog)
      if (status.canDownloadNow) {
        if (!mounted) return;
        setState(() {
          _isLoadingAvatar = true;
          _loadingMessage = 'Updating avatar...';
        });

        final res = await AvatarManager.updateModelNow(
          uid: currentUser.uid,
          streakDays: StreaksData.currentStreakDays,
        );

        if (!mounted) return;

        setState(() {
          _isLoadingAvatar = false;
          _loadingMessage = '';
        });

        if (res.success) {
          // Immediately update UI with new path
          setState(() {
            _currentAvatarPath = res.path;
            _avatarKeySalt++;
            _hasPendingUpdate = false;
            _pendingRequiredLevel = null;
            _pendingCurrentLevel = null;
          });

          // Play confetti/snackbar only if it's an upgrade
          if (res.level > status.currentLevel) {
            _onUpgrade(res.level);
          } else {
            Utilis.showToast(res.message ?? 'Avatar updated');
          }

          // Notify app listeners (if any) to refresh data
          refreshTrigger.value = refreshTrigger.value + 1;
        } else {
          // If we failed due to download limit, mark pending for avatar page
          if (res.downloadLimitExceeded) {
            setState(() => _hasPendingUpdate = true);
            await AvatarManager.markPendingUpdate(uid: currentUser.uid);
            Utilis.showSnackBar(
              'Server busy. Avatar will auto-update later.',
              isErr: true,
            );
          } else {
            Utilis.showSnackBar(res.error ?? 'Update failed', isErr: true);
          }
        }
      } else {
        // Cannot download now (limit or other) — mark pending and show very small hint
        await AvatarManager.markPendingUpdate(uid: currentUser.uid);
        setState(() {
          _hasPendingUpdate = true;
          _pendingRequiredLevel = status.requiredLevel;
          _pendingCurrentLevel = status.currentLevel;
        });
        // keep quiet here (Avatar page will show reload icon and detailed dialog)
      }
    } catch (e) {
      print('❌ handleStreakUpdate error: $e');
    }
  }

  // BUILD
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentTimer,
      builder: (context, timer, _) {
        return Stack(
          children: [
            Column(
              children: [
                // App bar row
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Builder(
                        builder: (context) {
                          return IconButton(
                            onPressed: () => Scaffold.of(context).openDrawer(),
                            icon: const HugeIcon(
                              icon: HugeIcons.strokeRoundedSidebarLeft,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: _toggleSmallHeatmap,
                                icon: const HugeIcon(
                                  icon: HugeIcons.strokeRoundedCalendar03,
                                  color: Colors.white,
                                ),
                              ),
                              IconButton(
                                onPressed: () => context.push('/profile'),
                                icon: const HugeIcon(
                                  icon: HugeIcons.strokeRoundedUserCircle,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3D Avatar
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          height: 300,
                          width: 200,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Key contains salt so it rebuilds when the path changes
                              if (!_isLoadingAvatar)
                                RepaintBoundary(
                                  child: Flutter3DViewer(
                                    key: ValueKey(
                                      'avatar|$_currentAvatarPath|$_avatarKeySalt',
                                    ),
                                    src: _currentAvatarPath,
                                  ),
                                ),
                              if (_isLoadingAvatar) _buildAvatarLoadingState(),
                            ],
                          ),
                        ),
                        const Expanded(child: PornFreeTimerCompact()),
                      ],
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConfettiWidget(
                        confettiController: _confettiController,
                        blastDirection: 3.14 / 2, // straight down
                        blastDirectionality: BlastDirectionality.directional,
                        emissionFrequency: 0.03,
                        numberOfParticles: 20,
                        maxBlastForce: 10,
                        minBlastForce: 5,
                        gravity: 0.25,
                        colors: const [
                          Colors.deepPurple,
                          Colors.deepPurpleAccent,
                          Colors.amber,
                          Colors.yellow,
                        ],
                      ),
                    ),
                  ],
                ),

                DaysList(
                  key: ValueKey(StreaksData.currentStreakDays),
                  onStreakUpdate: _handleStreakUpdate,
                ),
              ],
            ),

            // Heatmap overlay
            if (_showSmallHeatmap)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _hideSmallHeatmap,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Material(
                        elevation: 10,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 260,
                          padding: const EdgeInsets.all(8),
                          child: const CompactHeatMap(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ... (Rest of the widgets remain the same: CompactHeatMap, PornFreeTimerCompact, DaysList, _BottomSheetContent)zƒ
class CompactHeatMap extends StatefulWidget {
  const CompactHeatMap({super.key});

  @override
  State<CompactHeatMap> createState() => _CompactHeatMapState();
}

class _CompactHeatMapState extends State<CompactHeatMap> {
  @override
  Widget build(BuildContext context) {
    // ✅ Use STRING-based data format that the package expects
    final heatmapData = StreaksData.getHeatmapData();

    // Debug print to verify data
    print('🗓️ HeatMap rebuilding with ${heatmapData.length} entries');

    return HeatMapCalendar(
      // ✅ Force complete widget recreation with unique key
      key: ValueKey(
        'heatmap_${DateTime.now().millisecondsSinceEpoch}_${heatmapData.length}',
      ),
      defaultColor: Colors.white,
      flexible: true,
      colorMode: ColorMode.color,
      datasets: heatmapData,
      showColorTip: false,
      textColor: Colors.black54,
      size: 30,
      initDate: DateTime.now(),
      colorsets: const {
        0: Color.fromARGB(
          255,
          237,
          178,
          181,
        ), // Relapsed - Light Red for visibility
        1: Color.fromARGB(255, 206, 202, 202),
        2: Color.fromARGB(255, 206, 202, 202),
        3: Color.fromARGB(255, 198, 160, 255), //
      },
    );
  }
}

class PornFreeTimerCompact extends StatefulWidget {
  const PornFreeTimerCompact({super.key});

  @override
  State<PornFreeTimerCompact> createState() => _PornFreeTimerCompactState();
}

class _PornFreeTimerCompactState extends State<PornFreeTimerCompact> {
  Timer? _timer;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool isLoading = true;
  Duration totalDoneDuration = Duration.zero;
  Duration currentDuration = Duration.zero;

  // ------------------ NEW: keep reference to listener so we can remove it ------------------
  late VoidCallback _refreshListener;

  @override
  void initState() {
    super.initState();

    // create listener
    _refreshListener = _onRefreshTriggered;
    // subscribe to global refresh trigger
    refreshTrigger.addListener(_refreshListener);

    _initData();
  }

  // ------------------ NEW: called when refreshTrigger.value changes ------------------
  void _onRefreshTriggered() {
    // If already disposing or not mounted, ignore
    if (!mounted) return;

    // Cancel existing timer and re-fetch data to update timer values
    _timer?.cancel();

    // set a quick loading state so UI shows activity (optional)
    setState(() => isLoading = true);

    // Re-init — this will fetch data and restart timer
    _initData();
  }

  Future<void> _initData() async {
    try {
      // ✅ Wait for data to fully load
      final Duration d = await StreaksData.fetchData();

      if (mounted) {
        // Update ValueNotifier used across app
        currentTimer.value = d;

        currentDuration = d;
        totalDoneDuration = StreaksData.getTotalDoneDaysAsDuration();

        // Mark data loaded
        dataLoadedNotifier.value = true;
        setState(() => isLoading = false);

        // restart timer (ensure only one timer)
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() {
              currentDuration = currentDuration + const Duration(seconds: 1);
              totalDoneDuration =
                  totalDoneDuration + const Duration(seconds: 1);
              currentTimer.value =
                  currentDuration; // keep global notifier in sync
            });
          }
        });
      }
    } catch (e) {
      print('Error initializing data: $e');
      if (mounted) {
        setState(() => isLoading = false);
        dataLoadedNotifier.value = true; // prevent blocking heatmap
      }
    }
  }

  Future<void> refreshData() async {
    // wrapper used elsewhere — reuse same behavior
    _timer?.cancel();
    setState(() => isLoading = true);
    await _initData();
  }

  @override
  void dispose() {
    // remove the listener to avoid leaks/crashes
    try {
      refreshTrigger.removeListener(_refreshListener);
    } catch (_) {}
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(child: CupertinoActivityIndicator())
        : currentDuration == Duration.zero && totalDoneDuration == Duration.zero
        ? Center(
            child: Text(
              'No data available',
              style: TextStyle(color: Colors.grey),
            ),
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: SizeConfig.screenHeight / 6,
                width: SizeConfig.screenWidth / 2,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  children: [
                    _buildTimerView("Currently", currentDuration),
                    _buildTimerView("Total", totalDoneDuration),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SimplePageIndicator(currentPage: _currentPage, pageCount: 2),
            ],
          );
  }

  Widget _buildTimerView(String title, Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[400],
          ),
        ),
        Text(
          "You've been porn free for..",
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 8),
        Text(
          "$days days  $hours hrs",
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          maxLines: 1,
          softWrap: true,
        ),
        const SizedBox(height: 6),
        Text(
          "$minutes min  $seconds sec",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }
}

class DaysList extends StatefulWidget {
  final VoidCallback? onStreakUpdate;

  const DaysList({super.key, this.onStreakUpdate});

  @override
  State<DaysList> createState() => _DaysListState();
}

class _DaysListState extends State<DaysList> {
  static ValueNotifier<int?> selectedDay = ValueNotifier(null);

  @override
  Widget build(BuildContext context) {
    // ✅ Rebuild when data changes
    return ValueListenableBuilder<int>(
      valueListenable: refreshTrigger,
      builder: (context, _, __) {
        DateTime now = DateTime.now();
        DateTime today = DateTime(now.year, now.month, now.day);
        DateTime monday = now.subtract(Duration(days: now.weekday - 1));
        List<DateTime> weekDates = List.generate(
          7,
          (index) => monday.add(Duration(days: index)),
        );

        final dayFormatter = DateFormat('E');
        final dateFormatter = DateFormat('d MMM');

        Color getStatusColor(int? status) {
          if (status == StreaksData.NOT_OPENED ||
              status == StreaksData.SKIPPED) {
            return const Color.fromARGB(255, 131, 131, 131);
          } else if (status == StreaksData.RELAPSED) {
            return const Color.fromARGB(255, 190, 114, 120);
          } else if (status == StreaksData.BOTH_TILES) {
            return const Color.fromARGB(255, 122, 89, 178);
          } else {
            return Colors.transparent;
          }
        }

        return SizedBox(
          height: 70,
          child: ValueListenableBuilder<int?>(
            valueListenable: selectedDay,
            builder: (context, value, child) {
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: weekDates.length,
                itemBuilder: (context, index) {
                  final date = weekDates[index];
                  final DateTime dateOnly = DateTime(
                    date.year,
                    date.month,
                    date.day,
                  );
                  final status = StreaksData.getStatusForDate(date);

                  final bool canUpdate = !dateOnly.isAfter(today);
                  final Color currentColor = getStatusColor(status);
                  final bool isFutureDate = dateOnly.isAfter(today);

                  return GestureDetector(
                    onTap: () {
                      if (!canUpdate) {
                        Utilis.showSnackBar('Cannot update future dates');
                        return;
                      }
                      selectedDay.value = index;
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.grey[900],
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        builder: (context) => _BottomSheetContent(
                          date: date,
                          onUpdate: () {
                            // ✅ Trigger global refresh
                            refreshTrigger.value++;
                            widget.onStreakUpdate?.call();
                            if (mounted) setState(() {});
                          },
                          isToday: dateOnly == today,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 5,
                      ),
                      margin: const EdgeInsets.all(4),
                      constraints: BoxConstraints.tight(Size(50, 100)),
                      decoration: BoxDecoration(
                        color: currentColor,
                        border: Border.all(
                          color: today != dateOnly
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : const Color.fromARGB(255, 199, 133, 82),
                          width: today != dateOnly ? 1 : 0.5,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: isFutureDate || today == dateOnly
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.5,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : [],
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dayFormatter.format(date),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateFormatter.format(date),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _BottomSheetContent extends StatefulWidget {
  final DateTime date;
  final VoidCallback? onUpdate;
  final bool isToday;

  const _BottomSheetContent({
    required this.date,
    this.onUpdate,
    this.isToday = false,
  });

  @override
  State<_BottomSheetContent> createState() => _BottomSheetContentState();
}

class _BottomSheetContentState extends State<_BottomSheetContent> {
  bool isPornChecked = false;
  bool isMasturbateChecked = false;
  bool isUpdatingSkip = false;
  bool isUpdatingDone = false;
  bool isRelapsedUpdating = false;

  @override
  Widget build(BuildContext context) {
    int remainingSkips = StreaksData.getRemainingSkips();
    bool canSkip = StreaksData.canSkipToday();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              DateFormat('EEEE, MMM d').format(widget.date),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isRelapsedUpdating ? null : () => _handleRelapse(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  disabledBackgroundColor: Colors.red[900],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  shadowColor: Colors.red.withValues(alpha: 0.5),
                  elevation: 6,
                ),
                child: isRelapsedUpdating
                    ? CupertinoActivityIndicator(color: Colors.white)
                    : const Text(
                        "I Relapsed",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                _buildSkipButton(remainingSkips, canSkip),
                const SizedBox(width: 10),
                _buildButton(
                  'Done',
                  () => widget.isToday
                      ? _handleDoneAndSkip(StreaksData.BOTH_TILES)
                      : _updateForPastDate(StreaksData.BOTH_TILES),
                  isUpdatingDone,
                ),
              ],
            ),
            if (remainingSkips > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '$remainingSkips skip${remainingSkips == 1 ? '' : 's'} left this month',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'No skips remaining this month',
                  style: TextStyle(
                    color: Colors.red[300],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(String txt, bool isChecked, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!isChecked),
          splashColor: Colors.deepPurple.withValues(alpha: 0.3),
          highlightColor: Colors.deepPurple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: isChecked ? Colors.deepPurple : Colors.grey[850],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.deepPurpleAccent, width: 0.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withValues(alpha: 0.2),
                  blurRadius: isChecked ? 10 : 4,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ListTile(
              trailing: Icon(
                isChecked ? Icons.check_circle : Icons.circle_outlined,
                color: isChecked ? Colors.orange : Colors.grey,
                size: SizeConfig.iconMedium,
              ),
              title: Text(txt, style: TextStyle(color: Colors.white)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton(int remainingSkips, bool canSkip) {
    // ✅ FIX: For past dates, allow skip regardless of canSkipToday()
    bool canSkipThisDate = widget.isToday ? canSkip : true;

    return Expanded(
      child: SizedBox(
        height: 50,
        child: ElevatedButton(
          onPressed: (isUpdatingSkip || !canSkipThisDate)
              ? null
              : () => widget.isToday
                    ? _handleDoneAndSkip(StreaksData.SKIPPED)
                    : _updateForPastDate(StreaksData.SKIPPED),
          style: ElevatedButton.styleFrom(
            backgroundColor: canSkipThisDate
                ? Colors.grey[800]
                : Colors.grey[900],
            disabledBackgroundColor: Colors.grey[850],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: isUpdatingSkip
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CupertinoActivityIndicator(color: Colors.white),
                )
              : Text(
                  widget.isToday ? 'Skip Today' : 'Skip',
                  style: TextStyle(
                    color: canSkipThisDate ? Colors.white : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildButton(String txt, Function fun, bool isUpdating, [Color? clr]) {
    return Expanded(
      child: SizedBox(
        height: 50,
        child: ElevatedButton(
          onPressed: isUpdating ? null : () => fun(),
          style: ElevatedButton.styleFrom(
            backgroundColor: clr ?? Colors.deepPurple,
            disabledBackgroundColor: Colors.deepPurple[800],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: isUpdating
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CupertinoActivityIndicator(color: Colors.white),
                )
              : Text(txt, style: TextStyle(color: Colors.white, fontSize: 14)),
        ),
      ),
    );
  }

  // ✅ FIX: This method now works for ALL statuses (Done, Skip, Relapse)
  Future<void> _updateForPastDate(int status) async {
    // Prevent multiple simultaneous updates
    if (isUpdatingDone || isUpdatingSkip || isRelapsedUpdating) return;

    // Set appropriate loading state based on status
    setState(() {
      if (status == StreaksData.BOTH_TILES) {
        isUpdatingDone = true;
      } else if (status == StreaksData.SKIPPED) {
        isUpdatingSkip = true;
      } else if (status == StreaksData.RELAPSED) {
        isRelapsedUpdating = true;
      }
    });

    try {
      bool hasNet = await hasInternet;
      if (!hasNet) {
        Utilis.showSnackBar('Please enable internet', isErr: true);
        return;
      }

      // Update the requested date (past or today) and await completion
      await StreaksData.updateStatusForDate(widget.date, status);

      // Re-fetch authoritative data (recalculates everything)
      final Duration d = await StreaksData.fetchData();

      // Update the global timer notifier so timer widgets update
      currentTimer.value = d;

      // Notify global UI pieces to rebuild (heatmap, days list, etc.)
      refreshTrigger.value++;

      String statusText = status == StreaksData.BOTH_TILES
          ? 'Done'
          : status == StreaksData.SKIPPED
          ? 'Skipped'
          : 'Relapsed';
      Utilis.showToast('Day marked as $statusText');

      // Close sheet and inform parent
      if (mounted) {
        Navigator.of(context).pop();
        widget.onUpdate?.call();
      }
    } catch (e) {
      Utilis.showSnackBar('Failed to update: $e', isErr: true);
    } finally {
      if (mounted) {
        setState(() {
          isUpdatingDone = false;
          isUpdatingSkip = false;
          isRelapsedUpdating = false;
        });
      }
    }
  }

  // ✅ FIX: Now properly handles past dates too
  Future<void> _handleRelapse() async {
    if (isRelapsedUpdating) return;

    // For past dates, use the common update method
    if (!widget.isToday) {
      await _updateForPastDate(StreaksData.RELAPSED);
      return;
    }

    // For today, keep the original logic
    setState(() => isRelapsedUpdating = true);

    try {
      bool hasNet = await hasInternet;
      if (!hasNet) {
        Utilis.showSnackBar('Please enable internet', isErr: true);
        return;
      }

      // This updates today's entry and persists
      await StreaksData.updateRelapsed();

      // Fetch fresh authoritative data
      final Duration d = await StreaksData.fetchData();
      currentTimer.value = d;

      // Notify UI
      refreshTrigger.value++;

      Utilis.showToast('Streak reset. Don\'t give up!');

      if (mounted) {
        Navigator.of(context).pop();
        widget.onUpdate?.call();
      }
    } catch (e) {
      Utilis.showSnackBar('Failed to update: $e', isErr: true);
    } finally {
      if (mounted) setState(() => isRelapsedUpdating = false);
    }
  }

  Future<void> _handleDoneAndSkip(int status) async {
    if (isUpdatingDone || isUpdatingSkip) return;

    bool isSkip = status == StreaksData.SKIPPED;

    setState(() {
      if (isSkip) {
        isUpdatingSkip = true;
      } else {
        isUpdatingDone = true;
      }
    });

    try {
      bool hasNet = await hasInternet;
      if (!hasNet) {
        Utilis.showSnackBar('Please enable internet', isErr: true);
        return;
      }

      if (isSkip && !StreaksData.canSkipToday()) {
        Utilis.showSnackBar(
          'You\'ve used all ${StreaksData.MAX_SKIPS_PER_MONTH} skips this month',
          isErr: true,
        );
        return;
      }

      // Update today's entry (this method is authoritative for today)
      await StreaksData.updateDoneAndSkip(status);

      // Fetch fresh data and update timer
      final Duration d = await StreaksData.fetchData();
      currentTimer.value = d;

      // Notify UI
      refreshTrigger.value++;

      String message = isSkip
          ? 'Day skipped. ${StreaksData.getRemainingSkips()} skips left this month'
          : 'Great job! Keep going! 💪';

      Utilis.showToast(message);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onUpdate?.call();
      }
    } catch (e) {
      Utilis.showSnackBar('Failed to update: $e', isErr: true);
    } finally {
      if (mounted) {
        setState(() {
          isUpdatingSkip = false;
          isUpdatingDone = false;
        });
      }
    }
  }
}
