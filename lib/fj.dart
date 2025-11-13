import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:onlymens/core/apptheme.dart';
import 'package:onlymens/core/globals.dart';

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
    if (_currentPage < 3) {
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
              selectedTriggers: triggers,
              customTrigger: customTrigger,
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
              pageIndex: 3,
              onNext: () {
                // Complete onboarding
                _showSuccessDialog();
              },
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
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text(
          'Welcome to OnlyMens! 🎉',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Your journey to becoming smarter starts now.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Let\'s Go!'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BASE PAGE STRUCTURE
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
    final progress = (pageIndex + 1) / 4;

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

          // Progress Indicator
          Text(
            '${(progress * 100).toInt()}%',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),

          // Progress Bar
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

          // Title & Subtitle
          Padding(
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
          ),

          const SizedBox(height: 32),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
// PAGE 1: WELCOME
// ============================================================================
class WelcomePage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return BasePage(
      pageIndex: pageIndex,
      headerTitle: '',
      bigTitle: 'OnlyMens',
      subtitle:
          'Make yourself smarter — escape brain rot, gain clarity and save your precious time of life.',
      onNext: onNext,
      onBack: onBack,
      content: Column(
        children: [
          Image.asset('assets/onboarding/img1.png'),
          _buildFeatureCard(
            '👥 BetterWBro',
            'Here are the people who are on a similar journey in locality. You may find a friend to share hurdles, journey and talk to during hard times.',
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            '🧠 Hardy',
            'An AI friend to help you through tough relapsing times. It\'s trained to understand patterns and employ tricks to help you grow smarter.',
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            '🏆 Streaks',
            'Daily accountability with levels and achievement badges - turn your self-improvement into an exciting journey.',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PAGE 2: STATUS (RADIO SELECTION)
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
      subtitle: 'Choose the option that best matches your current behavior',
      onNext: () {
        onNext();
        obSelectedValues.addAll({'0': selectedFrequency});
      },
      onBack: onBack,
      isNextEnabled: selectedFrequency != null,
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

// ============================================================================
// PAGE 3: EFFECTS & TRIGGERS (UPDATED)
// ============================================================================
class EffectsPage extends StatefulWidget {
  final int pageIndex;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final List<String> selectedEffects;
  final String? customEffect;
  final List<String> selectedTriggers;
  final String? customTrigger;
  final ValueChanged<List<String>> onEffectsChanged;
  final ValueChanged<String?> onCustomEffectChanged;
  final ValueChanged<List<String>> onTriggersChanged;
  final ValueChanged<String?> onCustomTriggerChanged;

  const EffectsPage({
    super.key,
    required this.pageIndex,
    required this.onNext,
    required this.onBack,
    required this.selectedEffects,
    required this.customEffect,
    required this.selectedTriggers,
    required this.customTrigger,
    required this.onEffectsChanged,
    required this.onCustomEffectChanged,
    required this.onTriggersChanged,
    required this.onCustomTriggerChanged,
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

  final triggerOptions = [
    'When alone',
    'Under stress',
    'Boredom',
    'Anxiety',
    'Late-night hours',
    'After feeling lonely',
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
      headerTitle: 'Possible effects',
      bigTitle: 'How has pornography affected you?',
      subtitle: '',
      onNext: () {
        widget.onNext();
        obSelectedValues.addAll({
          '1': [
            widget.selectedEffects,
            widget.customEffect,
            widget.selectedTriggers,
            widget.customTrigger,
          ],
        });
      },
      onBack: widget.onBack,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grid of effect options (2 columns)
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

          // Custom effect input
          CustomInputCard(
            hintText: 'Other effects (optional)…',
            onChanged: widget.onCustomEffectChanged,
          ),

          const SizedBox(height: 32),

          // Triggers section
          const Text(
            'Situations when you are most likely to engage:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          // Grid of trigger options (2 columns)
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

          // Custom trigger input
          CustomInputCard(
            hintText: 'Other situations (optional)…',
            onChanged: widget.onCustomTriggerChanged,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PAGE 4: GOALS & ASPIRATIONS (REPLACED PAYMENT PAGE)
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
  bool smarterSelected = false;

  late ConfettiController _confettiController;

  final aspectOptions = [
    'Strengthen self-discipline',
    'Develop mental resilience',
    'Cultivate inner peace',
    'Build self-confidence',
    'Enhance focus and productivity',
    'Improve relationships',
  ];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

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
      onNext: () async {
        obSelectedValues.addAll({
          '2': [widget.selectedAspects, widget.aspectDetails],
        });
        await prefs.setBool('onboarding_done', true);
        context.go('/');
      },
      onBack: widget.onBack,
      content: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grid of aspect options (2 columns)
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

              // Large text field for detailed input
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

              const SizedBox(height: 20),

              // "You will become smarter" section
              // const Text(
              //   "You'll become smarter",
              //   style: TextStyle(
              //     color: Colors.white,
              //     fontSize: 28,
              //     fontWeight: FontWeight.bold,
              //   ),
              // ),
              // const SizedBox(height: 16),
              // RadioCard(
              //   title: 'For sure ✅',
              //   isSelected: smarterSelected,
              //   onTap: () {
              //     setState(() {
              //       smarterSelected = true;
              //     });
              //     //confetti
              //     _confettiController.play();
              //   },
              // ),

              // Align(
              //   alignment: Alignment.topCenter,
              //   child: ConfettiWidget(
              //     confettiController: _confettiController,
              //     blastDirectionality: BlastDirectionality
              //         .explosive, // 🔥 sprays in all directions
              //     emissionFrequency: 0.4, // low = bursty
              //     numberOfParticles: 25,
              //     gravity: 0.2, // softer fall
              //     shouldLoop: false,
              //     maxBlastForce: 25, // spread intensity
              //     minBlastForce: 10,
              //     blastDirection: -pi / 2, // just sets initial orientation
              //     colors: const [
              //       Colors.deepPurple,
              //       Colors.pinkAccent,
              //       Colors.cyanAccent,
              //       Colors.amber,
              //       Colors.lightGreenAccent,
              //     ],
              //     particleDrag: 0.08, // makes it feel airy
              //   ),
              // ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// REUSABLE COMPONENTS
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
