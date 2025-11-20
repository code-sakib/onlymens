import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:cleanmind/core/globals.dart';
import 'package:cleanmind/features/streaks_page/data/streaks_data.dart';
import 'package:cleanmind/guides/guides_manager.dart';

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
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      height: 200.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBackgroundImage(),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.amber, size: 20.r),
                      SizedBox(width: 8.w),
                      Text(
                        'Wisdom says',
                        style: TextStyle(
                          fontSize: 18.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(1.w, 1.h),
                              blurRadius: 3.r,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Expanded(
                    child: Text(
                      _quote!.text,
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.white,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(1.w, 1.h),
                            blurRadius: 3.r,
                          ),
                        ],
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      '— ${_quote!.author}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(1.w, 1.h),
                            blurRadius: 3.r,
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
    if (_quote?.imageUrl != null &&
        _quote!.imageUrl!.isNotEmpty &&
        !_imageLoadFailed) {
      print('🌐 Loading quote image from URL: ${_quote!.imageUrl!}');
      return Image.network(
        _quote!.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
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
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          );
        },
      );
    }
    return _buildAssetImage();
  }

  Widget _buildAssetImage() {
    return Image.asset(
      'assets/guide/quoteimg.jpg',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
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
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      height: 200.h,
      decoration: BoxDecoration(
        color: Colors.grey[300]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 8.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Center(
        child: CupertinoActivityIndicator(color: Colors.white.withOpacity(0.8)),
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
    glbCurrentStreakDaysNotifier.addListener(_onStreakChanged);
    _loadGuide(glbCurrentStreakDaysNotifier.value);
  }

  @override
  void dispose() {
    glbCurrentStreakDaysNotifier.removeListener(_onStreakChanged);
    super.dispose();
  }

  void _onStreakChanged() {
    final currentStreakDays = glbCurrentStreakDaysNotifier.value;
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
          margin: EdgeInsets.symmetric(horizontal: 16.w),
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4.r,
                offset: Offset(0, 2.h),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Days ${_guide!.dayRange}',
                style: TextStyle(fontSize: 13.sp, color: Colors.grey[500]),
              ),
              SizedBox(height: 16.h),
              ...(_guide!.tips.take(4).toList()).asMap().entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: EdgeInsets.only(top: 2.h),
                        width: 20.r,
                        height: 20.r,
                        decoration: BoxDecoration(
                          color: Colors.green[400]?.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.check,
                            color: Colors.green[400],
                            size: 14.r,
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: TextStyle(
                            fontSize: 14.sp,
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
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Center(child: CircularProgressIndicator(color: Colors.grey[400])),
    );
  }
}

class DominatingThoughtsWidget extends StatefulWidget {
  const DominatingThoughtsWidget({super.key});

  @override
  State<DominatingThoughtsWidget> createState() =>
      _DominatingThoughtsWidgetState();
}

class _DominatingThoughtsWidgetState extends State<DominatingThoughtsWidget> {
  String _thoughtText = "I am the master of my mind, not a slave to urges.";

  @override
  void initState() {
    super.initState();
    _loadThought();
  }

  Future<void> _loadThought() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('dmthought')
          .doc('current')
          .get();

      if (doc.exists && doc.data()?['text'] != null) {
        setState(() {
          _thoughtText = doc.data()!['text'];
        });
      }
    } catch (e) {
      print('Error loading thought: $e');
    }
  }

  Future<void> _saveThought(String newThought) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('dmthought')
          .doc('current')
          .set({'text': newThought, 'updatedAt': FieldValue.serverTimestamp()});

      setState(() {
        _thoughtText = newThought;
      });
    } catch (e) {
      print('Error saving thought: $e');
    }
  }

  void _showInfoBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'About component',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Back',
                    style: TextStyle(fontSize: 14.sp, color: Colors.deepPurple),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Text(
              "Hold this thought in your mind during relapse moments. Focus on it, believe it, and you'll feel its power.",
              style: TextStyle(
                fontSize: 15.sp,
                color: const Color(0xFFB0B0B0),
                height: 1.6,
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  void _showEditDialog() {
    final controller = TextEditingController(text: _thoughtText);
    const defaultThought = "I am the master of my mind, not a slave to urges.";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Row(
          children: [
            Text(
              'Edit Your Dominant Thought',
              style: TextStyle(color: Colors.white, fontSize: 15.5.sp),
            ),
            IconButton(
              onPressed: () {
                controller.text = defaultThought;
              },
              icon: Icon(Icons.restore, color: Colors.orange, size: 15.r),
              tooltip: 'Restore Default',
            ),
          ],
        ),

        content: TextField(
          controller: controller,
          maxLines: 3,
          style: TextStyle(color: Colors.white, fontSize: 16.sp),
          decoration: InputDecoration(
            hintText: 'What thought will dominate your mind today?',
            hintStyle: const TextStyle(color: Color(0xFF888888)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFF333333)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.deepPurple, width: 2.w),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: const Color(0xFF888888), fontSize: 14.sp),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final newThought = controller.text.trim();
              if (newThought.isNotEmpty) {
                _saveThought(newThought);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: Text(
              'Save',
              style: TextStyle(fontSize: 14.sp, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFF333333), width: 1.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dominating Thought',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: _showEditDialog,
                    child: Container(
                      padding: EdgeInsets.all(6.r),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        Icons.edit,
                        color: Colors.deepPurple,
                        size: 18.r,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  GestureDetector(
                    onTap: _showInfoBottomSheet,
                    child: Container(
                      padding: EdgeInsets.all(6.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedInformationCircle,
                        color: const Color(0xFFB0B0B0),
                        size: 18.r,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            _thoughtText,
            style: TextStyle(
              fontSize: 16.sp,
              color: const Color(0xFFE0E0E0),
              fontStyle: FontStyle.normal,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
