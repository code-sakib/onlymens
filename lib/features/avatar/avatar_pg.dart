import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:onlymens/features/avatar/avatar_data.dart';
import 'package:onlymens/features/streaks_page/data/streaks_data.dart';

class AvatarLevelsDrawer extends StatefulWidget {
  const AvatarLevelsDrawer({super.key});

  @override
  State<AvatarLevelsDrawer> createState() => _AvatarLevelsDrawerState();
}

class _AvatarLevelsDrawerState extends State<AvatarLevelsDrawer> {
  @override
  Widget build(BuildContext context) {
    final currentStreakDays = StreaksData.currentStreakDays;
    final currentLevel = AvatarManager.getLevelFromDays(currentStreakDays);

    return Drawer(
      width: 0.67.sw,
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
                padding: EdgeInsets.all(16.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Avatar Levels',
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Current: Level $currentLevel',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$currentStreakDays day${currentStreakDays == 1 ? '' : 's'} streak',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // LEVEL LIST
              Expanded(
                child: ListView.builder(
                  itemCount: 4,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
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
                            height: 32.h,
                            width: 3.w,
                            margin: EdgeInsets.symmetric(vertical: 4.h),
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
        borderRadius: BorderRadius.circular(12.r),
        border: isCurrent
            ? Border.all(color: Colors.deepPurple, width: 2.w)
            : isUnlocked
            ? Border.all(color: Colors.deepPurple.withOpacity(0.3), width: 1.w)
            : Border.all(color: Colors.grey[300]!, width: 1.w),
        boxShadow: [
          BoxShadow(
            color: isCurrent
                ? Colors.deepPurple.withOpacity(0.2)
                : Colors.black12,
            blurRadius: isCurrent ? 8.r : 4.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(12.r),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: ColorFiltered(
                colorFilter: isUnlocked
                    ? const ColorFilter.mode(
                        Colors.transparent,
                        BlendMode.multiply,
                      )
                    : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                child: Image.asset(
                  imagePath,
                  width: 80.w,
                  height: 80.h,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 80.w,
                    height: 80.h,
                    color: Colors.grey[300],
                    child: Icon(
                      Icons.person,
                      size: 40.r,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        level,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: isUnlocked ? Colors.black87 : Colors.grey[600],
                        ),
                      ),
                      if (isUnlocked && !isCurrent)
                        Padding(
                          padding: EdgeInsets.only(left: 6.w),
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16.r,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    days,
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    characteristic,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: isUnlocked ? Colors.blue[700] : Colors.grey[500],
                    ),
                  ),
                  if (progressText.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 8.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4.r),
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
                              minHeight: 6.h,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            progressText,
                            style: TextStyle(
                              fontSize: 11.sp,
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
