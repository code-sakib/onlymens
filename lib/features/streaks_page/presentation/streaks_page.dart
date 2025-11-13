import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:onlymens/core/globals.dart';
import 'package:onlymens/features/avatar/avatar_pg.dart';
import 'package:onlymens/features/streaks_page/presentation/pTimer.dart';
import 'package:onlymens/guides/blogs.dart';
import 'package:onlymens/guides/guides_pg.dart';
import 'package:onlymens/utilis/size_config.dart';
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
            SizedBox(
              height: SizeConfig.screenHeight / 1.9,
              child: TimerComponents(),
            ),

            secondRowButtons(context),
            const SizedBox(height: 24),

            // Daily Motivation Section
            const DailyMotivationWidget(),
            const SizedBox(height: 24),

            // // Progress Insights Section
            // _buildProgressInsights(),
            // const SizedBox(height: 24),

            // Blog Articles Section
            // Blog Articles Section
            FutureBuilder<List<BlogPost>>(
              future:
                  BlogManager.fetchTodayBlogs(), // ✅ fetches today's featured blogs
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CupertinoActivityIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return fallbackBlogs(context); // ✅ uses fallback blogs
                }

                final blogs = snapshot.data!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '  Latest Researches',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: blogs.length,
                      itemBuilder: (context, index) {
                        final blog = blogs[index];
                        return blogCard(
                          context,
                          blog.toJson(),
                        ); // ✅ pass as Map<String,dynamic>
                      },
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // // Community Support Section
            // _buildCommunitySupportSection(),
            const SizedBox(height: 24),

            // Quick Tips Section
            LevelGuideTipsWidget(),
            const SizedBox(height: 40),
          ],
        ),
      ),
      drawer: AvatarLevelsDrawer(),
      floatingActionButton: // In settings page or debug menu
      ElevatedButton(
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

/// One-time migration and cleanup utility
/// Run this once to clean up old avatar storage
class AvatarStorageCleanup {
  /// Main cleanup function - call this once from settings or debug menu
  static Future<CleanupResult> performCleanup() async {
    try {
      print('🧹 Starting Avatar Storage Cleanup...');

      int deletedFiles = 0;
      double freedSpaceMB = 0.0;
      List<String> deletedFileNames = [];

      // 1. Clean up Documents/avatars directory (old uncompressed files)
      final docsResult = await _cleanupDocumentsDirectory();
      deletedFiles += docsResult['count'] as int;
      freedSpaceMB += docsResult['size'] as double;
      deletedFileNames.addAll(docsResult['files'] as List<String>);

      // 2. Clean up Application Support directory (old location)
      final supportResult = await _cleanupApplicationSupportDirectory();
      deletedFiles += supportResult['count'] as int;
      freedSpaceMB += supportResult['size'] as double;
      deletedFileNames.addAll(supportResult['files'] as List<String>);

      // 3. Clean up any orphaned files
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

  /// Clean up Documents/avatars directory
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

            // Delete old uncompressed files (level_X.glb)
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

  /// Clean up Application Support directory (old location)
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

        // Delete empty directory
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

  /// Clean up orphaned files (files that shouldn't exist)
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

            // Delete any file that's not a compressed avatar
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

  /// Get current storage usage
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

// Result classes
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

/// UI Widget to show cleanup options
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
          Icon(Icons.cleaning_services, color: Colors.blue),
          SizedBox(width: 8),
          Text('Avatar Storage Cleanup'),
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
                Icon(Icons.check_circle, color: Colors.green, size: 48),
                SizedBox(height: 16),
                Text(
                  'Cleanup Successful!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                SizedBox(height: 8),
                Text('Files deleted: ${_cleanupResult!.deletedFiles}'),
                Text(
                  'Space freed: ${_cleanupResult!.freedSpaceMB.toStringAsFixed(2)} MB',
                ),
                if (_cleanupResult!.deletedFileNames.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Text(
                    'Deleted files:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ..._cleanupResult!.deletedFileNames.map(
                    (name) => Padding(
                      padding: EdgeInsets.only(left: 8, top: 4),
                      child: Text(
                        '• $name',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                  ),
                ],
              ] else ...[
                Icon(Icons.error, color: Colors.red, size: 48),
                SizedBox(height: 16),
                Text(
                  'Cleanup Failed',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: 8),
                Text(_cleanupResult!.error ?? 'Unknown error'),
              ],
            ] else if (_storageInfo != null) ...[
              Text(
                'Current Storage Usage',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              _buildStorageCard(),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'What will be cleaned:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Old uncompressed avatar files (level_X.glb)\n'
                      '• Files from old Application Support location\n'
                      '• Any orphaned or corrupted files',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
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
            child: Text('Back'),
          )
        else
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        if (_cleanupResult == null)
          ElevatedButton(
            onPressed: _isLoading ? null : _performCleanup,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: Text('Clean Up'),
          )
        else if (_cleanupResult!.success)
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Done'),
          ),
      ],
    );
  }

  Widget _buildStorageCard() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Files:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Text('${_storageInfo!.totalFiles}'),
            ],
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Size:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Text('${_storageInfo!.totalSizeMB.toStringAsFixed(2)} MB'),
            ],
          ),
          if (_storageInfo!.files.isNotEmpty) ...[
            Divider(height: 16),
            ..._storageInfo!.files.map(
              (file) => Padding(
                padding: EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      file.isCompressed ? Icons.check_circle : Icons.warning,
                      size: 16,
                      color: file.isCompressed ? Colors.green : Colors.orange,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(file.name, style: TextStyle(fontSize: 12)),
                    ),
                    Text(
                      '${file.sizeMB.toStringAsFixed(2)} MB',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
