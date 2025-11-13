import 'dart:async';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:onlymens/core/apptheme.dart';
import 'package:onlymens/core/globals.dart';
import 'package:uuid/uuid.dart';

// ============================================================================
// MAIN ONBOARDING WIDGET (UPDATED TO 6 PAGES INCLUDING REPORT)
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

  static const int totalPages =
      6; // Welcome, Status, Effects, Triggers, Goals, Report

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
            StatusPage(
              pageIndex: 1,
              onNext: _nextPage,
              onBack: _previousPage,
              selectedFrequency: frequency,
              onFrequencyChanged: (value) {
                setState(() {
                  frequency = value;
                });
              },
            ),
            EffectsPage(
              pageIndex: 2,
              onNext: _nextPage,
              onBack: _previousPage,
              selectedEffects: effects,
              customEffect: customEffect,
              onEffectsChanged: (newEffects) {
                setState(() {
                  effects = newEffects;
                });
              },
              onCustomEffectChanged: (value) {
                setState(() {
                  customEffect = value;
                });
              },
            ),
            TriggersPage(
              pageIndex: 3,
              onNext: _nextPage,
              onBack: _previousPage,
              selectedTriggers: triggers,
              customTrigger: customTrigger,
              onTriggersChanged: (newTriggers) {
                setState(() {
                  triggers = newTriggers;
                });
              },
              onCustomTriggerChanged: (value) {
                setState(() {
                  customTrigger = value;
                });
              },
            ),
            GoalsPage(
              pageIndex: 4,
              onNext: _nextPage,
              onBack: _previousPage,
              selectedAspects: aspects,
              aspectDetails: aspectDetails,
              onAspectsChanged: (newAspects) {
                setState(() {
                  aspects = newAspects;
                });
              },
              onAspectDetailsChanged: (value) {
                setState(() {
                  aspectDetails = value;
                });
              },
            ),

            // In your ReportPage, update the onNext callback:
            ReportPage(
              pageIndex: 5,
              onNext: () async {
                // Mark onboarding as complete
                await prefs.setBool('onboarding_done', true);

                // Navigate directly to pricing page
                if (context.mounted) {
                  context.go('/pricing'); // or context.push('/pricing')
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
// BASE PAGE STRUCTURE (progress updated for 6 pages)
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
    // Exclude welcome (0) and report (5) from progress calculation
    final progressPages = 4; // Pages 1-4 only
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
            AppColors.primary.withOpacity(0.15),
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
            height: 44,
            child: Row(
              children: [
                if (pageIndex > 0)
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    onPressed: onBack,
                  )
                else
                  const SizedBox(width: 48),
                Expanded(
                  child: Text(
                    headerTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),

          // Progress Indicator - hidden for Welcome (0) and Report (5)
          if (pageIndex != 0 && pageIndex != 5) ...[
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  minHeight: 4,
                ),
              ),
            ),

            const SizedBox(height: 32),
          ] else ...[
            const SizedBox(height: 24),
          ],

          // Title & Subtitle
          bigTitle.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bigTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 16,
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
              padding: const EdgeInsets.all(20),
              child: content,
            ),
          ),

          // Next Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isNextEnabled ? onNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: Colors.white30,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  nextButtonText,
                  style: const TextStyle(
                    fontSize: 16,
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
// REPORT PAGE WITH AI INSIGHTS AND GRAPH
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

  // Get or generate a persistent device ID
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('device_id');
    if (id == null) {
      id = const Uuid().v4(); // Generate random UUID
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
          _estimatedDays = result.data['estimatedDays'] ?? 15;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      print('Error generating report: $e');
      if (mounted) {
        setState(() {
          _aiInsight = _getFallbackInsight();
          _estimatedDays = 15;
          _isLoading = false;
        });
        _animationController.forward();
      }
    }
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
      nextButtonText: 'Continue to Pricing',
      content: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CupertinoActivityIndicator(color: AppColors.primary),
                  const SizedBox(height: 20),
                  Text(
                    'Analyzing your journey...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Based on your inputs, here\'s what to expect',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Chart Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
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
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$_estimatedDays days',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: SfCartesianChart(
                            plotAreaBorderWidth: 0,
                            primaryXAxis: NumericAxis(
                              isVisible: true,
                              majorGridLines: const MajorGridLines(width: 0),
                              axisLine: const AxisLine(width: 0),
                              labelStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                            primaryYAxis: NumericAxis(
                              isVisible: true,
                              majorGridLines: MajorGridLines(
                                width: 1,
                                color: Colors.white.withOpacity(0.1),
                              ),
                              axisLine: const AxisLine(width: 0),
                              labelStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
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
                                    AppColors.primary.withOpacity(0.4),
                                    AppColors.primary.withOpacity(0.0),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderColor: AppColors.primary,
                                borderWidth: 3,
                                animationDuration: 2000,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // AI Insight Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withOpacity(0.1),
                          AppColors.background,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            HugeIcon(
                              icon: HugeIcons
                                  .strokeRoundedArtificialIntelligence02,
                              color: AppColors.primary,
                              size: 24,
                            ),

                            const SizedBox(width: 8),
                            Text(
                              'AI Insights',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _aiInsight,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Summary Stats
                  _buildSummaryStats(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Current State',
            widget.frequency,
            Icons.timeline,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Focus Areas',
            '${widget.aspects.length} goals',
            Icons.flag,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
// EXISTING PAGES (WelcomePage, StatusPage, etc. - KEEP AS IS)
// ============================================================================

// ... (Keep all your existing page implementations: WelcomePage, StatusPage,
// EffectsPage, TriggersPage, GoalsPage, RadioCard, MultiSelectCard, CustomInputCard)
// They remain unchanged from your original code

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
  final PageController _reviewController = PageController();
  Timer? _autoScrollTimer;
  int _currentReviewIndex = 0;

  final List<Map<String, String>> reviews = [
    {
      'image': 'assets/onboarding/p1.png',
      'name': 'Ethan',
      'quote': 'It helped me to gain back control.',
    },
    {
      'image': 'assets/onboarding/p2.png',
      'name': 'John',
      'quote': 'Felt good by seeing every sec of my growth.',
    },
    {
      'image': 'assets/onboarding/p3.png',
      'name': 'Ruby',
      'quote': 'A small habit that changed my life.',
    },
    {
      'image': 'assets/onboarding/p4.png',
      'name': 'Logan',
      'quote': 'I finally feel like I own my time again.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_reviewController.hasClients) {
        final nextPage = (_currentReviewIndex + 1) % reviews.length;
        _reviewController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _reviewController.dispose();
    super.dispose();
  }

  Widget _buildReviewCard(Map<String, String> review, int index) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.5;

    return Container(
      width: cardWidth,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundImage: AssetImage(review['image']!),
            backgroundColor: Colors.white12,
          ),
          const SizedBox(height: 8),
          Text(
            '${review['name']}${index % 2 != 0 ? ' • early user' : ''}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${review['quote']}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      pageIndex: widget.pageIndex,
      headerTitle: 'OnlyMens',
      bigTitle: '',
      subtitle: '',
      onNext: widget.onNext,
      onBack: widget.onBack,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedTextKit(
            totalRepeatCount: 1,
            animatedTexts: [
              TyperAnimatedText(
                'Quit porn — Make yourself smarter — escape brain rot, gain clarity and save precious time of your life.',
                textStyle: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Image.asset(
                      'assets/onboarding/l1.png',
                      fit: BoxFit.contain,
                      height: 130,
                      opacity: const AlwaysStoppedAnimation(0.8),
                    ),
                  ),
                ),

                Expanded(
                  flex: 3,
                  child: PageView.builder(
                    controller: _reviewController,
                    onPageChanged: (index) {
                      setState(() => _currentReviewIndex = index);
                    },
                    itemCount: reviews.length,
                    itemBuilder: (context, index) =>
                        Center(child: _buildReviewCard(reviews[index], index)),
                  ),
                ),

                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Image.asset(
                      'assets/onboarding/l2.png',
                      fit: BoxFit.contain,
                      height: 130,
                      opacity: const AlwaysStoppedAnimation(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _buildFeatureCard(
            'BetterWBro',
            'Here are the people who are on a similar journey in locality. You may find a friend to share hurdles, journey and talk to during hard times.',
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            'Hardy',
            'An AI friend to help you through tough relapsing times. It\'s trained to understand patterns and employ tricks to help you grow smarter.',
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            'Streaks',
            'Daily accountability with levels and achievement badges - turn your self-improvement into an exciting journey.',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(String title, String description) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              HugeIcon(
                icon: HugeIcons.strokeRoundedMedal04,
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

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
      subtitle: 'Choose the option that best matches your current behavior',
      onNext: () {
        onNext();
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
          const SizedBox(height: 16),
          RadioCard(
            title: 'Frequently',
            isSelected: selectedFrequency == 'Frequently',
            onTap: () => onFrequencyChanged('Frequently'),
          ),
          const SizedBox(height: 16),
          RadioCard(
            title: 'Occasionally',
            isSelected: selectedFrequency == 'Occasionally',
            onTap: () => onFrequencyChanged('Occasionally'),
          ),
          const SizedBox(height: 16),
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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
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

          const SizedBox(height: 12),

          CustomInputCard(
            hintText: 'Other effects (optional)…',
            onChanged: widget.onCustomEffectChanged,
          ),
        ],
      ),
    );
  }
}

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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
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

          const SizedBox(height: 12),

          CustomInputCard(
            hintText: 'Other situations (optional)…',
            onChanged: widget.onCustomTriggerChanged,
          ),
        ],
      ),
    );
  }
}

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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
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

          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: TextField(
              onChanged: widget.onAspectDetailsChanged,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText:
                    'You can describe what motivates you, how you wish to grow, or what support you need to reach your goals.',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                fillColor: Colors.transparent,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.white30,
                  width: 2,
                ),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16),
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.white30,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 2,
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
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}
