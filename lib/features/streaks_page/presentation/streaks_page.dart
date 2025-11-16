import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:onlymens/core/globals.dart';
import 'package:onlymens/features/avatar/avatar_pg.dart';
import 'package:onlymens/features/streaks_page/presentation/pTimer.dart';
import 'package:onlymens/guides/blogs.dart';
import 'package:onlymens/guides/guides_pg.dart';
import 'package:onlymens/utilis/snackbar.dart';

import 'dart:io';
import 'package:path_provider/path_provider.dart';

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
              ],
            ),
            SizedBox(height: 40.h),
          ],
        ),
      ),
      drawer: AvatarLevelsDrawer(),
      floatingActionButton: ElevatedButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AvatarCleanupDialog(),
          );
        },
        child: Text('Clean Avatar Storage'),
      ),
    );
  }
}

Widget _buildProgressInsights() {
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
          'Progress Insights',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 20.h),
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
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, color: color, size: 28.r),
      ),
      SizedBox(height: 8.h),
      Text(
        value,
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      SizedBox(height: 4.h),
      Text(
        label,
        style: TextStyle(fontSize: 12.sp, color: Colors.grey[400]),
        textAlign: TextAlign.center,
      ),
    ],
  );
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

// Avatar Storage Cleanup classes remain the same but with ScreenUtil
class AvatarStorageCleanup {
  static Future<CleanupResult> performCleanup() async {
    try {
      print('🧹 Starting Avatar Storage Cleanup...');

      int deletedFiles = 0;
      double freedSpaceMB = 0.0;
      List<String> deletedFileNames = [];

      final docsResult = await _cleanupDocumentsDirectory();
      deletedFiles += docsResult['count'] as int;
      freedSpaceMB += docsResult['size'] as double;
      deletedFileNames.addAll(docsResult['files'] as List<String>);

      final supportResult = await _cleanupApplicationSupportDirectory();
      deletedFiles += supportResult['count'] as int;
      freedSpaceMB += supportResult['size'] as double;
      deletedFileNames.addAll(supportResult['files'] as List<String>);

      final orphanResult = await _cleanupOrphanedFiles();
      deletedFiles += orphanResult['count'] as int;
      freedSpaceMB += orphanResult['size'] as double;
      deletedFileNames.addAll(orphanResult['files'] as List<String>);

      print('✅ Cleanup Complete!');
      print('   Files deleted: $deletedFiles');
      print('   Space freed: ${freedSpaceMB.toStringAsFixed(2)} MB');

      return CleanupResult(
        success: true,
        deletedFiles: deletedFiles,
        freedSpaceMB: freedSpaceMB,
        deletedFileNames: deletedFileNames,
      );
    } catch (e) {
      print('❌ Cleanup error: $e');
      return CleanupResult(success: false, error: e.toString());
    }
  }

  static Future<Map<String, dynamic>> _cleanupDocumentsDirectory() async {
    int count = 0;
    double size = 0.0;
    List<String> files = [];

    try {
      final Directory appDocs = await getApplicationDocumentsDirectory();
      final Directory avatarDir = Directory('${appDocs.path}/avatars');

      if (await avatarDir.exists()) {
        final entities = avatarDir.listSync();

        for (var entity in entities) {
          if (entity is File) {
            final name = entity.path.split('/').last;

            if (name.startsWith('level_') && name.endsWith('.glb')) {
              final stat = await entity.stat();
              final fileSizeMB = stat.size / (1024 * 1024);

              await entity.delete();

              count++;
              size += fileSizeMB;
              files.add(name);

              print(
                '🗑️ Deleted old file: $name (${fileSizeMB.toStringAsFixed(2)} MB)',
              );
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ Documents cleanup error: $e');
    }

    return {'count': count, 'size': size, 'files': files};
  }

  static Future<Map<String, dynamic>>
  _cleanupApplicationSupportDirectory() async {
    int count = 0;
    double size = 0.0;
    List<String> files = [];

    try {
      final Directory appSupport = await getApplicationSupportDirectory();
      final Directory avatarDir = Directory('${appSupport.path}/avatars');

      if (await avatarDir.exists()) {
        final entities = avatarDir.listSync();

        for (var entity in entities) {
          if (entity is File) {
            final name = entity.path.split('/').last;
            final stat = await entity.stat();
            final fileSizeMB = stat.size / (1024 * 1024);

            await entity.delete();

            count++;
            size += fileSizeMB;
            files.add('(AppSupport) $name');

            print(
              '🗑️ Deleted from AppSupport: $name (${fileSizeMB.toStringAsFixed(2)} MB)',
            );
          }
        }

        if (avatarDir.listSync().isEmpty) {
          await avatarDir.delete();
          print('🗑️ Deleted empty AppSupport/avatars directory');
        }
      }
    } catch (e) {
      print('⚠️ AppSupport cleanup error: $e');
    }

    return {'count': count, 'size': size, 'files': files};
  }

  static Future<Map<String, dynamic>> _cleanupOrphanedFiles() async {
    int count = 0;
    double size = 0.0;
    List<String> files = [];

    try {
      final Directory appDocs = await getApplicationDocumentsDirectory();
      final Directory avatarDir = Directory('${appDocs.path}/avatars');

      if (await avatarDir.exists()) {
        final entities = avatarDir.listSync();

        for (var entity in entities) {
          if (entity is File) {
            final name = entity.path.split('/').last;

            if (!name.startsWith('av_lv') || !name.endsWith('_comp.glb')) {
              final stat = await entity.stat();
              final fileSizeMB = stat.size / (1024 * 1024);

              await entity.delete();

              count++;
              size += fileSizeMB;
              files.add(name);

              print('🗑️ Deleted orphaned file: $name');
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ Orphan cleanup error: $e');
    }

    return {'count': count, 'size': size, 'files': files};
  }

  static Future<StorageInfo> getStorageInfo() async {
    try {
      final Directory appDocs = await getApplicationDocumentsDirectory();
      final Directory avatarDir = Directory('${appDocs.path}/avatars');

      if (!await avatarDir.exists()) {
        return StorageInfo(totalFiles: 0, totalSizeMB: 0.0, files: []);
      }

      final entities = avatarDir.listSync();
      int totalFiles = 0;
      double totalSize = 0.0;
      List<FileInfo> fileList = [];

      for (var entity in entities) {
        if (entity is File) {
          final name = entity.path.split('/').last;
          final stat = await entity.stat();
          final sizeMB = stat.size / (1024 * 1024);

          totalFiles++;
          totalSize += sizeMB;

          fileList.add(
            FileInfo(
              name: name,
              sizeMB: sizeMB,
              path: entity.path,
              isCompressed: name.contains('_comp'),
            ),
          );
        }
      }

      return StorageInfo(
        totalFiles: totalFiles,
        totalSizeMB: totalSize,
        files: fileList,
      );
    } catch (e) {
      print('❌ Storage info error: $e');
      return StorageInfo(totalFiles: 0, totalSizeMB: 0.0, files: []);
    }
  }
}

class CleanupResult {
  final bool success;
  final int deletedFiles;
  final double freedSpaceMB;
  final List<String> deletedFileNames;
  final String? error;

  CleanupResult({
    required this.success,
    this.deletedFiles = 0,
    this.freedSpaceMB = 0.0,
    this.deletedFileNames = const [],
    this.error,
  });
}

class StorageInfo {
  final int totalFiles;
  final double totalSizeMB;
  final List<FileInfo> files;

  StorageInfo({
    required this.totalFiles,
    required this.totalSizeMB,
    required this.files,
  });
}

class FileInfo {
  final String name;
  final double sizeMB;
  final String path;
  final bool isCompressed;

  FileInfo({
    required this.name,
    required this.sizeMB,
    required this.path,
    required this.isCompressed,
  });
}

class AvatarCleanupDialog extends StatefulWidget {
  const AvatarCleanupDialog({super.key});

  @override
  State<AvatarCleanupDialog> createState() => _AvatarCleanupDialogState();
}

class _AvatarCleanupDialogState extends State<AvatarCleanupDialog> {
  bool _isLoading = false;
  StorageInfo? _storageInfo;
  CleanupResult? _cleanupResult;

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  Future<void> _loadStorageInfo() async {
    setState(() => _isLoading = true);
    final info = await AvatarStorageCleanup.getStorageInfo();
    setState(() {
      _storageInfo = info;
      _isLoading = false;
    });
  }

  Future<void> _performCleanup() async {
    setState(() => _isLoading = true);
    final result = await AvatarStorageCleanup.performCleanup();
    setState(() {
      _cleanupResult = result;
      _isLoading = false;
    });
    await _loadStorageInfo();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.cleaning_services, color: Colors.blue, size: 24.r),
          SizedBox(width: 8.w),
          Text('Avatar Storage Cleanup', style: TextStyle(fontSize: 16.sp)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else if (_cleanupResult != null) ...[
              if (_cleanupResult!.success) ...[
                Icon(Icons.check_circle, color: Colors.green, size: 48.r),
                SizedBox(height: 16.h),
                Text(
                  'Cleanup Successful!',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Files deleted: ${_cleanupResult!.deletedFiles}',
                  style: TextStyle(fontSize: 14.sp),
                ),
                Text(
                  'Space freed: ${_cleanupResult!.freedSpaceMB.toStringAsFixed(2)} MB',
                  style: TextStyle(fontSize: 14.sp),
                ),
              ] else ...[
                Icon(Icons.error, color: Colors.red, size: 48.r),
                SizedBox(height: 16.h),
                Text(
                  'Cleanup Failed',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  _cleanupResult!.error ?? 'Unknown error',
                  style: TextStyle(fontSize: 14.sp),
                ),
              ],
            ] else if (_storageInfo != null) ...[
              Text(
                'Current Storage Usage',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12.h),
              _buildStorageCard(),
            ],
          ],
        ),
      ),
      actions: [
        if (_cleanupResult != null)
          TextButton(
            onPressed: () {
              setState(() => _cleanupResult = null);
              _loadStorageInfo();
            },
            child: Text('Back', style: TextStyle(fontSize: 14.sp)),
          )
        else
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(fontSize: 14.sp)),
          ),
        if (_cleanupResult == null)
          ElevatedButton(
            onPressed: _isLoading ? null : _performCleanup,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: Text('Clean Up', style: TextStyle(fontSize: 14.sp)),
          )
        else if (_cleanupResult!.success)
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Done', style: TextStyle(fontSize: 14.sp)),
          ),
      ],
    );
  }

  Widget _buildStorageCard() {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Files:',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14.sp),
              ),
              Text(
                '${_storageInfo!.totalFiles}',
                style: TextStyle(fontSize: 14.sp),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Size:',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14.sp),
              ),
              Text(
                '${_storageInfo!.totalSizeMB.toStringAsFixed(2)} MB',
                style: TextStyle(fontSize: 14.sp),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
