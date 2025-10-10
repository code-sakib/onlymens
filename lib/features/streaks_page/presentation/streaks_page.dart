import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:onlymens/core/app_error.dart';
import 'package:onlymens/core/apptheme.dart';
import 'package:onlymens/core/globals.dart';
import 'package:onlymens/utilis/size_config.dart';
import 'package:onlymens/utilis/snackbar.dart';

class StreaksPage extends StatefulWidget {
  const StreaksPage({super.key});

  @override
  State<StreaksPage> createState() => _StreaksPageState();
}

class _StreaksPageState extends State<StreaksPage> {
  // controls whether the small heatmap popup is visible
  bool _showSmallHeatmap = false;

  // approximate right offset for the small popup; tweak if needed
  final double _popupRight = 16;
  final double _popupTopOffset = 10; // below the nav bar by default

  void _toggleSmallHeatmap() =>
      setState(() => _showSmallHeatmap = !_showSmallHeatmap);
  void _hideSmallHeatmap() {
    if (_showSmallHeatmap) setState(() => _showSmallHeatmap = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CupertinoNavigationBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // calendar button toggles the small heatmap popup
            IconButton(
              onPressed: _toggleSmallHeatmap,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedCalendar03,
                color: Colors.white,
              ),
            ),

            IconButton(
              onPressed: () {},
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedUserCircle,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // main content
          SingleChildScrollView(
            child: Center(
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Scaffold.of(context).openDrawer(),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedAlien01,
                          color: Colors.white,
                          size: 150,
                          strokeWidth: 1,
                        ),
                      ),
                      PornFreeTimerCompact(startTime: DateTime(2025, 10, 1)),
                    ],
                  ),
                  const DaysList(),
                  secondRowButtons(),
                  const SizedBox(height: 300),
                ],
              ),
            ),
          ),

          // Small heatmap popup anchored to top-right (just below nav bar)
          // It's not a dialog — it's a small card that appears anchored.
          if (_showSmallHeatmap)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // Tapping anywhere outside the small card hides it
                onTap: _hideSmallHeatmap,
                child: Stack(
                  children: [
                    // The small popup itself; taps here are absorbed so they
                    // don't dismiss the popup
                    Positioned(
                      top: _popupTopOffset,
                      right: _popupRight,
                      child: GestureDetector(
                        onTap: () {}, // absorb taps
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
                              children: const [
                                // compact heatmap view — small size, no color tip
                                CompactHeatMap(),
                              ],
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

      drawer: Drawer(width: SizeConfig.screenWidth / 1.5),
    );
  }

  secondRowButtons() {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: () => GoRouter.of(context).push('/affirmations'),
            label: const Icon(
              Icons.local_library,
              color: Colors.black,
              size: 20,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple[600],
              shape: const CircleBorder(),
            ),
          ),
          PanicButton(onTriggered: () {}),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                isGuest = false; // Reset guest mode
                await auth.signOut();
                if (context.mounted) {
                  context.go('/'); // Correct route
                }
              } on AppError catch (e) {
                if (context.mounted) {
                  Utilis.showSnackBar(e.userMessage, isErr: true);
                }
              }
            },
            label: Image.asset('assets/streaks/medi.png', height: 20),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple[600],
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class PanicButton extends StatefulWidget {
  final VoidCallback onTriggered;
  const PanicButton({super.key, required this.onTriggered});

  @override
  State<PanicButton> createState() => _PanicButtonState();
}

class _PanicButtonState extends State<PanicButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  bool _isTriggered = false;
  bool _isProcessing = false;

  late AnimationController _timerController;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _onTriggered();
    });
  }

  Future<void> _onTriggered() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isTriggered = true;
      _isPressed = false;
      _isProcessing = true;
    });

    Utilis.showToast('Panic Mode Activated!');

    await Future.delayed(const Duration(milliseconds: 1000));

    if (mounted) {
      GoRouter.of(context).push('/panicpg');
    }

    setState(() {
      _isProcessing = false;
      _isTriggered = false;
    });
  }

  void _startTimer() {
    if (_isProcessing) return;
    setState(() {
      _isPressed = true;
      _isTriggered = false;
    });
    _timerController.forward(from: 0);
  }

  void _cancelTimer() {
    if (!_isPressed || _isTriggered) return;
    _timerController.reverse();
    setState(() => _isPressed = false);
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const borderRadius = 20.0;

    return Center(
      child: GestureDetector(
        onTapDown: (_) => _startTimer(),
        onTapUp: (_) => _cancelTimer(),
        onTapCancel: _cancelTimer,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Animated glowing rectangular border
            AnimatedBuilder(
              animation: _timerController,
              builder: (context, _) {
                return Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      if (_isPressed)
                        BoxShadow(
                          color: Colors.redAccent.withAlpha(
                            (0.5 + _timerController.value * 0.5 * 255).toInt(),
                          ),
                          blurRadius: 12,
                          spreadRadius: 1.5,
                        ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _RectBorderPainter(
                      progress: _timerController.value,
                      color: Colors.redAccent,
                      borderRadius: borderRadius,
                    ),
                    child: const SizedBox(width: 150, height: 50),
                  ),
                );
              },
            ),

            // Actual Panic button
            AnimatedScale(
              scale: _isPressed ? 0.97 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Opacity(
                opacity: _isProcessing ? 0.7 : 1,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 102, 25, 25),
                    foregroundColor: Colors.white,
                    fixedSize: const Size(150, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    elevation: 0,
                  ),
                  child: Text(
                    _isProcessing ? 'Processing...' : 'Panic Mode',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Custom Painter: Draws an animated rectangular border filling clockwise
/// ---------------------------------------------------------------------------
class _RectBorderPainter extends CustomPainter {
  final double progress; // 0 → 1
  final Color color;
  final double borderRadius;

  _RectBorderPainter({
    required this.progress,
    required this.color,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final totalPerimeter =
        2 * (size.width + size.height - 4 * borderRadius + pi * borderRadius);
    final currentLength = totalPerimeter * progress;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final path = Path()..addRRect(rect);
    final metrics = path.computeMetrics().first;

    final extractPath = metrics.extractPath(0, currentLength);
    canvas.drawPath(extractPath, paint);
  }

  @override
  bool shouldRepaint(covariant _RectBorderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class DaysList extends StatelessWidget {
  const DaysList({super.key});

  static const listOfDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static ValueNotifier<int?> selectedDay = ValueNotifier(null);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ValueListenableBuilder<int?>(
        valueListenable: selectedDay,
        builder: (context, value, child) {
          final mL = List.generate(5, (i) => i);
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: listOfDays.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  selectedDay.value = index;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 8,
                  ),
                  margin: const EdgeInsets.all(4),
                  constraints: BoxConstraints.tight(Size(50, 60)),
                  decoration: BoxDecoration(
                    color: selectedDay.value == index || mL.contains(index)
                        ? AppColors.primary
                        : Colors.transparent,
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        width: 3,
                      ),
                      left: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        width: 1,
                      ),
                      right: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        width: 1,
                      ),
                      top: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(listOfDays[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// CompactHeatMap: small, tight heatmap used in the top-right popup
class CompactHeatMap extends StatelessWidget {
  const CompactHeatMap({super.key});

  Map<DateTime, int> _genData() {
    final now = DateTime.now();
    return {
      for (var i = 0; i < 20; i++)
        DateTime(now.year, now.month, (i % 28) + 1): (i % 5) + 1,
    };
  }

  @override
  Widget build(BuildContext context) {
    return HeatMapCalendar(
      defaultColor: Colors.white,
      flexible: true,
      colorMode: ColorMode.color,
      datasets: {}..addAll(_genData()),
      showColorTip: false,
      textColor: Colors.black54,
      size: 30,
      initDate: DateTime.now(),
      colorsets: const {1: Color.fromARGB(255, 139, 89, 225)},
    );
  }
}

class AppHeatMap extends StatelessWidget {
  const AppHeatMap({super.key});

  @override
  Widget build(BuildContext context) {
    Map<DateTime, int> genFSept() {
      return {
        for (var item in List.generate(30, (index) => index + 1))
          DateTime(2025, 9, item): (item) % 5 == 0 ? 0 : (item) % 5,
      };
    }

    return SizedBox(
      width: SizeConfig.screenWidth / 2,
      child: HeatMapCalendar(
        defaultColor: Colors.white,
        flexible: true,
        colorMode: ColorMode.color,
        datasets: {}..addAll(genFSept()),
        showColorTip: false,
        textColor: Colors.black54,
        size: 80,
        initDate: DateTime.now(),
        colorsets: const {1: Color.fromARGB(255, 139, 89, 225)},
      ),
    );
  }
}

class PornFreeTimerCompact extends StatefulWidget {
  final DateTime startTime;
  const PornFreeTimerCompact({super.key, required this.startTime});

  @override
  State<PornFreeTimerCompact> createState() => _PornFreeTimerCompactState();
}

class _PornFreeTimerCompactState extends State<PornFreeTimerCompact> {
  late Timer _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.startTime);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed = DateTime.now().difference(widget.startTime);
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = _elapsed.inDays;
    final hours = _elapsed.inHours % 24;
    final minutes = _elapsed.inMinutes % 60;
    final seconds = _elapsed.inSeconds % 60;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 🕒 Timer Text
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("You've been porn free for.."),
            // Days & Hours
            Text(
              "$days days  $hours hrs",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            // Minutes & Seconds
            Text(
              "$minutes min  $seconds sec",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
