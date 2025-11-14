import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:onlymens/features/affirmations/affirmations_data.dart';
import 'package:onlymens/utilis/snackbar.dart';

// Affirmations Page with ScreenUtil

class AffirmationsPage extends StatefulWidget {
  const AffirmationsPage({super.key});

  @override
  State<AffirmationsPage> createState() => _AffirmationsPageState();
}

class _AffirmationsPageState extends State<AffirmationsPage> {
  // ValueNotifiers for reactive updates without full rebuilds
  final ValueNotifier<List<Map<String, dynamic>>> _affirmationsNotifier =
      ValueNotifier([]);
  final ValueNotifier<int> _currentAffNotifier = ValueNotifier(0);
  final ValueNotifier<bool> _isGeneratingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  final ValueNotifier<int> _remainingGenerationsNotifier = ValueNotifier(3);

  @override
  void initState() {
    super.initState();
    _loadAffirmations();
    _loadGenerationLimit();
  }

  @override
  void dispose() {
    _affirmationsNotifier.dispose();
    _currentAffNotifier.dispose();
    _isGeneratingNotifier.dispose();
    _isLoadingNotifier.dispose();
    _remainingGenerationsNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadAffirmations() async {
    _isLoadingNotifier.value = true;
    try {
      final affirmations = await AffirmationData.fetchAffirmations();

      final defaultAffirmation = {
        'id': 'default_1',
        'title': 'Daily Affirmation',
        'subtitle': '''Becoming better every day.
My daily actions shape my future.
I choose mental strength over short pleasures.
I'm becoming the person I want to be.
Progress, not perfection.
Peace and discipline guide my path.''',
        'isDefault': true,
      };

      // Always show default if less than 3 user affirmations
      if (affirmations.length < 3) {
        _affirmationsNotifier.value = [...affirmations, defaultAffirmation];
      } else {
        _affirmationsNotifier.value = affirmations;
      }

      // Adjust currentAff if needed
      if (_currentAffNotifier.value >= _affirmationsNotifier.value.length) {
        _currentAffNotifier.value = _affirmationsNotifier.value.length - 1;
      }

      _isLoadingNotifier.value = false;
    } catch (e) {
      print('Error loading affirmations: $e');
      _isLoadingNotifier.value = false;
      Utilis.showSnackBar('Failed to load affirmations', isErr: true);
    }
  }

  Future<void> _loadGenerationLimit() async {
    try {
      final remaining = await AffirmationData.getRemainingGenerations();
      _remainingGenerationsNotifier.value = remaining;
    } catch (e) {
      print('Error loading generation limit: $e');
    }
  }

  bool _canAddMore() {
    final nonDefaultCount = _affirmationsNotifier.value
        .where((a) => !(a['isDefault'] ?? false))
        .length;
    return nonDefaultCount < 3;
  }

  Future<void> _generateAffirmation() async {
    // Check local limit first
    if (!_canAddMore()) {
      Navigator.of(context).pop(); // Close drawer first
      Utilis.showSnackBar(
        'Maximum 3 affirmations allowed. Delete one to add more.',
        isErr: true,
      );
      return;
    }

    // Check daily generation limit
    if (_remainingGenerationsNotifier.value <= 0) {
      Navigator.of(context).pop(); // Close drawer first
      Utilis.showSnackBar(
        'Daily generation limit reached (3/day). Resets tomorrow!',
        isErr: true,
      );
      return;
    }

    _isGeneratingNotifier.value = true;

    try {
      final result = await AffirmationData.generateAffirmationWithAI();

      _isGeneratingNotifier.value = false;
      _remainingGenerationsNotifier.value = result['remainingToday'] ?? 0;
      _showGeneratedAffirmationDialog(result['affirmation'] ?? '');
    } catch (e) {
      _isGeneratingNotifier.value = false;
      Navigator.of(context).pop(); // Close drawer on error
      Utilis.showSnackBar('Failed to generate: $e', isErr: true);
    }
  }

  void _showAddAffirmationDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.deepPurple.withOpacity(0.3), Colors.grey[900]!],
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedEdit02,
                      color: Colors.deepPurple,
                      size: 28.r,
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      'Create Your Affirmation',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                TextField(
                  controller: titleController,
                  style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14.sp,
                    ),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(
                        color: Colors.deepPurple.withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(
                        color: Colors.deepPurple.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(
                        color: Colors.deepPurple,
                        width: 2.w,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                TextField(
                  controller: contentController,
                  style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  maxLines: 8,
                  maxLength: 400,
                  decoration: InputDecoration(
                    labelText: 'Affirmation Content',
                    labelStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14.sp,
                    ),
                    hintStyle: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12.sp,
                    ),
                    filled: true,
                    fillColor: Colors.black26,
                    counterStyle: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12.sp,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(
                        color: Colors.deepPurple.withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(
                        color: Colors.deepPurple.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(
                        color: Colors.deepPurple,
                        width: 2.w,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey, fontSize: 16.sp),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24.w,
                          vertical: 12.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final content = contentController.text.trim();

                        if (title.isEmpty || content.isEmpty) {
                          Utilis.showSnackBar(
                            'Please fill in all fields',
                            isErr: true,
                          );
                          return;
                        }

                        Navigator.of(dialogContext).pop();
                        await _addCustomAffirmation(title, content);
                      },
                      icon: Icon(Icons.add, size: 20.r),
                      label: Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGeneratedAffirmationDialog(String generatedText) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isRegenerating = false;

          return Dialog(
            backgroundColor: Colors.grey[900],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Container(
              padding: EdgeInsets.all(24.r),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.r),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.deepPurple.withOpacity(0.3),
                    Colors.grey[900]!,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Generated Affirmation',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        onPressed: isRegenerating
                            ? null
                            : () async {
                                if (_remainingGenerationsNotifier.value <= 0) {
                                  Utilis.showSnackBar(
                                    'Daily generation limit reached (3/day). Try tomorrow!',
                                    isErr: true,
                                  );
                                  return;
                                }

                                setDialogState(() => isRegenerating = true);

                                try {
                                  final result =
                                      await AffirmationData.generateAffirmationWithAI();
                                  _remainingGenerationsNotifier.value =
                                      result['remainingToday'] ?? 0;

                                  Navigator.of(dialogContext).pop();
                                  _showGeneratedAffirmationDialog(
                                    result['affirmation'] ?? '',
                                  );
                                } catch (e) {
                                  setDialogState(() => isRegenerating = false);
                                  Utilis.showSnackBar(
                                    'Failed to regenerate: $e',
                                    isErr: true,
                                  );
                                }
                              },
                        icon: isRegenerating
                            ? SizedBox(
                                width: 20.r,
                                height: 20.r,
                                child: CupertinoActivityIndicator(
                                  color: Colors.white,
                                  radius: 8.r,
                                ),
                              )
                            : Icon(
                                Icons.refresh,
                                color: Colors.white38,
                                size: 24.r,
                              ),
                        tooltip: 'Regenerate',
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  Container(
                    constraints: BoxConstraints(maxHeight: 300.h),
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: Colors.deepPurple.withOpacity(0.3),
                        width: 1.w,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        generatedText,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isRegenerating
                            ? null
                            : () => Navigator.of(dialogContext).pop(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey, fontSize: 16.sp),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24.w,
                            vertical: 12.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                        onPressed: isRegenerating
                            ? null
                            : () async {
                                Navigator.of(dialogContext).pop();
                                await _addGeneratedAffirmation(generatedText);
                              },
                        icon: Icon(Icons.check, size: 20.r),
                        label: Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addGeneratedAffirmation(String affirmationText) async {
    try {
      await AffirmationData.addAffirmation(
        "Affirmation ${_affirmationsNotifier.value.where((a) => !(a['isDefault'] ?? false)).length + 1}",
        affirmationText,
      );

      await _loadAffirmations();
      Utilis.showSnackBar('Affirmation added successfully!');
    } catch (e) {
      Utilis.showSnackBar('Failed to add: $e', isErr: true);
    }
  }

  Future<void> _addCustomAffirmation(String title, String content) async {
    try {
      await AffirmationData.addAffirmation(title, content);
      await _loadAffirmations();

      // Delay snackbar slightly to ensure it appears after dialog closes
      await Future.delayed(const Duration(milliseconds: 100));
      Utilis.showSnackBar('Affirmation added successfully!');
    } catch (e) {
      Utilis.showSnackBar('Failed to add: $e', isErr: true);
    }
  }

  Future<void> _deleteAffirmation(
    String affirmationId,
    bool isDefault,
    BuildContext drawerContext,
  ) async {
    if (isDefault) {
      Navigator.of(drawerContext).pop(); // Close drawer first
      await Future.delayed(const Duration(milliseconds: 100));
      Utilis.showSnackBar('Cannot delete default affirmation', isErr: true);
      return;
    }

    try {
      // Close drawer immediately for smooth UX
      Navigator.of(drawerContext).pop();

      await AffirmationData.deleteAffirmation(affirmationId);
      await _loadAffirmations();

      await Future.delayed(const Duration(milliseconds: 100));
      Utilis.showSnackBar('Affirmation deleted');
    } catch (e) {
      Utilis.showSnackBar('Failed to delete: $e', isErr: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoadingNotifier,
      builder: (context, isLoading, _) {
        if (isLoading) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/affirmations/base_img.jpg"),
                  fit: BoxFit.cover,
                ),
              ),
              child: Center(
                child: CupertinoActivityIndicator(
                  color: Colors.white,
                  radius: 10.r,
                ),
              ),
            ),
          );
        }

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/affirmations/base_img.jpg"),
                fit: BoxFit.cover,
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top bar row (back, title, bookmark)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: Icon(
                            CupertinoIcons.back,
                            color: Colors.white,
                            size: 24.r,
                          ),
                        ),
                        Text(
                          'Recite Your Affirmations',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Builder(
                          builder: (ctx) => IconButton(
                            onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                            icon: HugeIcon(
                              icon: HugeIcons.strokeRoundedBookmarkCheck01,
                              color: Colors.white,
                              size: 24.r,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Expandable scrollable content area
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 24.h,
                      ),
                      child: Center(
                        child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                          valueListenable: _affirmationsNotifier,
                          builder: (context, affirmations, _) {
                            return ValueListenableBuilder<int>(
                              valueListenable: _currentAffNotifier,
                              builder: (context, currentAff, _) {
                                final text = affirmations.isEmpty
                                    ? 'Add your first affirmation to get started!'
                                    : affirmations[currentAff]['subtitle'] ??
                                          '';

                                return SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Text(
                                    text,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22.sp,
                                      height: 1.6,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                      shadows: const [
                                        Shadow(
                                          blurRadius: 12,
                                          color: Colors.black54,
                                          offset: Offset(2, 2),
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                    softWrap: true,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          endDrawer: Builder(
            builder: (drawerContext) {
              return Drawer(
                width: 0.5.sw,
                backgroundColor: Theme.of(
                  drawerContext,
                ).scaffoldBackgroundColor,
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(8.r),
                      child: Text(
                        '- Your Affirmations -',
                        style: Theme.of(drawerContext).textTheme.labelSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Flexible(
                      child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                        valueListenable: _affirmationsNotifier,
                        builder: (context, affirmations, _) {
                          return ValueListenableBuilder<int>(
                            valueListenable: _currentAffNotifier,
                            builder: (context, currentAff, _) {
                              return ListView.separated(
                                itemCount: affirmations.length,
                                separatorBuilder: (_, __) =>
                                    SizedBox(height: 4.h),
                                itemBuilder: (_, index) {
                                  final currentItem = affirmations[index];
                                  final isDefault =
                                      currentItem['isDefault'] ?? false;

                                  return ListTile(
                                    title: Text(
                                      currentItem['title'] ?? '',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.sp,
                                      ),
                                    ),
                                    tileColor: currentAff != index
                                        ? Colors.grey[900]
                                        : Colors.deepPurple,
                                    subtitle: Text(
                                      currentItem['subtitle'] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12.sp),
                                    ),
                                    onTap: () {
                                      _currentAffNotifier.value = index;
                                      Navigator.of(drawerContext).pop();
                                    },
                                    onLongPress: () {
                                      if (!isDefault) {
                                        showDialog(
                                          context: drawerContext,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor: Colors.grey[900],
                                            title: Text(
                                              'Delete Affirmation',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 18.sp,
                                              ),
                                            ),
                                            content: Text(
                                              'Are you sure you want to delete "${currentItem['title']}"?',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14.sp,
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx),
                                                child: Text(
                                                  'Cancel',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14.sp,
                                                  ),
                                                ),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                ),
                                                onPressed: () {
                                                  Navigator.pop(ctx);
                                                  _deleteAffirmation(
                                                    currentItem['id'],
                                                    isDefault,
                                                    drawerContext,
                                                  );
                                                },
                                                child: Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    fontSize: 14.sp,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          minimumSize: Size(double.infinity, 45.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                        onPressed: () {
                          if (!_canAddMore()) {
                            Navigator.of(drawerContext).pop();
                            Utilis.showSnackBar(
                              'Maximum 3 affirmations allowed. Long press to delete one.',
                              isErr: true,
                            );
                            return;
                          }
                          _showAddAffirmationDialog();
                        },
                        icon: Icon(Icons.add, color: Colors.white, size: 20.r),
                        label: Text(
                          'Add Custom',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Padding(
                      padding: EdgeInsets.all(8.r),
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _isGeneratingNotifier,
                        builder: (context, isGenerating, _) {
                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              minimumSize: Size(double.infinity, 45.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                            onPressed: isGenerating
                                ? null
                                : _generateAffirmation,
                            child: isGenerating
                                ? SizedBox(
                                    height: 20.h,
                                    width: 20.w,
                                    child: CupertinoActivityIndicator(
                                      color: Colors.white,
                                      radius: 8.r,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Generate',
                                        style: TextStyle(fontSize: 14.sp),
                                      ),
                                      SizedBox(width: 8.w),
                                      HugeIcon(
                                        icon: HugeIcons.strokeRoundedAiEditing,
                                        size: 20.r,
                                      ),
                                    ],
                                  ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
