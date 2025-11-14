import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:onlymens/core/apptheme.dart';
import 'package:onlymens/core/globals.dart';
import 'package:onlymens/features/avatar/avatar_data.dart';
import 'package:onlymens/features/streaks_page/data/streaks_data.dart';
import 'package:onlymens/utilis/page_indicator.dart';
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

class _TimerComponentsState extends State<TimerComponents> {
  bool _showSmallHeatmap = false;
  String _currentAvatarPath = AvatarManager.BUNDLED_LEVEL_1;
  bool _isLoadingAvatar = false;
  String _loadingMessage = '';
  int _avatarKeySalt = 0;
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
    refreshTrigger.addListener(_onGlobalRefresh);
  }

  void _onGlobalRefresh() {
    _initializeAvatar();
    _checkAvatarUpdate();
  }

  @override
  void dispose() {
    refreshTrigger.removeListener(_onGlobalRefresh);
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _bootAvatarLogic() async {
    final initialPath = await AvatarManager.getCurrentAvatarPath(
      currentUser.uid,
    );
    if (mounted) {
      setState(() {
        _currentAvatarPath = initialPath;
        _avatarKeySalt++;
      });
    }

    await _initializeAvatar();
    await _checkAvatarUpdate();
  }

  void _toggleSmallHeatmap() =>
      setState(() => _showSmallHeatmap = !_showSmallHeatmap);
  void _hideSmallHeatmap() {
    if (_showSmallHeatmap) setState(() => _showSmallHeatmap = false);
  }

  Widget _buildAvatarLoadingState() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoActivityIndicator(color: Colors.white, radius: 12.r),
          SizedBox(height: 16.h),
          Text(
            _loadingMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );

  void _onUpgrade(int newLevel) {
    _confettiController.play();
    Utilis.showSnackBar(
      "🎉 Congrats! Avatar upgraded to Level $newLevel!",
      isErr: false,
    );
  }

  Future<void> _initializeAvatar() async {
    if (!mounted) return;

    setState(() {
      _isLoadingAvatar = true;
      _loadingMessage = 'Checking avatar...';
    });

    try {
      final info = await AvatarManager.getStorageInfo(currentUser.uid);
      final int previousLevel = info['current_level'] ?? 1;

      final result = await AvatarManager.checkAndUpdateModelAfterFetch(
        uid: currentUser.uid,
        currentStreakDays: StreaksData.currentStreakDays,
      );

      if (!mounted) return;

      setState(() {
        _currentAvatarPath = result.currentPath;
        _avatarKeySalt++;
        _isLoadingAvatar = false;
        _loadingMessage = '';
      });

      if (result.wasUpdated) {
        final int newLevel = result.currentLevel;
        if (newLevel > previousLevel) {
          _onUpgrade(newLevel);
        } else {
          if (result.message != null) Utilis.showToast(result.message!);
        }
      }

      if (result.downloadLimitExceeded) {
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
        });
      }

      if (result.downloadLimitExceeded) {}
    } catch (e) {
      print('❌ Avatar check failed: $e');
    }
  }

  Future<void> _handleStreakUpdate() async {
    try {
      final status = await AvatarManager.checkIfUpdateNeeded(
        uid: currentUser.uid,
        newStreakDays: StreaksData.currentStreakDays,
      );

      if (!status.needsUpdate) {
        await _checkAvatarUpdate();
        return;
      }

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
          setState(() {
            _currentAvatarPath = res.path;
            _avatarKeySalt++;
          });

          if (res.level > status.currentLevel) {
            _onUpgrade(res.level);
          } else {
            Utilis.showToast(res.message ?? 'Avatar updated');
          }

          refreshTrigger.value = refreshTrigger.value + 1;
        } else {
          if (res.downloadLimitExceeded) {
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
        await AvatarManager.markPendingUpdate(uid: currentUser.uid);
        setState(() {});
      }
    } catch (e) {
      print('❌ handleStreakUpdate error: $e');
    }
  }

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
                  padding: EdgeInsets.only(top: 8.r),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Builder(
                        builder: (context) {
                          return IconButton(
                            onPressed: () => Scaffold.of(context).openDrawer(),
                            icon: HugeIcon(
                              icon: HugeIcons.strokeRoundedSidebarLeft,
                              color: Colors.white,
                              size: 30.sp,
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
                                icon: HugeIcon(
                                  icon: HugeIcons.strokeRoundedCalendar03,
                                  color: Colors.white,
                                  size: 30.sp,
                                ),
                              ),
                              IconButton(
                                onPressed: () => context.push('/profile'),
                                icon: HugeIcon(
                                  icon: HugeIcons.strokeRoundedUserCircle,
                                  color: Colors.white,
                                  size: 30.sp,
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
                          height: 260.h,
                          width: 200.w,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
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
                        blastDirection: 3.14 / 2,
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
                    padding: EdgeInsets.only(top: 60.r),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Material(
                        elevation: 10,
                        borderRadius: BorderRadius.circular(12.r),
                        child: Container(
                          width: 260.w,
                          padding: EdgeInsets.all(8.r),
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

class CompactHeatMap extends StatefulWidget {
  const CompactHeatMap({super.key});

  @override
  State<CompactHeatMap> createState() => _CompactHeatMapState();
}

class _CompactHeatMapState extends State<CompactHeatMap> {
  @override
  Widget build(BuildContext context) {
    final heatmapData = StreaksData.getHeatmapData();

    print('🗓️ HeatMap rebuilding with ${heatmapData.length} entries');

    return HeatMapCalendar(
      key: ValueKey(
        'heatmap_${DateTime.now().millisecondsSinceEpoch}_${heatmapData.length}',
      ),
      defaultColor: Colors.white,
      flexible: true,
      colorMode: ColorMode.color,
      datasets: heatmapData,
      showColorTip: false,
      textColor: Colors.black54,
      size: 25.sp,
      initDate: DateTime.now(),
      colorsets: const {
        0: Color.fromARGB(255, 237, 178, 181),
        1: Color.fromARGB(255, 206, 202, 202),
        2: Color.fromARGB(255, 206, 202, 202),
        3: Color.fromARGB(255, 198, 160, 255),
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

  late VoidCallback _refreshListener;

  @override
  void initState() {
    super.initState();

    _refreshListener = _onRefreshTriggered;
    refreshTrigger.addListener(_refreshListener);

    _initData();
  }

  void _onRefreshTriggered() {
    if (!mounted) return;

    _timer?.cancel();

    setState(() => isLoading = true);

    _initData();
  }

  Future<void> _initData() async {
    try {
      final Duration d = await StreaksData.fetchData();

      if (mounted) {
        currentTimer.value = d;

        currentDuration = d;
        totalDoneDuration = StreaksData.getTotalDoneDaysAsDuration();

        dataLoadedNotifier.value = true;
        setState(() => isLoading = false);

        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() {
              currentDuration = currentDuration + const Duration(seconds: 1);
              totalDoneDuration =
                  totalDoneDuration + const Duration(seconds: 1);
              currentTimer.value = currentDuration;
            });
          }
        });
      }
    } catch (e) {
      print('Error initializing data: $e');
      if (mounted) {
        setState(() => isLoading = false);
        dataLoadedNotifier.value = true;
      }
    }
  }

  Future<void> refreshData() async {
    _timer?.cancel();
    setState(() => isLoading = true);
    await _initData();
  }

  @override
  void dispose() {
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
                  style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 120.h,
                    width: 200.w,
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
                  SizedBox(height: 10.h),
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
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: Colors.grey[400],
          ),
        ),
        Text(
          "You've been porn free for..",
          style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
        ),
        SizedBox(height: 8.h),
        Text(
          "$days days  $hours hrs",
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
          maxLines: 1,
          softWrap: true,
        ),
        SizedBox(height: 6.h),
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
          height: 70.h,
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20.r),
                          ),
                        ),
                        builder: (context) => _BottomSheetContent(
                          date: date,
                          onUpdate: () {
                            refreshTrigger.value++;
                            widget.onStreakUpdate?.call();
                            if (mounted) setState(() {});
                          },
                          isToday: dateOnly == today,
                        ),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 4.h,
                        horizontal: 5.w,
                      ),
                      margin: EdgeInsets.all(3.r),
                      constraints: BoxConstraints.tight(Size(50.w, 100.h)),
                      decoration: BoxDecoration(
                        color: currentColor,
                        border: Border.all(
                          color: today != dateOnly
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : const Color.fromARGB(255, 199, 133, 82),
                          width: today != dateOnly ? 1.w : 0.5.w,
                        ),
                        borderRadius: BorderRadius.circular(10.r),
                        boxShadow: isFutureDate || today == dateOnly
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.5,
                                  ),
                                  blurRadius: 6.r,
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
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            dateFormatter.format(date),
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10.sp,
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
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: 20.h),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Text(
              DateFormat('EEEE, MMM d').format(widget.date),
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton(
                onPressed: isRelapsedUpdating ? null : () => _handleRelapse(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  disabledBackgroundColor: Colors.red[900],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  shadowColor: Colors.red.withValues(alpha: 0.5),
                  elevation: 6,
                ),
                child: isRelapsedUpdating
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : Text(
                        "I Relapsed",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15.sp,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            SizedBox(height: 15.h),
            Row(
              children: [
                _buildSkipButton(remainingSkips, canSkip),
                SizedBox(width: 10.w),
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
                padding: EdgeInsets.only(top: 12.h),
                child: Text(
                  '$remainingSkips skip${remainingSkips == 1 ? '' : 's'} left this month',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12.sp,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              Padding(
                padding: EdgeInsets.only(top: 12.h),
                child: Text(
                  'No skips remaining this month',
                  style: TextStyle(
                    color: Colors.red[300],
                    fontSize: 12.sp,
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
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!isChecked),
          splashColor: Colors.deepPurple.withValues(alpha: 0.3),
          highlightColor: Colors.deepPurple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10.r),
          child: Container(
            decoration: BoxDecoration(
              color: isChecked ? Colors.deepPurple : Colors.grey[850],
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: Colors.deepPurpleAccent,
                width: 0.2.w,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withValues(alpha: 0.2),
                  blurRadius: isChecked ? 10.r : 4.r,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ListTile(
              trailing: Icon(
                isChecked ? Icons.check_circle : Icons.circle_outlined,
                color: isChecked ? Colors.orange : Colors.grey,
                size: 24.sp,
              ),
              title: Text(
                txt,
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton(int remainingSkips, bool canSkip) {
    bool canSkipThisDate = widget.isToday ? canSkip : true;

    return Expanded(
      child: SizedBox(
        height: 50.h,
        child: ElevatedButton(
          onPressed: (isUpdatingSkip || !canSkipThisDate)
              ? null
              : () => widget.isToday
                    ? _handleDoneAndSkip(StreaksData.SKIPPED)
                    : _updateForPastDate(StreaksData.SKIPPED),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                canSkipThisDate ? Colors.grey[800] : Colors.grey[900],
            disabledBackgroundColor: Colors.grey[850],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
          child: isUpdatingSkip
              ? SizedBox(
                  width: 20.w,
                  height: 20.h,
                  child: const CupertinoActivityIndicator(color: Colors.white),
                )
              : Text(
                  widget.isToday ? 'Skip Today' : 'Skip',
                  style: TextStyle(
                    color: canSkipThisDate ? Colors.white : Colors.grey[600],
                    fontSize: 14.sp,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildButton(String txt, Function fun, bool isUpdating, [Color? clr]) {
    return Expanded(
      child: SizedBox(
        height: 50.h,
        child: ElevatedButton(
          onPressed: isUpdating ? null : () => fun(),
          style: ElevatedButton.styleFrom(
            backgroundColor: clr ?? Colors.deepPurple,
            disabledBackgroundColor: Colors.deepPurple[800],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
          child: isUpdating
              ? SizedBox(
                  width: 20.w,
                  height: 20.h,
                  child: const CupertinoActivityIndicator(color: Colors.white),
                )
              : Text(
                  txt,
                  style: TextStyle(color: Colors.white, fontSize: 14.sp),
                ),
        ),
      ),
    );
  }

  Future<void> _updateForPastDate(int status) async {
    if (isUpdatingDone || isUpdatingSkip || isRelapsedUpdating) return;

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

      await StreaksData.updateStatusForDate(widget.date, status);

      final Duration d = await StreaksData.fetchData();

      currentTimer.value = d;

      refreshTrigger.value++;

      String statusText = status == StreaksData.BOTH_TILES
          ? 'Done'
          : status == StreaksData.SKIPPED
              ? 'Skipped'
              : 'Relapsed';
      Utilis.showToast('Day marked as $statusText');

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

  Future<void> _handleRelapse() async {
    if (isRelapsedUpdating) return;

    if (!widget.isToday) {
      await _updateForPastDate(StreaksData.RELAPSED);
      return;
    }

    setState(() => isRelapsedUpdating = true);

    try {
      bool hasNet = await hasInternet;
      if (!hasNet) {
        Utilis.showSnackBar('Please enable internet', isErr: true);
        return;
      }

      await StreaksData.updateRelapsed();

      final Duration d = await StreaksData.fetchData();
      currentTimer.value = d;

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

      await StreaksData.updateDoneAndSkip(status);

      final Duration d = await StreaksData.fetchData();
      currentTimer.value = d;

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