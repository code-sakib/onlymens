import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:onlymens/features/streaks_page/data/streaks_data.dart';
import 'package:onlymens/guides/guides_manager.dart';

// Import the data classes
// import 'quote_guide_classes.dart';

/// Widget for displaying daily motivational quote
class DailyMotivationWidget extends StatefulWidget {
  const DailyMotivationWidget({super.key});

  @override
  State<DailyMotivationWidget> createState() => _DailyMotivationWidgetState();
}

class _DailyMotivationWidgetState extends State<DailyMotivationWidget> {
  DailyQuote? _quote;
  bool _isLoading = true;
  bool _imageLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    try {
      setState(() => _isLoading = true);

      final quote = await QuoteManager.fetchTodayQuote();

      if (mounted) {
        setState(() {
          _quote = quote;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading quote: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Use default quote on error
          _quote = DailyQuote(
            text:
                'The truth is simple. If it was complicated, everyone would understand it.',
            author: 'Walt Whitman',
            date: DateTime.now().toString(),
            imageUrl: null,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_quote == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            _buildBackgroundImage(),

            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title at top
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: const [
                      Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Wisdom says',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(1, 1),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Quote text
                  Expanded(
                    child: Text(
                      _quote!.text,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(1, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Author bottom-right
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      '— ${_quote!.author}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(1, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
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

  Widget _buildBackgroundImage() {
    // Try network image first if available
    if (_quote?.imageUrl != null &&
        _quote!.imageUrl!.isNotEmpty &&
        !_imageLoadFailed) {
      print('🌐 Loading quote image from URL: ${_quote!.imageUrl!}');
      return Image.network(
        _quote!.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Network image failed, mark as failed and show asset
          if (!_imageLoadFailed) {
            Future.microtask(() {
              if (mounted) {
                setState(() => _imageLoadFailed = true);
              }
            });
          }
          return _buildAssetImage();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[800],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          );
        },
      );
    }

    // Use asset image by default
    return _buildAssetImage();
  }

  Widget _buildAssetImage() {
    return Image.asset(
      'assets/guide/quoteimg.jpg',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        // If asset fails, show gradient fallback
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple[700]!, Colors.deepPurple[500]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[300]!.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: CupertinoActivityIndicator(
          color: Colors.white.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

/// Widget for displaying level-based quick tips
class LevelGuideTipsWidget extends StatefulWidget {
  const LevelGuideTipsWidget({super.key});

  @override
  State<LevelGuideTipsWidget> createState() => _LevelGuideTipsWidgetState();
}

class _LevelGuideTipsWidgetState extends State<LevelGuideTipsWidget> {
  LevelGuide? _guide;
  bool _isLoading = true;
  String? _error;
  int _lastStreakDays = 0;

  @override
  void initState() {
    super.initState();
    // Listen to streak changes
    glbCurrentStreakDaysNotifier.addListener(_onStreakChanged);
    // Load initial guide
    _loadGuide(glbCurrentStreakDaysNotifier.value);
  }

  @override
  void dispose() {
    glbCurrentStreakDaysNotifier.removeListener(_onStreakChanged);
    super.dispose();
  }

  void _onStreakChanged() {
    final currentStreakDays = glbCurrentStreakDaysNotifier.value;

    // Only reload if level changed
    if (_shouldReloadGuide(_lastStreakDays, currentStreakDays)) {
      _loadGuide(currentStreakDays);
    }

    _lastStreakDays = currentStreakDays;
  }

  bool _shouldReloadGuide(int oldDays, int newDays) {
    final oldLevel = GuideManager.getLevelFromDays(oldDays);
    final newLevel = GuideManager.getLevelFromDays(newDays);
    return oldLevel != newLevel;
  }

  Future<void> _loadGuide(int streakDays) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final guide = await GuideManager.fetchGuideForStreak(streakDays);

      if (mounted) {
        setState(() {
          _guide = guide;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          // Use default guide on error
          final level = GuideManager.getLevelFromDays(streakDays);
          _guide = GuideManager.getDefaultGuide(level);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: glbCurrentStreakDaysNotifier,
      builder: (context, currentStreakDays, child) {
        if (_isLoading) {
          return _buildLoadingState();
        }

        if (_guide == null || _guide!.tips.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Days ${_guide!.dayRange}',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(height: 16),
              // Show only first 4 tips
              ...(_guide!.tips.take(4).toList()).asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.green[400]?.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.check,
                            color: Colors.green[400],
                            size: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.value,
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
      },
    );
  }

  Widget _buildLoadingState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Center(child: CircularProgressIndicator(color: Colors.grey[400])),
    );
  }
}
