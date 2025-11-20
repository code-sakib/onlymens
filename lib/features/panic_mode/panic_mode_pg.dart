import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:cleanmind/features/panic_mode/panicm_service.dart';
import 'package:cleanmind/features/streaks_page/data/streaks_data.dart';
import 'package:cleanmind/utilis/snackbar.dart';

// ============================================
// PANIC MODE PAGE (Online API Integration - No Timer)
// ============================================
class PanicModePg extends StatefulWidget {
  const PanicModePg({super.key});

  @override
  State<PanicModePg> createState() => _PanicModePgState();
}

class _PanicModePgState extends State<PanicModePg> {
  final PanicModeService _panicModeService = PanicModeService();
  String? _mainText;
  String? _guidanceText;
  bool _isLoading = true;
  bool _showGuidanceCard = false;

  @override
  void initState() {
    super.initState();
    _loadGuidance();

    // Auto show/hide guidance card
    // Auto show/hide guidance card
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _showGuidanceCard = true);
      Future.delayed(const Duration(seconds: 6), () {
        if (!mounted) return;
        setState(() => _showGuidanceCard = false);
      });
    });
  }

  Future<void> _loadGuidance() async {
    try {
      final response = await _panicModeService.generateGuidance(
        currentStreak: glbCurrentStreakDays,
        longestStreak: glbTotalDoneDays,
      );

      if (!mounted) return;
      setState(() {
        _mainText = response.mainText; // FETCH ONLY MAIN TEXT
        _guidanceText = _getFallbackGuidanceText(); // ALWAYS DEFAULT GUIDANCE
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error: $e');

      if (!mounted) return;
      setState(() {
        _mainText = _getFallbackMainText(); // USE FALLBACK MAIN ONLY
        _guidanceText = _getFallbackGuidanceText(); // ALWAYS DEFAULT GUIDANCE
        _isLoading = false;
      });
    }
  }

  String _getFallbackMainText() {
    final streak = glbCurrentStreakDays;
    return streak > 0
        ? "You've shown incredible strength for $streak days straight. That's not luck — that's YOU choosing growth over instant gratification.\n\nWhat you're feeling right now? It's just brain chemistry lying to you. These thoughts aren't facts — they're echoes of old patterns trying to pull you back.\n\nYou've already proven you're stronger than this urge $streak times. Right now, in this moment, you have all the power. The urge will pass. Your progress is real."
        : "You've taken the hardest step — deciding to change. That alone shows incredible courage.\n\nThis urge you're feeling is your brain's old wiring trying to fire up. But you're rewiring it right now, in this very moment.\n\nYou have the power to let this pass. The thoughts aren't commands — they're just noise. Stay here. Breathe. This will pass.";
  }

  String _getFallbackGuidanceText() {
    return "Take slow, deep breaths. It's okay if your mind is racing. Don't fight the thoughts; just let the words above pass through your mind and subtly believe in them.";
  }

  void _handleBack() {
    Utilis.showSnackBar('Keep going strong..💪');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final topBarHeight = 56.h;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ==========================
          // BACKGROUND MAIN TEXT AREA
          // ==========================
          Positioned.fill(
            child: _isLoading
                ? Center(
                    child: CupertinoActivityIndicator(
                      radius: 16.r,
                      color: Colors.grey,
                    ),
                  )
                : SmoothBuildText(text: _mainText ?? ''),
          ),

          // ==========================
          // TOP BAR
          // ==========================
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                height: topBarHeight,
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: _handleBack,
                      icon: Icon(
                        CupertinoIcons.back,
                        color: Colors.white54,
                        size: 26.r,
                      ),
                    ),

                    // Info button
                    IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => setState(
                        () => _showGuidanceCard = !_showGuidanceCard,
                      ),
                      icon: Icon(
                        _showGuidanceCard ? Icons.info : Icons.info_outline,
                        color: _showGuidanceCard
                            ? Colors.deepPurpleAccent
                            : Colors.grey,
                        size: 24.r,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ==========================
          // GUIDANCE CARD (bottom)
          // ==========================
          if (_showGuidanceCard && _guidanceText != null)
            Positioned(
              left: 20.w,
              right: 20.w,
              bottom: 0,
              child: SafeArea(
                child: GuidanceCard(
                  text: _guidanceText!,
                  onClose: () => setState(() => _showGuidanceCard = false),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================
// SMOOTH BUILD TEXT (gradual character reveal + auto-scroll)
// ============================================
class SmoothBuildText extends StatefulWidget {
  final String text;
  final int initialSpeed; // ms per character (slow start)
  final int finalSpeed; // ms per character (fast end)
  final double opacity;

  const SmoothBuildText({
    super.key,
    required this.text,
    this.initialSpeed = 80,
    this.finalSpeed = 70,
    this.opacity = 0.7,
  });

  @override
  State<SmoothBuildText> createState() => _SmoothBuildTextState();
}

class _SmoothBuildTextState extends State<SmoothBuildText> {
  final ScrollController _scrollController = ScrollController();
  String _displayedText = '';
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_started) {
        _started = true;
        _animateTyping();
      }
    });
  }

  Future<void> _animateTyping() async {
    final chars = widget.text.split('');

    for (int i = 0; i < chars.length; i++) {
      if (!mounted) return;

      setState(() {
        _displayedText = widget.text.substring(0, i + 1);
      });

      // Auto-scroll as new text appears
      await Future.delayed(const Duration(milliseconds: 10));
      _scrollToBottom();

      final progress = i / chars.length;
      int currentSpeed;

      if (progress < 0.3) {
        currentSpeed = widget.initialSpeed;
      } else {
        final factor = (progress - 0.3) / 0.7;
        currentSpeed =
            (widget.initialSpeed -
                    (widget.initialSpeed - widget.finalSpeed) * factor)
                .round();
      }

      await Future.delayed(Duration(milliseconds: currentSpeed));
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(20.w, 50.h, 20.w, 10.h),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          _displayedText,
          style: TextStyle(
            fontSize: 26.sp,
            height: 1.8,
            color: Color.fromRGBO(255, 255, 255, widget.opacity),
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// ============================================
// GUIDANCE CARD
// ============================================
class GuidanceCard extends StatelessWidget {
  final String text;
  final VoidCallback onClose;

  const GuidanceCard({super.key, required this.text, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: Colors.deepPurpleAccent.withValues(alpha: 0.3),
            width: 1.w,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedSparkles,
              color: Colors.deepPurpleAccent,
              size: 20.r,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Guidance',
                    style: TextStyle(
                      color: Colors.deepPurpleAccent,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    text,
                    softWrap: true,
                    style: TextStyle(
                      color: Colors.grey.shade300,
                      fontSize: 13.sp,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: Icon(Icons.close, color: Colors.grey, size: 20.r),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
