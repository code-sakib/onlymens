import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:onlymens/core/globals.dart';
import 'package:onlymens/features/streaks_page/presentation/pTimer.dart';
import 'package:onlymens/utilis/size_config.dart';
import 'package:onlymens/utilis/snackbar.dart';

class StreaksPage extends StatefulWidget {
  const StreaksPage({super.key});

  @override
  State<StreaksPage> createState() => _StreaksPageState();
}

class _StreaksPageState extends State<StreaksPage> {
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
            SizedBox(
              height: SizeConfig.screenHeight / 2,
              child: Flexible(child: TimerComponents()),
            ),
            secondRowButtons(context),
            const SizedBox(height: 24),

            // Daily Motivation Section
            _buildMotivationSection(),
            const SizedBox(height: 24),

            // Progress Insights Section
            _buildProgressInsights(),
            const SizedBox(height: 24),

            // Blog Articles Section
            _buildBlogSection(context),
            const SizedBox(height: 24),

            // Community Support Section
            _buildCommunitySupportSection(),
            const SizedBox(height: 24),

            // Quick Tips Section
            _buildQuickTipsSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
      drawer: Drawer(
        width: SizeConfig.screenWidth / 1.5,
        child: Container(
          color: Colors.white,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Avatar Levels',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Divider(thickness: 2),
                  SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildAvatarCard(
                          imagePath: 'assets/3d/lvl1.png',
                          level: 'Level 1',
                          days: 'Day 1-3',
                          characteristic: 'Just Started',
                        ),
                        SizedBox(height: 16),
                        _buildAvatarCard(
                          imagePath: 'assets/3d/lvl2.png',
                          level: 'Level 2',
                          days: 'Day 3-9',
                          characteristic: 'Getting There',
                        ),
                        SizedBox(height: 16),
                        _buildAvatarCard(
                          imagePath: 'assets/3d/lvl3.png',
                          level: 'Level 3',
                          days: 'Day 9-15',
                          characteristic: 'On Track',
                        ),
                        SizedBox(height: 16),
                        _buildAvatarCard(
                          imagePath: 'assets/3d/lvl4.png',
                          level: 'Level 4',
                          days: 'Day 15-22',
                          characteristic: 'Pro Alpha',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildMotivationSection() {
  return Container(
    margin: EdgeInsets.symmetric(horizontal: 16),
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.deepPurple[700]!, Colors.deepPurple[500]!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.deepPurple.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb, color: Colors.amber, size: 28),
            SizedBox(width: 12),
            Text(
              'A wise man said',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Text(
          '"Every moment of resistance is a victory. You\'re not just avoiding a habit—you\'re reclaiming your power, your focus, and your future."',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.95),
            height: 1.5,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    ),
  );
}

Widget _buildProgressInsights() {
  return Container(
    margin: EdgeInsets.symmetric(horizontal: 16),
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.grey[850],
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progress Insights',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildInsightCard(
              'Current Streak',
              '11 Days',
              Icons.whatshot,
              Colors.orange,
            ),
            _buildInsightCard(
              'Best Streak',
              '18 Days',
              Icons.emoji_events,
              Colors.amber,
            ),
            _buildInsightCard(
              'Success Rate',
              '60%',
              Icons.trending_up,
              Colors.green,
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildInsightCard(
  String label,
  String value,
  IconData icon,
  Color color,
) {
  return Column(
    children: [
      Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, color: color, size: 28),
      ),
      SizedBox(height: 8),
      Text(
        value,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      SizedBox(height: 4),
      Text(
        label,
        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
        textAlign: TextAlign.center,
      ),
    ],
  );
}

Widget _buildBlogSection(BuildContext context) {
  final blogs = [
    {
      'title': 'How Porn Paves the Way to Misery',
      'excerpt':
          'Understanding the psychological and physiological impact of pornography addiction and its devastating effects on mental health, relationships, and personal growth.',
      'icon': Icons.psychology,
      'color': Colors.red,
      'route': '/blog/misery',
    },
    {
      'title': 'Rewiring Your Brain: The Science of Recovery',
      'excerpt':
          'Discover how neuroplasticity can help you rebuild neural pathways, restore dopamine sensitivity, and reclaim control over your life.',
      'icon': Icons.psychology_alt,
      'color': Colors.blue,
      'route': '/blog/rewiring',
    },
    {
      'title': 'Building Unshakeable Self-Discipline',
      'excerpt':
          'Practical strategies and mindset shifts to develop iron-will discipline that helps you resist urges and build lasting positive habits.',
      'icon': Icons.fitness_center,
      'color': Colors.green,
      'route': '/blog/discipline',
    },
  ];

  return Container(
    margin: EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 16),
          child: Row(
            children: [
              Icon(Icons.article, color: Colors.deepPurple[300], size: 28),
              SizedBox(width: 8),
              Text(
                'Recovery Insights',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        ...blogs.map(
          (blog) => Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: _buildBlogCard(
              context,
              blog['title'] as String,
              blog['excerpt'] as String,
              blog['icon'] as IconData,
              blog['color'] as Color,
              blog['route'] as String,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildBlogCard(
  BuildContext context,
  String title,
  String excerpt,
  IconData icon,
  Color color,
  String route,
) {
  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              BlogDetailPage(title: title, icon: icon, color: color),
        ),
      );
    },
    child: Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  excerpt,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400],
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Read More',
                      style: TextStyle(
                        fontSize: 13,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, color: color, size: 16),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildCommunitySupportSection() {
  return Container(
    margin: EdgeInsets.symmetric(horizontal: 16),
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.grey[850],
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.group, color: Colors.deepPurple[300], size: 28),
            SizedBox(width: 12),
            Text(
              'Community Support',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Text(
          'You\'re not alone in this journey. Join thousands of others who are committed to positive change.',
          style: TextStyle(fontSize: 14, color: Colors.grey[400], height: 1.5),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildSupportStat('1.2K', 'Active Members')),
            SizedBox(width: 12),
            Expanded(child: _buildSupportStat('850+', 'Success Stories')),
          ],
        ),
      ],
    ),
  );
}

Widget _buildSupportStat(String value, String label) {
  return Container(
    padding: EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.deepPurple.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.3)),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple[300],
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

Widget _buildQuickTipsSection() {
  final tips = [
    'Stay hydrated - drink 8 glasses of water daily',
    'Exercise for 30 minutes to boost mood',
    'Practice mindfulness meditation',
    'Get 7-8 hours of quality sleep',
  ];

  return Container(
    margin: EdgeInsets.symmetric(horizontal: 16),
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.grey[850],
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tips_and_updates, color: Colors.amber, size: 28),
            SizedBox(width: 12),
            Text(
              'Quick Daily Tips',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        ...tips.map(
          (tip) => Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle, color: Colors.green[400], size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tip,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[300],
                      height: 1.4,
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
}

Widget _buildAvatarCard({
  required String imagePath,
  required String level,
  required String days,
  required String characteristic,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              imagePath,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[300],
                  child: Icon(Icons.person, size: 40, color: Colors.grey[600]),
                );
              },
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  days,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                SizedBox(height: 4),
                Text(
                  characteristic,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[700],
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

secondRowButtons(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(10.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: () => context.push('/affirmations'),
          label: HugeIcon(icon: HugeIcons.strokeRoundedHandPrayer, size: 20),
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
          label: HugeIcon(icon: HugeIcons.strokeRoundedRelieved01),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple[600],
            shape: const CircleBorder(),
          ),
        ),
      ],
    ),
  );
}

// Replace the entire DaysList class with this:

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

class BlogDetailPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const BlogDetailPage({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
  });

  String _getContent() {
    if (title.contains('Misery')) {
      return _getMiseryContent();
    } else if (title.contains('Rewiring')) {
      return _getRewiringContent();
    } else {
      return _getDisciplineContent();
    }
  }

  String _getMiseryContent() {
    return '''The Hidden Devastation

Pornography is often dismissed as a harmless indulgence, a private activity with no real consequences. But beneath the surface lies a darker reality—one that silently erodes mental health, relationships, self-worth, and the very essence of who you are. Understanding how pornography paves the way to misery is the first step toward reclaiming your life.

The Neurological Hijacking

When you watch pornography, your brain releases massive amounts of dopamine—the "feel-good" chemical associated with pleasure and reward. This creates an immediate rush that feels intensely satisfying. However, repeated exposure to this artificial stimulation causes your brain to adapt in harmful ways.

Over time, your dopamine receptors become desensitized. What once gave you pleasure now barely registers. You need more extreme content, longer sessions, or more frequent use just to feel the same high. This is the foundation of addiction—your brain has been hijacked, and the natural pleasures of life pale in comparison to the artificial stimulation pornography provides.

This neurological rewiring doesn't just affect your viewing habits. It impacts everything: your motivation, your focus, your ability to feel joy from everyday activities, and your emotional regulation. The world becomes gray and lifeless when your brain is calibrated to expect the hyperstimulation that pornography provides.

The Psychological Toll

Beyond the brain chemistry, pornography takes a profound psychological toll. Many users report feelings of shame, guilt, and self-disgust after viewing sessions. These feelings aren't just moral reactions—they're signs of cognitive dissonance, the painful awareness that your actions don't align with your values.

This internal conflict erodes self-esteem. You begin to see yourself as weak, undisciplined, or morally deficient. These negative self-perceptions become self-fulfilling prophecies, making it harder to break free from the cycle. Depression and anxiety often follow, as the habit becomes a source of constant internal turmoil.

Moreover, pornography distorts your perception of sexuality and relationships. It creates unrealistic expectations about physical appearance, sexual performance, and what intimacy should look like. Real relationships, with their complexities and emotional depth, can't compete with the fantasy world pornography creates. This leads to dissatisfaction, disconnection, and often, the breakdown of meaningful relationships.

The Relational Destruction

Perhaps nowhere is the misery more evident than in relationships. Partners of pornography users often report feeling betrayed, inadequate, and replaced by pixels on a screen. The emotional intimacy that forms the foundation of healthy relationships is eroded when one partner is getting their sexual and emotional needs met through artificial means.

Trust is shattered when secret pornography use is discovered. Even without discovery, the secrecy itself creates distance. You become emotionally unavailable, distracted, and less present. The energy and attention that should be invested in your relationship is diverted to feeding the addiction.

For single individuals, pornography can make genuine connection nearly impossible. You approach potential partners with unrealistic expectations, struggle with real intimacy, and may find yourself unable to perform sexually without the specific stimulation pornography has conditioned you to require.

The Time and Energy Drain

Consider the hours lost to pornography—time that could have been spent building skills, nurturing relationships, pursuing passions, or simply being present in your life. But it's not just the time spent viewing; it's the mental energy consumed by the constant battle between urges and resistance, the planning of when and how to use, and the aftermath of guilt and shame.

This drain extends to your productivity and ambition. Many users report a significant decrease in motivation and drive. Why pursue difficult goals when you can get an instant dopamine hit from pornography? The habit becomes a way to escape discomfort, boredom, or stress—but in doing so, it prevents you from developing healthy coping mechanisms and achieving real accomplishment.

The Path Forward

Understanding that pornography paves the way to misery is sobering, but it's also empowering. Recognition is the first step toward change. The good news is that your brain is remarkably plastic—capable of healing and rewiring itself when given the chance.

Recovery is possible. It requires honesty about the problem, commitment to change, and often support from others who understand the struggle. But every day of freedom is a step away from misery and toward a life of genuine connection, authentic joy, and self-respect.

The choice is yours: continue down a path that leads only to deeper misery, or take the courageous step toward freedom and reclaim the life you deserve.

Final Thoughts

The misery pornography creates isn't always obvious at first. It accumulates slowly, like a fog that gradually obscures your vision until you can barely see the path ahead. But by understanding the mechanisms through which pornography destroys—neurologically, psychologically, relationally, and practically—you can begin to clear that fog and see a brighter future ahead.

You are not your habit. You are not defined by your struggles. And you have the power to choose a different path—one that leads not to misery, but to fulfillment, connection, and authentic happiness.''';
  }

  String _getRewiringContent() {
    return '''Understanding Neuroplasticity

Your brain is not fixed. Despite what you may have been told or what you may believe about yourself, your brain has an extraordinary ability to change, adapt, and heal. This property is called neuroplasticity, and it's the foundation of your recovery journey.

Every thought you think, every action you take, and every experience you have physically changes your brain. Neural pathways strengthen with use and weaken with disuse. This is how you learned to walk, talk, and ride a bicycle—and it's also how you developed problematic patterns with pornography. But here's the crucial insight: the same mechanism that created the problem can be used to solve it.

The Damage Done

Before we discuss rewiring, it's important to understand what needs to be fixed. Regular pornography use creates several problematic neural patterns.

First, your reward circuitry becomes hypersensitized to pornography and desensitized to natural rewards. The dopamine receptors that respond to everyday pleasures are downregulated, making it harder to feel joy from normal activities. Simultaneously, the pathways associated with pornography use become superhighways in your brain, making the behavior almost automatic.

Second, your stress response systems become dysregulated. Pornography becomes your primary coping mechanism for stress, boredom, loneliness, or any uncomfortable emotion. This prevents you from developing healthy emotional regulation skills and makes you dependent on the behavior for emotional stability.

Third, your prefrontal cortex—the part of your brain responsible for decision-making, impulse control, and executive function—becomes less active. This is why resisting urges feels so difficult; the very part of your brain that should help you make good decisions has been weakened by the addiction.

The Rewiring Process

Recovery isn't just about stopping pornography use—it's about actively rewiring your brain to function healthily again. This process takes time, patience, and consistent effort, but the results are transformative.

Phase 1: The Detox (Days 1-30)

The first phase is the most challenging. Your brain is flooded with cravings as it desperately seeks the dopamine rush it's become accustomed to. During this period, you may experience what's often called a "flatline"—a period of low motivation, low libido, and emotional numbness.

This is actually a good sign. Your brain is recalibrating, and your dopamine receptors are beginning to upregulate. Natural pleasures don't feel pleasurable yet because your brain is still calibrated for the supernormal stimulus of pornography. Push through this phase with the knowledge that it's temporary.

During this phase, focus on removing all triggers and access to pornography, building new daily routines that don't include the habit, engaging in physical exercise to boost natural dopamine, and connecting with supportive people who understand your journey.

Phase 2: The Awakening (Days 30-90)

Around the 30-day mark, many people report significant changes. Colors seem brighter, music sounds better, and everyday activities become more enjoyable. This is your dopamine receptors healing and regaining sensitivity to natural rewards.

Your prefrontal cortex also begins to strengthen during this phase. Decision-making becomes easier, impulse control improves, and you start feeling more like yourself again. The mental fog that characterized your addiction begins to lift.

However, this phase isn't without challenges. You may experience waves of intense cravings or emotional volatility as your brain continues to adjust. These are normal parts of the healing process, not signs that you're failing.

Phase 3: The New Normal (Days 90+)

Beyond 90 days, the new neural pathways you've been building become increasingly strong, while the old pornography pathways continue to weaken. The habit that once felt impossible to resist now has much less power over you.

Your natural reward system is largely restored. You find genuine joy in relationships, hobbies, accomplishments, and simple pleasures. Your stress response system has learned new, healthy coping mechanisms. Your prefrontal cortex is strong and active, giving you real agency over your choices.

Active Strategies for Rewiring

Simply abstaining from pornography initiates healing, but active strategies accelerate and deepen the rewiring process.

Mindfulness and meditation strengthen your prefrontal cortex and improve your ability to observe urges without acting on them. Even 10 minutes daily makes a significant difference.

Physical exercise boosts BDNF (brain-derived neurotrophic factor), which promotes neuroplasticity and neural healing. It also provides a healthy dopamine boost and reduces stress.

Cold exposure through cold showers or ice baths trains your brain to tolerate discomfort and strengthens willpower. They also boost dopamine naturally and improve mood.

Real human connection activates your brain's reward pathways in healthy ways. Invest time in meaningful relationships, join support groups, and don't isolate yourself.

Learning new skills stimulates neuroplasticity and creates new neural pathways. Whether it's a language, instrument, or sport, challenging your brain to learn helps it rewire.

Quality sleep is when your brain consolidates new learning and clears out metabolic waste. Prioritize 7-9 hours of quality sleep each night.

The Science of Hope

Neuroimaging studies have shown remarkable recovery in individuals who abstain from pornography. Brain scans reveal that gray matter volume increases, dopamine receptor density improves, and prefrontal cortex activity returns to normal levels.

This isn't just theory—it's measurable, observable change. Your brain can heal. The damage isn't permanent. You're not broken beyond repair.

Handling Setbacks

Rewiring isn't always linear. Setbacks happen, and when they do, it's crucial to understand that a single lapse doesn't erase your progress. The neural pathways you've been building remain, even if the old pathways briefly activate.

What matters is how you respond. Shame and self-punishment trigger stress responses that can lead to binge behavior. Instead, treat setbacks with curiosity and compassion. What triggered the lapse? What can you learn? How will you respond differently next time?

Each time you successfully resist an urge—even for just a few seconds longer than last time—you're strengthening new pathways and weakening old ones. Progress compounds over time.

The Promise of Recovery

The brain you'll have six months or a year into recovery will be dramatically different from the brain you have now. You'll think more clearly, feel more deeply, connect more authentically, and act more purposefully.

You'll rediscover genuine sexuality—not the performative, consumption-based sexuality of pornography, but the intimate, connected sexuality that enriches relationships and expresses love.

You'll find that life itself becomes more vivid and meaningful. The activities and relationships you've been neglecting will come back into focus. Your values and your actions will align. You'll become the person you always wanted to be.

This isn't magical thinking—it's the predictable result of giving your brain the environment it needs to heal. Neuroplasticity is on your side. Every day of recovery is a day of rewiring. Every healthy choice strengthens new pathways. Every urge you resist weakens old ones.

Your brain wants to heal. Your job is simply to give it the chance.''';
  }

  String _getDisciplineContent() {
    return '''The Foundation of Freedom

Self-discipline is not about punishment or deprivation. It's about freedom—the freedom to choose your actions rather than being controlled by impulses, the freedom to build the life you want rather than settling for what's easy, and the freedom to become who you're capable of being rather than remaining trapped by habit.

Building unshakeable self-discipline is the single most important skill for overcoming pornography addiction and creating lasting change. It's the bridge between knowing what you should do and actually doing it, between intentions and actions, between who you are and who you want to become.

Understanding Discipline

Many people misunderstand discipline. They see it as rigid adherence to rules, as joyless sacrifice, or as something you either have or don't have. But true discipline is something entirely different.

Discipline is the alignment of your actions with your values. It's making the choice that serves your long-term wellbeing even when the short-term discomfort is real. It's the muscle that grows stronger each time you use it, and weaker each time you give in to immediate gratification.

The good news is that discipline is not innate—it's learned. You weren't born with or without it. Every single disciplined person you admire built that capacity through repeated practice, just as you're about to do.

The Discipline Pyramid

Building unshakeable discipline requires a structured approach. Think of it as a pyramid with four levels.

Level 1: Physical Foundation

Your physical state dramatically affects your willpower and decision-making capacity. When you're tired, hungry, or stressed, your prefrontal cortex (the discipline center of your brain) functions poorly. You become impulsive and reactive rather than intentional and proactive.

To build a strong physical foundation, sleep 7-9 hours consistently, eat regular nutritious meals, exercise daily even if just for 20 minutes, limit caffeine and avoid alcohol, and practice proper hydration.

Level 2: Environmental Design

Discipline is much easier when your environment supports your goals rather than sabotages them. Relying purely on willpower when surrounded by triggers is like trying to diet while living in a bakery.

Create an environment that makes success inevitable by removing all access to pornography, eliminating idle phone time, designing your space for productivity, controlling your triggers, and building in friction for bad habits while reducing friction for good habits.

Level 3: Mental Mastery

Your thoughts create your reality. The stories you tell yourself about who you are, what you're capable of, and what you deserve shape your actions more than anything else.

Develop mental mastery through identity shift, urge surfing, cognitive reframing, visualization, and positive self-talk. Stop saying "I'm trying to quit" and start saying "I'm someone who doesn't use pornography."

Level 4: Consistent Action

All the foundation, environment design, and mental work means nothing without consistent action. Discipline is built through doing, not just thinking or planning.

Start small and build momentum. Stack new habits onto existing ones. Track your consistency. Gradually increase difficulty. The key is daily action, not perfection.

The Power of Micro-Decisions

Every single day, you face countless micro-decisions. These decisions seem small and insignificant in the moment, but they compound over time. Each one is either a deposit in your discipline account or a withdrawal from it.

The person who consistently makes disciplined micro-decisions builds tremendous willpower over time. The person who consistently chooses comfort weakens their discipline muscle until it can barely function. Your life is the sum of your micro-decisions. Choose wisely.

The Twenty-Second Rule

When an urge arises, commit to waiting just twenty seconds before acting on it. During those twenty seconds, you create space for your prefrontal cortex to activate and your rational mind to engage.

Often, twenty seconds is enough for the intensity of the urge to diminish. And if it isn't, commit to another twenty seconds. You're not committing to never acting on the urge—just to waiting twenty more seconds. This simple technique transforms your relationship with urges from powerlessness to agency.

The Discipline-Confidence Loop

Discipline creates confidence, and confidence makes discipline easier. Each time you successfully resist an urge, make a healthy choice, or follow through on a commitment, you prove to yourself that you're capable. This proof builds self-trust and confidence.

With greater confidence, subsequent disciplined choices become easier because you believe in your ability to follow through. This creates an upward spiral. The inverse is also true: giving in erodes self-trust and makes future discipline harder. Which spiral are you building?

Handling the Discipline Dip

There will be days when discipline feels impossible. You're tired, stressed, overwhelmed, or emotionally drained. The urges are intense, and your resistance is low. These are the most important days. These are the days that define who you're becoming.

On these days, don't try to be a hero. Lower the bar. Instead of your full workout, do five minutes. The goal isn't perfection—it's maintaining the identity of someone who shows up even when it's hard.

The Long Game

Building unshakeable discipline is a marathon, not a sprint. There is no finish line where you suddenly "have" discipline and never struggle again. It's a practice, a daily choice, a muscle that requires consistent exercise.

But here's what happens over time: The things that once required intense willpower become automatic. The urges that once felt overwhelming become manageable. The person you're becoming becomes your natural state rather than an aspiration.

The Truth About Freedom

True freedom comes from discipline, not from the absence of rules. The person enslaved to their impulses thinks they're free, but they're controlled by their urges, their environment, their habits.

The disciplined person—the one who can feel an urge and choose not to act on it, who can face discomfort without fleeing, who can delay gratification for meaningful goals—is truly free. They're the author of their life.

This is the freedom worth fighting for. This is the life worth building. And it all starts with the simple, daily practice of discipline.

You are capable of this. Not someday, not once you "get ready," not after one more failure. Right now. Today. This moment. The question is: Will you choose it?''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.3),
                    color.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color, size: 48),
                  SizedBox(height: 16),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Colors.grey[400],
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        '15 min read',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                      SizedBox(width: 20),
                      Icon(
                        Icons.calendar_today,
                        color: Colors.grey[400],
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Oct 12, 2025',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 30),

            // Content
            Text(
              _getContent(),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[300],
                height: 1.8,
                letterSpacing: 0.3,
              ),
            ),

            SizedBox(height: 40),

            // Call to Action
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.favorite, color: color, size: 40),
                  SizedBox(height: 16),
                  Text(
                    'Your Journey Starts Today',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Every moment you choose recovery is a victory. Keep going—you\'re worth it.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[400],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
