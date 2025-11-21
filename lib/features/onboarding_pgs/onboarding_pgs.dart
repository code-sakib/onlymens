// onboarding_screen.dart — FINAL RESPONSIVE VERSION

import 'dart:async';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Added ScreenUtil
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:cleanmind/core/apptheme.dart';
import 'package:uuid/uuid.dart';

// Import your other pages (StatusPage, EffectsPage, etc.) here
// assuming they are in the same file or imported correctly.
// If they are in this file, apply ScreenUtil to them similarly.

// ============================================================================
// MAIN ONBOARDING WIDGET
// ============================================================================

final Map<String, dynamic> obSelectedValues = {};

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Answers storage
  String? frequency;
  List<String> effects = [];
  String? customEffect;
  List<String> triggers = [];
  String? customTrigger;
  List<String> aspects = [];
  String? aspectDetails;

  static const int totalPages = 6;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _nextPage() {
    if (_currentPage < totalPages - 1) {
      _goToPage(_currentPage + 1);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _goToPage(_currentPage - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          children: [
            WelcomePage(pageIndex: 0, onNext: _nextPage, onBack: _previousPage),

            // NOTE: Ensure StatusPage, EffectsPage, TriggersPage, GoalsPage
            // are also updated with ScreenUtil in their respective definitions.
            StatusPage(
              pageIndex: 1,
              onNext: _nextPage,
              onBack: _previousPage,
              selectedFrequency: frequency,
              onFrequencyChanged: (value) => setState(() => frequency = value),
            ),
            EffectsPage(
              pageIndex: 2,
              onNext: _nextPage,
              onBack: _previousPage,
              selectedEffects: effects,
              customEffect: customEffect,
              onEffectsChanged: (val) => setState(() => effects = val),
              onCustomEffectChanged: (val) =>
                  setState(() => customEffect = val),
            ),
            TriggersPage(
              pageIndex: 3,
              onNext: _nextPage,
              onBack: _previousPage,
              selectedTriggers: triggers,
              customTrigger: customTrigger,
              onTriggersChanged: (val) => setState(() => triggers = val),
              onCustomTriggerChanged: (val) =>
                  setState(() => customTrigger = val),
            ),
            GoalsPage(
              pageIndex: 4,
              onNext: _nextPage,
              onBack: _previousPage,
              selectedAspects: aspects,
              aspectDetails: aspectDetails,
              onAspectsChanged: (val) => setState(() => aspects = val),
              onAspectDetailsChanged: (val) =>
                  setState(() => aspectDetails = val),
            ),

            ReportPage(
              pageIndex: 5,
              onNext: () async {
                if (context.mounted) {
                  context.push('/pricing');
                }
              },
              onBack: _previousPage,
              frequency: frequency ?? 'Not specified',
              effects: effects,
              customEffect: customEffect,
              triggers: triggers,
              customTrigger: customTrigger,
              aspects: aspects,
              aspectDetails: aspectDetails,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// BASE PAGE STRUCTURE (Responsive)
// ============================================================================
class BasePage extends StatelessWidget {
  final int pageIndex;
  final String headerTitle;
  final String bigTitle;
  final String subtitle;
  final Widget content;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final bool isNextEnabled;
  final String nextButtonText;

  const BasePage({
    super.key,
    required this.pageIndex,
    required this.headerTitle,
    required this.bigTitle,
    required this.subtitle,
    required this.content,
    required this.onNext,
    required this.onBack,
    this.isNextEnabled = true,
    this.nextButtonText = 'Continue',
  });

  @override
  Widget build(BuildContext context) {
    final progressPages = 4;
    final currentProgressPage = pageIndex == 0
        ? 0
        : (pageIndex >= 5 ? 4 : pageIndex);
    final progress = currentProgressPage / progressPages;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.background,
            AppColors.background,
          ],
          stops: const [0, 0.3, 1],
        ),
      ),
      child: Column(
        children: [
          // Top Bar
          SizedBox(
            height: 44.h,
            child: Row(
              children: [
                if (pageIndex > 0)
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: 24.r,
                    ),
                    onPressed: onBack,
                  )
                else
                  SizedBox(width: 48.w),
                Expanded(
                  child: Text(
                    headerTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(width: 48.w),
              ],
            ),
          ),

          // Progress Indicator
          if (pageIndex != 0 && pageIndex != 5) ...[
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2.r),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  minHeight: 4.h,
                ),
              ),
            ),

            SizedBox(height: 32.h),
          ] else ...[
            SizedBox(height: 24.h),
          ],

          // Title & Subtitle
          bigTitle.isNotEmpty
              ? Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bigTitle,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        SizedBox(height: 8.h),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 16.sp,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : SizedBox.shrink(),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.r),
              child: content,
            ),
          ),

          // Next Button
          Padding(
            padding: EdgeInsets.all(20.r),
            child: SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton(
                onPressed: isNextEnabled
                    ? () {
                        HapticFeedback.mediumImpact();
                        onNext();
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: Colors.white30,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  nextButtonText,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// REPORT PAGE WITH AI INSIGHTS AND GRAPH (Responsive)
// ============================================================================
class ReportPage extends StatefulWidget {
  final int pageIndex;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final String frequency;
  final List<String> effects;
  final String? customEffect;
  final List<String> triggers;
  final String? customTrigger;
  final List<String> aspects;
  final String? aspectDetails;

  const ReportPage({
    super.key,
    required this.pageIndex,
    required this.onNext,
    required this.onBack,
    required this.frequency,
    required this.effects,
    this.customEffect,
    required this.triggers,
    this.customTrigger,
    required this.aspects,
    this.aspectDetails,
  });

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String _aiInsight = '';
  int _estimatedDays = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _generateReport();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('device_id');
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString('device_id', id);
    }
    return id;
  }

  Future<void> _generateReport() async {
    try {
      final deviceId = await getDeviceId();
      final effectsList = [
        ...widget.effects,
        if (widget.customEffect?.isNotEmpty == true) widget.customEffect!,
      ];
      final triggersList = [
        ...widget.triggers,
        if (widget.customTrigger?.isNotEmpty == true) widget.customTrigger!,
      ];

      final callable = FirebaseFunctions.instance.httpsCallable(
        'generateOnboardingReport',
      );
      final result = await callable.call({
        'deviceId': deviceId,
        'frequency': widget.frequency,
        'effects': effectsList,
        'triggers': triggersList,
        'goals': widget.aspects,
        'goalDetails': widget.aspectDetails,
      });

      if (mounted) {
        setState(() {
          _aiInsight = result.data['insight'] ?? 'Keep moving forward! 💪';
          _estimatedDays = result.data['estimatedDays'] ?? _getDefaultDays();
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      debugPrint('Error generating report: $e');
      if (mounted) {
        setState(() {
          _aiInsight = _getFallbackInsight();
          _estimatedDays = _getDefaultDays();
          _isLoading = false;
        });
        _animationController.forward();
      }
    }
  }

  int _getDefaultDays() {
    final freq = widget.frequency.toLowerCase();
    if (freq == 'never') return 15;
    if (freq == 'occasionally') return 25;
    if (freq == 'frequently') return 35;
    if (freq == 'daily') return 45;
    return 7;
  }

  String _getFallbackInsight() {
    if (widget.frequency.toLowerCase() == 'never') {
      return "You're already doing great! 🌟\n\nYour awareness and commitment to self-improvement are impressive. Continue nurturing your focus and building on the strong foundation you've created. The habits you're forming now will compound into remarkable growth over time.";
    }
    return "You've taken the most important step — recognizing the need for change. 💪\n\nThe path ahead won't always be easy, but every day of progress builds momentum. Stay consistent, track your patterns, and remember: you're stronger than any urge. Better days are coming.";
  }

  List<ChartData> _getChartData() {
    return [
      ChartData(0, 20),
      ChartData(_estimatedDays * 0.2, 25),
      ChartData(_estimatedDays * 0.4, 45),
      ChartData(_estimatedDays * 0.6, 65),
      ChartData(_estimatedDays * 0.8, 75),
      ChartData(_estimatedDays.toDouble(), 85),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      pageIndex: widget.pageIndex,
      headerTitle: 'Your Personalized Report',
      bigTitle: '',
      subtitle: '',
      onNext: widget.onNext,
      onBack: widget.onBack,
      nextButtonText: 'Continue',
      content: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CupertinoActivityIndicator(
                    color: AppColors.primary,
                    radius: 14.r,
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'Analyzing your journey...',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 16.sp,
                    ),
                  ),
                ],
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Your Growth Trajectory',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // Chart Card
                  Container(
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Growth Progress',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_estimatedDays != 7)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 6.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Text(
                                  '$_estimatedDays days',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else
                              const SizedBox(),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        SizedBox(
                          height: 200.h,
                          child: SfCartesianChart(
                            plotAreaBorderWidth: 0,
                            primaryXAxis: NumericAxis(
                              isVisible: true,
                              majorGridLines: const MajorGridLines(width: 0),
                              axisLine: const AxisLine(width: 0),
                              labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12.sp,
                              ),
                            ),
                            primaryYAxis: NumericAxis(
                              isVisible: true,
                              majorGridLines: MajorGridLines(
                                width: 1,
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                              axisLine: const AxisLine(width: 0),
                              labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12.sp,
                              ),
                              labelFormat: '{value}%',
                            ),
                            series: <CartesianSeries<ChartData, double>>[
                              SplineAreaSeries<ChartData, double>(
                                dataSource: _getChartData(),
                                xValueMapper: (ChartData data, _) => data.x,
                                yValueMapper: (ChartData data, _) => data.y,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.4),
                                    AppColors.primary.withValues(alpha: 0.0),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderColor: AppColors.primary,
                                borderWidth: 3.w,
                                animationDuration: 2000,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // AI Insight Card
                  Container(
                    padding: EdgeInsets.all(20.r),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.1),
                          AppColors.background,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedSparkles,
                              color: AppColors.primary,
                              size: 24.r,
                            ),

                            SizedBox(width: 8.w),
                            Text(
                              'Path ahead',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          _aiInsight,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 15.sp,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class ChartData {
  final double x;
  final double y;
  ChartData(this.x, this.y);
}

// ============================================================================
// WELCOME PAGE (Responsive)
// ============================================================================

class WelcomePage extends StatefulWidget {
  final int pageIndex;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const WelcomePage({
    super.key,
    required this.pageIndex,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  @override
  Widget build(BuildContext context) {
    return BasePage(
      pageIndex: widget.pageIndex,
      headerTitle: 'CleanMind',
      bigTitle: '',
      subtitle: '',
      onNext: widget.onNext,
      onBack: widget.onBack,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 50.h,
            child: AnimatedTextKit(
              onNext: (index, isLast) {
                HapticFeedback.mediumImpact();
              },
              totalRepeatCount: 1,
              animatedTexts: [
                TyperAnimatedText(
                  'Quit porn — escape brain rot, gain clarity and use your mind at its best again. ',
                  textStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 16.sp,
                    height: 1.5.h,
                  ),
                ),
              ],
            ),
          ),

          // Lottie Animation
          SizedBox(
            height: 250.h,
            child: Lottie.asset(
              'assets/lottie/oblottie.json',
              fit: BoxFit.contain,
            ),
          ),

          _buildFeatureCard(
            description:
                'Block porn on websites — cut off the triggers, reclaim focus, and protect your mind from slipping back into old loops.',
          ),

          SizedBox(height: 12.h),

          _buildFeatureCard(
            description:
                'Rise and unlock avatar-based achievements that make your self-growth journey truely exciting and rewarding.',
          ),

          SizedBox(height: 12.h),

          _buildFeatureCard(
            description:
                'Advanced AI models that act like a friend — trained to understand the situation, talk you through tough moments, and guide you with voice or chat.',
          ),

          SizedBox(height: 12.h),

          _buildFeatureCard(
            description:
                'Meet people on a similar journey. Share hurdles, support each other and stay accountable.',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({required String description}) {
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 12.r,
            offset: Offset(0, 3.h),
          ),
        ],
      ),
      child: Text(
        description,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.88),
          fontSize: 15.sp,
          height: 1.45,
        ),
      ),
    );
  }
}

// ============================================================================
// STATUS PAGE
// ============================================================================
class StatusPage extends StatelessWidget {
  final int pageIndex;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final String? selectedFrequency;
  final ValueChanged<String> onFrequencyChanged;

  const StatusPage({
    super.key,
    required this.pageIndex,
    required this.onNext,
    required this.onBack,
    required this.selectedFrequency,
    required this.onFrequencyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BasePage(
      pageIndex: pageIndex,
      headerTitle: 'About You',
      bigTitle: 'What best describes your current pornography content use?',
      subtitle: 'Choose the best match',
      onNext: () {
        onNext();
        // Ensure obSelectedValues is accessible here
        obSelectedValues.addAll({'0': selectedFrequency});
      },
      onBack: onBack,
      isNextEnabled: true,
      content: Column(
        children: [
          RadioCard(
            title: 'Daily',
            isSelected: selectedFrequency == 'Daily',
            onTap: () => onFrequencyChanged('Daily'),
          ),
          SizedBox(height: 16.h),
          RadioCard(
            title: 'Frequently',
            isSelected: selectedFrequency == 'Frequently',
            onTap: () => onFrequencyChanged('Frequently'),
          ),
          SizedBox(height: 16.h),
          RadioCard(
            title: 'Occasionally',
            isSelected: selectedFrequency == 'Occasionally',
            onTap: () => onFrequencyChanged('Occasionally'),
          ),
          SizedBox(height: 16.h),
          RadioCard(
            title: 'Never',
            isSelected: selectedFrequency == 'Never',
            onTap: () => onFrequencyChanged('Never'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EFFECTS PAGE
// ============================================================================
class EffectsPage extends StatefulWidget {
  final int pageIndex;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final List<String> selectedEffects;
  final String? customEffect;
  final ValueChanged<List<String>> onEffectsChanged;
  final ValueChanged<String?> onCustomEffectChanged;

  const EffectsPage({
    super.key,
    required this.pageIndex,
    required this.onNext,
    required this.onBack,
    required this.selectedEffects,
    required this.customEffect,
    required this.onEffectsChanged,
    required this.onCustomEffectChanged,
  });

  @override
  State<EffectsPage> createState() => _EffectsPageState();
}

class _EffectsPageState extends State<EffectsPage> {
  final effectOptions = [
    'Impaired concentration',
    'Reduced creativity',
    'Sleep disturbances',
    'Apathy',
    'Relationship difficulties',
    'Lowered self-esteem',
  ];

  void _toggleEffect(String effect) {
    final newEffects = List<String>.from(widget.selectedEffects);
    if (newEffects.contains(effect)) {
      newEffects.remove(effect);
    } else {
      newEffects.add(effect);
    }
    widget.onEffectsChanged(newEffects);
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      pageIndex: widget.pageIndex,
      headerTitle: 'Possible effects',
      bigTitle: 'How has pornography affected you?',
      subtitle: '',
      onNext: () {
        widget.onNext();
        obSelectedValues.addAll({
          '1': [widget.selectedEffects, widget.customEffect],
        });
      },
      onBack: widget.onBack,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio:
                  2.2, // Aspect ratio usually doesn't need scaling
            ),
            itemCount: effectOptions.length,
            itemBuilder: (context, index) {
              final option = effectOptions[index];
              return MultiSelectCard(
                title: option,
                isSelected: widget.selectedEffects.contains(option),
                onTap: () => _toggleEffect(option),
              );
            },
          ),

          SizedBox(height: 12.h),

          CustomInputCard(
            hintText: 'Other effects (optional)',
            onChanged: widget.onCustomEffectChanged,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TRIGGERS PAGE
// ============================================================================
class TriggersPage extends StatefulWidget {
  final int pageIndex;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final List<String> selectedTriggers;
  final String? customTrigger;
  final ValueChanged<List<String>> onTriggersChanged;
  final ValueChanged<String?> onCustomTriggerChanged;

  const TriggersPage({
    super.key,
    required this.pageIndex,
    required this.onNext,
    required this.onBack,
    required this.selectedTriggers,
    required this.customTrigger,
    required this.onTriggersChanged,
    required this.onCustomTriggerChanged,
  });

  @override
  State<TriggersPage> createState() => _TriggersPageState();
}

class _TriggersPageState extends State<TriggersPage> {
  final triggerOptions = [
    'When alone',
    'Under stress',
    'Boredom',
    'Anxiety',
    'Late-night hours',
    'After feeling lonely',
  ];

  void _toggleTrigger(String trigger) {
    final newTriggers = List<String>.from(widget.selectedTriggers);
    if (newTriggers.contains(trigger)) {
      newTriggers.remove(trigger);
    } else {
      newTriggers.add(trigger);
    }
    widget.onTriggersChanged(newTriggers);
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      pageIndex: widget.pageIndex,
      headerTitle: 'Situations',
      bigTitle: 'Situations when you are most likely to engage',
      subtitle: '',
      onNext: () {
        widget.onNext();
        obSelectedValues.addAll({
          '2': [widget.selectedTriggers, widget.customTrigger],
        });
      },
      onBack: widget.onBack,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio: 2.2,
            ),
            itemCount: triggerOptions.length,
            itemBuilder: (context, index) {
              final option = triggerOptions[index];
              return MultiSelectCard(
                title: option,
                isSelected: widget.selectedTriggers.contains(option),
                onTap: () => _toggleTrigger(option),
              );
            },
          ),

          SizedBox(height: 12.h),

          CustomInputCard(
            hintText: 'Other situations (optional)',
            onChanged: widget.onCustomTriggerChanged,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// GOALS PAGE
// ============================================================================
class GoalsPage extends StatefulWidget {
  final int pageIndex;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final List<String> selectedAspects;
  final String? aspectDetails;
  final ValueChanged<List<String>> onAspectsChanged;
  final ValueChanged<String?> onAspectDetailsChanged;

  const GoalsPage({
    super.key,
    required this.pageIndex,
    required this.onNext,
    required this.onBack,
    required this.selectedAspects,
    required this.aspectDetails,
    required this.onAspectsChanged,
    required this.onAspectDetailsChanged,
  });

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  final aspectOptions = [
    'Strengthen self-discipline',
    'Develop mental resilience',
    'Cultivate inner peace',
    'Build self-confidence',
    'Enhance focus and productivity',
    'Improve relationships',
  ];

  void _toggleAspect(String aspect) {
    final newAspects = List<String>.from(widget.selectedAspects);
    if (newAspects.contains(aspect)) {
      newAspects.remove(aspect);
    } else {
      newAspects.add(aspect);
    }
    widget.onAspectsChanged(newAspects);
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      pageIndex: widget.pageIndex,
      headerTitle: 'Your Growth Goals',
      bigTitle: 'In this area, you would like to:',
      subtitle: '',
      onNext: () {
        widget.onNext();
        obSelectedValues.addAll({
          '3': [widget.selectedAspects, widget.aspectDetails],
        });
      },
      onBack: widget.onBack,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio: 2.0,
            ),
            itemCount: aspectOptions.length,
            itemBuilder: (context, index) {
              final option = aspectOptions[index];
              return MultiSelectCard(
                title: option,
                isSelected: widget.selectedAspects.contains(option),
                onTap: () => _toggleAspect(option),
              );
            },
          ),

          SizedBox(height: 16.h),

          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: TextField(
              onChanged: widget.onAspectDetailsChanged,
              maxLines: 3,
              style: TextStyle(color: Colors.white, fontSize: 16.sp),
              decoration: InputDecoration(
                hintText:
                    'You can describe what motivates you, how you wish to grow, or what support you need to reach your goals.',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14.sp,
                ),
                border: InputBorder.none,
                fillColor: Colors.transparent,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.all(16.r),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGETS (Responsive)
// ============================================================================

class RadioCard extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const RadioCard({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: 60.h,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 24.r,
              height: 24.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.white30,
                  width: 2.w,
                ),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 12.r,
                  height: 12.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                ),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: Colors.white, fontSize: 16.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MultiSelectCard extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const MultiSelectCard({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24.r,
              height: 24.r,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6.r),
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.white30,
                  width: 2.w,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 16.r, color: Colors.white)
                  : null,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomInputCard extends StatelessWidget {
  final ValueChanged<String?> onChanged;
  final String hintText;

  const CustomInputCard({
    super.key,
    required this.onChanged,
    this.hintText = 'Any other...',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50.h,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: TextField(
        onChanged: onChanged,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16.sp,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
        ),
      ),
    );
  }
}
