import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gaimon/gaimon.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cleanmind/core/globals.dart';
import 'package:cleanmind/features/avatar/avatar_pg.dart';
import 'package:cleanmind/features/streaks_page/presentation/pTimer.dart';
import 'package:cleanmind/guides/blogs.dart';
import 'package:cleanmind/guides/guides_pg.dart';
import 'package:cleanmind/utilis/snackbar.dart';

class StreaksPage extends StatefulWidget {
  const StreaksPage({super.key});

  @override
  State<StreaksPage> createState() => _StreaksPageState();
}

class _StreaksPageState extends State<StreaksPage> {
  @override
  void initState() {
    currentUser = auth.currentUser!;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 400.h, child: TimerComponents()),

            secondRowButtons(context),
            SizedBox(height: 24.h),

            const DominatingThoughtsWidget(),
            SizedBox(height: 24.h),

            const DailyMotivationWidget(),
            SizedBox(height: 24.h),

            FutureBuilder<List<BlogPost>>(
              future: BlogManager.fetchTodayBlogs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CupertinoActivityIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return fallbackBlogs(context);
                }

                final blogs = snapshot.data!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 16.w),
                      child: Text(
                        'Latest Researches',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: blogs.length,
                      itemBuilder: (context, index) {
                        final blog = blogs[index];
                        return blogCard(context, blog.toJson());
                      },
                    ),
                  ],
                );
              },
            ),

            SizedBox(height: 24.h),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 16.w),
                  child: Text(
                    'Level Tips',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                LevelGuideTipsWidget(),
                SizedBox(height: 30.h),
              ],
            ),
          ],
        ),
      ),
      drawer: AvatarLevelsDrawer(),
    );
  }
}

secondRowButtons(BuildContext context) {
  return Padding(
    padding: EdgeInsets.all(10.r),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: () => context.push('/affirmations'),
          label: HugeIcon(icon: HugeIcons.strokeRoundedBookEdit, size: 20.r),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple[600],
            shape: const CircleBorder(),
          ),
        ),
        PanicButton(onTriggered: () {}),
        ElevatedButton.icon(
          onPressed: () async {
            context.push('/meditation');
          },
          label: HugeIcon(icon: HugeIcons.strokeRoundedRelieved01, size: 20.r),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple[600],
            shape: const CircleBorder(),
          ),
        ),
      ],
    ),
  );
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
    Gaimon.selection();

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

    HapticFeedback.heavyImpact();

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
    final borderRadius = 20.r;

    return Center(
      child: GestureDetector(
        onTapDown: (_) => _startTimer(),
        onTapUp: (_) => _cancelTimer(),
        onTapCancel: _cancelTimer,
        child: Stack(
          alignment: Alignment.center,
          children: [
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
                          blurRadius: 12.r,
                          spreadRadius: 1.5.r,
                        ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _RectBorderPainter(
                      progress: _timerController.value,
                      color: Colors.redAccent,
                      borderRadius: borderRadius,
                    ),
                    child: SizedBox(width: 150.w, height: 50.h),
                  ),
                );
              },
            ),
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
                    fixedSize: Size(150.w, 50.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                    side: BorderSide(color: Colors.red, width: 1.5.w),
                    elevation: 0,
                  ),
                  child: Text(
                    _isProcessing ? 'Activating...' : 'Relapsing?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
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

class _RectBorderPainter extends CustomPainter {
  final double progress;
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
