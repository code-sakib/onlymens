import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:onlymens/core/apptheme.dart';
import 'package:onlymens/core/globals.dart';
import 'package:onlymens/features/streaks_page/data/streaks_data.dart';
import 'package:onlymens/utilis/page_indicator.dart';
import 'package:onlymens/utilis/size_config.dart';
import 'package:onlymens/utilis/snackbar.dart';

ValueNotifier<Duration?> currentTimer = ValueNotifier(Duration.zero);

class TimerComponents extends StatefulWidget {
  const TimerComponents({super.key});

  @override
  State<TimerComponents> createState() => _TimerComponentsState();
}

class _TimerComponentsState extends State<TimerComponents> {
  bool _showSmallHeatmap = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final double _popupRight = 16;
  final double _popupTopOffset = 10;

  void _toggleSmallHeatmap() =>
      setState(() => _showSmallHeatmap = !_showSmallHeatmap);
  void _hideSmallHeatmap() {
    if (_showSmallHeatmap) setState(() => _showSmallHeatmap = false);
  }

  final bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentTimer,
      builder: (context, timer, child) {
        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            leading: IconButton(
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
              icon: Icon(Icons.more_vert, color: Colors.transparent),
            ),
            actions: [
              IconButton(
                onPressed: _toggleSmallHeatmap,
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar03,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: () {
                  context.push('/profile');
                },
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedUserCircle,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        height: 300,
                        width: 200,
                        child: Flutter3DViewer(src: 'assets/3d/av_lv1.glb'),
                      ),
                      PornFreeTimerCompact(),
                    ],
                  ),
                  DaysList(key: ValueKey(StreaksData.currentStreakDays)),
                ],
              ),
              if (_showSmallHeatmap)
                  Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _hideSmallHeatmap,
                    child: Stack(
                      children: [
                        Positioned(
                          top: _popupTopOffset,
                          right: _popupRight,
                          child: GestureDetector(
                            onTap: () {},
                            child: Material(
                              elevation: 10,
                              borderRadius: BorderRadius.circular(12),
                              clipBehavior: Clip.hardEdge,
                              child: Container(
                                width: min(SizeConfig.screenWidth * 0.6, 260),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [CompactHeatMap()],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
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
  Timer? _timer; // make nullable so no cancel error
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final d = await StreaksData.fetchData();

    // Update once when data arrives
    currentTimer.value = d;
    setState(() => isLoading = false);

    // Start a timer that updates every second
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && currentTimer.value != null) {
        // Add 1 second to current timer value
        currentTimer.value = currentTimer.value! + const Duration(seconds: 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return !isLoading || currentTimer.value == null
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Center(
                child: SizedBox(
                  height: SizeConfig.screenHeight / 8,
                  width: SizeConfig.screenWidth / 2,
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    children: [
                      _buildTimerView(
                        "Currently",
                        "You've been porn free for..",
                        currentTimer.value!,
                      ),
                      _buildTimerView(
                        "This month",
                        "You've been porn free for..",
                        currentTimer.value!,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SimplePageIndicator(currentPage: _currentPage, pageCount: 2),
            ],
          )
        : const CupertinoActivityIndicator();
  }

  Widget _buildTimerView(String title, String subtitle, Duration duration) {
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
        Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 8),
        Text(
          "$days days  $hours hrs",
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
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
  const DaysList({super.key});

  @override
  State<DaysList> createState() => _DaysListState();
}

class _DaysListState extends State<DaysList> {
  static ValueNotifier<int?> selectedDay = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    DateTime monday = now.subtract(Duration(days: now.weekday - 1));
    List<DateTime> weekDates = List.generate(
      7,
      (index) => monday.add(Duration(days: index)),
    );

    final dayFormatter = DateFormat('E');
    final dateFormatter = DateFormat('d MMM');

    // Helper function that returns both color and dots
    Color getStatusColor(int? status) {
      Color bgColor;

      if (status == null || status == StreaksData.NOT_OPENED) {
        bgColor = Colors.transparent;
      } else if (status == StreaksData.RELAPSED) {
        bgColor = const Color(0xFF7F1019).withValues(alpha: 0.5);
      } else if (status == StreaksData.SKIPPED) {
        bgColor = Colors.grey;
      } else if (status == StreaksData.BOTH_TILES) {
        bgColor = Colors.deepPurple;
      } else {
        bgColor = Colors.transparent;
      }

      return bgColor;
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

              // Get status from StreaksData
              final status = StreaksData.getStatusForDate(date);
              final canUpdate = StreaksData.canUpdateDate(date);

              // Get color and dots for this status
              final Color currentColor = getStatusColor(status);

              return GestureDetector(
                onTap: () {
                  if (!canUpdate) {
                    Utilis.showSnackBar('Cannot update past dates');
                    return;
                  }
                  selectedDay.value = index;
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => _BottomSheetContent(
                      date: date,
                      onUpdate: () {
                        // Rebuild DaysList
                        setState(() {});
                      },
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 5,
                  ),
                  margin: const EdgeInsets.all(4),
                  constraints: BoxConstraints.tight(Size(50, 50)),
                  decoration: BoxDecoration(
                    color: currentColor,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      status != 0
                          ? BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.5),
                              blurRadius: 6,
                              offset: const Offset(0, 6),
                            )
                          : BoxShadow(),
                    ],
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
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormatter.format(date),
                        style: TextStyle(color: Colors.white70, fontSize: 10),
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
  }
}

///streaks bottom sheet
class _BottomSheetContent extends StatefulWidget {
  final DateTime date;
  final VoidCallback? onUpdate; // Add this callback

  const _BottomSheetContent({
    required this.date,
    this.onUpdate, // Add this parameter
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
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Text(
            DateFormat('EEEE, MMM d').format(widget.date),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 20),

          // List Tiles
          _buildTile("Didn't watch porn", isPornChecked, (val) {
            setState(() => isPornChecked = val);
          }),
          _buildTile("Didn't masturbate", isMasturbateChecked, (val) {
            setState(() => isMasturbateChecked = val);
          }),
          SizedBox(height: 20),

          // I Relapsed Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isRelapsedUpdating ? null : () => _handleRelapse(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
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

          // Skip and Done Buttons Row
          Row(
            children: [
              _buildButton(
                'Skip Today',
                () => _handleDoneAndSkip(2),
                isUpdatingSkip,
                Colors.grey[800],
              ),
              const SizedBox(width: 10),
              _buildButton('Done', () => _handleDoneAndSkip(3), isUpdatingDone),
            ],
          ),
        ],
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
              color: isChecked ? Colors.deepPurple : Colors.grey[900],
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

  Future<void> _handleRelapse() async {
    if (isRelapsedUpdating) return;

    setState(() => isRelapsedUpdating = true);

    try {
      // Check internet
      bool hasNet = await hasInternet;
      if (!hasNet) {
        Utilis.showSnackBar('Please enable internet', isErr: true);
        return;
      }

      // Update with RELAPSED status
      await StreaksData.updateRelapsed();
      await StreaksData.fetchData().then((d) {
        currentTimer.value = d;
      });
      Utilis.showToast('Streak reset. Don\'t give up!');
      if (mounted) {
        context.pop();
        // Call the callback to trigger parent rebuild
      }
    } catch (e) {
      Utilis.showSnackBar('Failed to update: $e', isErr: true);
    } finally {
      if (mounted) {
        setState(
          () => isRelapsedUpdating = false,
        ); // Fixed: was setting isUpdating instead
      }
    }
  }

  Future<void> _handleSkip() async {
    if (isUpdatingSkip) return;

    setState(() => isUpdatingSkip = true);

    try {
      bool hasNet = await hasInternet;
      if (!hasNet) {
        Utilis.showSnackBar('Please enable internet', isErr: true);
        return;
      }

      //skip
      //grey mark
      //timer streak stays same

      // Update with SKIPPED status
      await StreaksData.updateData(StreaksData.SKIPPED);

      Utilis.showToast('Day skipped');
      if (mounted) {
        Navigator.of(context).pop();
        // Call the callback to trigger parent rebuild
        widget.onUpdate?.call();
      }
    } catch (e) {
      Utilis.showSnackBar('Failed to update: $e', isErr: true);
    } finally {
      if (mounted) {
        setState(() {
          isUpdatingSkip = false;
        });
      }
    }
  }

  Future<void> _handleDoneAndSkip(int status) async {
    if (isUpdatingDone) return;

    setState(() => isUpdatingDone = true);

    try {
      bool hasNet = await hasInternet;
      if (!hasNet) {
        Utilis.showSnackBar('Please enable internet', isErr: true);
        return;
      }

      // Update with appropriate status
      await StreaksData.updateDoneAndSkip(status);
      await StreaksData.fetchData().then((d) {
        currentTimer.value = d;
      });

      Utilis.showToast('Great job! Keep going! 💪');
      if (mounted) {
        Navigator.of(context).pop();
        // Call the callback to trigger parent rebuild
      }
    } catch (e) {
      Utilis.showSnackBar('Failed to update: $e', isErr: true);
    } finally {
      if (mounted) setState(() => isUpdatingDone = false);
    }
  }

  Widget _buildButton(String txt, Function fun, bool isUpdating, [Color? clr]) {
    return Expanded(
      child: ElevatedButton(
        onPressed: isUpdating ? null : () => fun(),
        style: ElevatedButton.styleFrom(
          backgroundColor: clr ?? Colors.deepPurple,
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
            : Text(txt),
      ),
    );
  }
}

class CompactHeatMap extends StatelessWidget {
  const CompactHeatMap({super.key});

  @override
  Widget build(BuildContext context) {
    return HeatMapCalendar(
      defaultColor: Colors.white,
      flexible: true,
      colorMode: ColorMode.color,
      datasets: StreaksData.getHeatmapData(),
      showColorTip: false,
      textColor: Colors.black54,
      size: 30,
      initDate: DateTime.now(),
      colorsets: {
        0: Color(0xFF7F1019).withValues(alpha: 0.5), // Relapsed
        2: Colors.grey,
        3: Color.fromARGB(255, 139, 89, 225), // Success (purple)
      },
    );
  }
}
