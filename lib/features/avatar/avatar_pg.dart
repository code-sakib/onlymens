import 'package:flutter/material.dart';
import 'package:onlymens/core/globals.dart';
import 'package:onlymens/features/avatar/avatar_data.dart';
import 'package:onlymens/features/streaks_page/data/streaks_data.dart';
import 'package:onlymens/utilis/snackbar.dart';

class AvatarLevelsDrawer extends StatefulWidget {
  const AvatarLevelsDrawer({super.key});

  @override
  State<AvatarLevelsDrawer> createState() => _AvatarLevelsDrawerState();
}

class _AvatarLevelsDrawerState extends State<AvatarLevelsDrawer> {
  bool _hasPendingUpdate = false;
  int? _pendingRequiredLevel;
  int? _pendingCurrentLevel;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _checkPendingStatus();
  }

  Future<void> _checkPendingStatus() async {
    try {
      final info = await AvatarManager.getStorageInfo(currentUser.uid);
      final pending = info['pending_update'] ?? false;
      if (mounted) setState(() => _hasPendingUpdate = pending);
    } catch (_) {}
  }

  /// Manual update trigger
  Future<void> _handleManualRetry() async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);

    try {
      final res = await AvatarManager.updateModelNow(
        uid: currentUser.uid,
        streakDays: StreaksData.currentStreakDays,
      );

      if (!mounted) return;

      setState(() => _isUpdating = false);

      if (res.success) {
        setState(() => _hasPendingUpdate = false);
        Utilis.showSnackBar('🎉 Avatar updated successfully!', isErr: false);
      } else if (res.downloadLimitExceeded) {
        Utilis.showSnackBar(
          'Server busy. Avatar will auto-update later.',
          isErr: true,
        );
      } else {
        Utilis.showSnackBar(res.error ?? 'Update failed', isErr: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        Utilis.showSnackBar('Update failed: $e', isErr: true);
      }
    }
  }

  /// Show info dialog
  void _showPendingInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.system_update_alt, color: Colors.orange),
            SizedBox(width: 8),
            Text('Avatar update pending'),
          ],
        ),
        content: const Text(
          'Server is temporarily busy. Avatar will auto-update soon.\n\nYou can retry manually now if you wish.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (Navigator.canPop(context)) Navigator.pop(context);
              Utilis.showToast('Avatar will update later');
            },
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              if (Navigator.canPop(context)) Navigator.pop(context);
              _handleManualRetry();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('Try Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStreakDays = StreaksData.currentStreakDays;
    final currentLevel = AvatarManager.getLevelFromDays(currentStreakDays);

    return Drawer(
      width: MediaQuery.of(context).size.width / 1.5,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8F7FF),
              Color(0xFFFFFBFE),
              Color(0xFFF3F0FF),
              Color(0xFFFAF8FF),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left text info
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Avatar Levels',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Current: Level $currentLevel',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$currentStreakDays day${currentStreakDays == 1 ? '' : 's'} streak',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),

                    // Right side reload icon (if pending)
                    if (_hasPendingUpdate)
                      IconButton(
                        tooltip: 'Avatar update pending',
                        icon: _isUpdating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.orange,
                                ),
                              )
                            : const Icon(
                                Icons.system_update_alt,
                                color: Colors.orange,
                              ),
                        onPressed: _isUpdating ? null : _showPendingInfoDialog,
                      ),
                  ],
                ),
              ),

              // LEVEL LIST
              Expanded(
                child: ListView.builder(
                  itemCount: 4,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemBuilder: (context, index) {
                    final levels = [
                      {
                        'image': 'assets/3d/lvl1.png',
                        'level': 'Level 1',
                        'days': 'Day 1-7',
                        'char': 'The Beginning',
                        'requiredDays': 7,
                      },
                      {
                        'image': 'assets/3d/lvl2.png',
                        'level': 'Level 2',
                        'days': 'Day 8-14',
                        'char': 'Building Momentum',
                        'requiredDays': 14,
                      },
                      {
                        'image': 'assets/3d/lvl3.png',
                        'level': 'Level 3',
                        'days': 'Day 15-22',
                        'char': 'Strong Foundation',
                        'requiredDays': 22,
                      },
                      {
                        'image': 'assets/3d/lvl4.png',
                        'level': 'Level 4',
                        'days': 'Day 23-30+',
                        'char': 'Master of Self',
                        'requiredDays': 30,
                      },
                    ];

                    final levelNum = index + 1;
                    final data = levels[index];

                    double progress = 0.0;
                    String progressText = '';

                    if (currentLevel > levelNum) {
                      progress = 1.0;
                      progressText = 'Completed';
                    } else if (currentLevel == levelNum) {
                      if (levelNum < 4) {
                        final next = _getNextLevelDay(levelNum);
                        final start = _getLevelStartDay(levelNum);
                        final total = next - start;
                        final done = currentStreakDays - start;
                        progress = (done / total).clamp(0.0, 1.0);
                        progressText = '$currentStreakDays/$next days';
                      } else {
                        progress = 1.0;
                        progressText = 'Max Level';
                      }
                    } else if (levelNum == currentLevel + 1) {
                      final start = _getLevelStartDay(levelNum);
                      final remain = start - currentStreakDays;
                      progressText =
                          '$remain day${remain == 1 ? '' : 's'} to unlock';
                    }

                    return Column(
                      children: [
                        _buildAvatarCard(
                          context: context,
                          imagePath: data['image']! as String,
                          level: data['level']! as String,
                          days: data['days']! as String,
                          characteristic: data['char']! as String,
                          isUnlocked: currentLevel >= levelNum,
                          isCurrent: currentLevel == levelNum,
                          progress: progress,
                          progressText: progressText,
                        ),
                        if (index < 3)
                          Container(
                            height: 32,
                            width: 3,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: currentLevel > levelNum
                                    ? [Colors.deepPurple, Colors.deepPurple]
                                    : currentLevel == levelNum
                                    ? [Colors.deepPurple, Colors.grey[300]!]
                                    : [Colors.grey[300]!, Colors.grey[300]!],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _getLevelStartDay(int level) {
    switch (level) {
      case 1:
        return 1;
      case 2:
        return 8;
      case 3:
        return 15;
      case 4:
        return 23;
      default:
        return 1;
    }
  }

  int _getNextLevelDay(int level) {
    switch (level) {
      case 1:
        return 8;
      case 2:
        return 15;
      case 3:
        return 23;
      case 4:
        return 30;
      default:
        return 8;
    }
  }

  Widget _buildAvatarCard({
    required BuildContext context,
    required String imagePath,
    required String level,
    required String days,
    required String characteristic,
    required bool isUnlocked,
    required bool isCurrent,
    required double progress,
    required String progressText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isCurrent
            ? Colors.deepPurple.withOpacity(0.1)
            : isUnlocked
            ? Colors.deepPurple.withOpacity(0.05)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: isCurrent
            ? Border.all(color: Colors.deepPurple, width: 2)
            : isUnlocked
            ? Border.all(color: Colors.deepPurple.withOpacity(0.3), width: 1)
            : Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: isCurrent
                ? Colors.deepPurple.withOpacity(0.2)
                : Colors.black12,
            blurRadius: isCurrent ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Avatar preview image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColorFiltered(
                colorFilter: isUnlocked
                    ? const ColorFilter.mode(
                        Colors.transparent,
                        BlendMode.multiply,
                      )
                    : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                child: Image.asset(
                  imagePath,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[300],
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Avatar info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        level,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isUnlocked ? Colors.black87 : Colors.grey[600],
                        ),
                      ),
                      if (isUnlocked && !isCurrent)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    days,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    characteristic,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isUnlocked ? Colors.blue[700] : Colors.grey[500],
                    ),
                  ),
                  if (progressText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isCurrent
                                    ? Colors.deepPurple
                                    : isUnlocked
                                    ? Colors.green
                                    : Colors.grey[400]!,
                              ),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            progressText,
                            style: TextStyle(
                              fontSize: 11,
                              color: isCurrent
                                  ? Colors.deepPurple
                                  : isUnlocked
                                  ? Colors.green[700]
                                  : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
