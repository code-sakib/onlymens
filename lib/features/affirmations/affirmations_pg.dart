import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:onlymens/features/affirmations/affirmations_data.dart';
import 'package:onlymens/utilis/snackbar.dart';

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
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
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedEdit02,
                      color: Colors.deepPurple,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Create Your Affirmation',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.deepPurple.withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.deepPurple.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.deepPurple,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 8,
                  maxLength: 400,
                  decoration: InputDecoration(
                    labelText: 'Affirmation Content',
                    labelStyle: TextStyle(color: Colors.grey[400]),

                    hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                    filled: true,
                    fillColor: Colors.black26,
                    counterStyle: TextStyle(color: Colors.grey[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.deepPurple.withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.deepPurple.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.deepPurple,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
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
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 16,
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
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
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
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CupertinoActivityIndicator(
                                  color: Colors.white,
                                  radius: 8,
                                ),
                              )
                            : const Icon(
                                Icons.refresh,
                                color: Colors.white38,
                                size: 24,
                              ),
                        tooltip: 'Regenerate',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.deepPurple.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        generatedText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isRegenerating
                            ? null
                            : () => Navigator.of(dialogContext).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: isRegenerating
                            ? null
                            : () async {
                                Navigator.of(dialogContext).pop();
                                await _addGeneratedAffirmation(generatedText);
                              },
                        icon: const Icon(Icons.check, size: 20),
                        label: const Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 16,
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
              child: const Center(
                child: CupertinoActivityIndicator(
                  color: Colors.white,
                  radius: 8,
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
            // inside Scaffold.body: (replace your current Center(...) block with this)
            child: Container(
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
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: const Icon(
                              CupertinoIcons.back,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Recite Your Affirmations',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Builder(
                            builder: (ctx) => IconButton(
                              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                              icon: const HugeIcon(
                                icon: HugeIcons.strokeRoundedBookmarkCheck01,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Expandable scrollable content area
                    Expanded(
                      child: Padding(
                        // reduce big vertical padding — use comfortable values
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 24.0,
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
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        height: 1.6,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                        shadows: [
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
          ),
          endDrawer: Builder(
            builder: (drawerContext) {
              final double drawerWidth =
                  MediaQuery.of(drawerContext).size.width / 2;

              return Drawer(
                width: drawerWidth,
                backgroundColor: Theme.of(
                  drawerContext,
                ).scaffoldBackgroundColor,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
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
                                    const SizedBox(height: 4),
                                itemBuilder: (_, index) {
                                  final currentItem = affirmations[index];
                                  final isDefault =
                                      currentItem['isDefault'] ?? false;

                                  return ListTile(
                                    title: Text(
                                      currentItem['title'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    tileColor: currentAff != index
                                        ? Colors.grey[900]
                                        : Colors.deepPurple,
                                    subtitle: Text(
                                      currentItem['subtitle'] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
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
                                            title: const Text(
                                              'Delete Affirmation',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                            content: Text(
                                              'Are you sure you want to delete "${currentItem['title']}"?',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx),
                                                child: const Text(
                                                  'Cancel',
                                                  style: TextStyle(
                                                    color: Colors.white,
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
                                                child: const Text('Delete'),
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
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          minimumSize: const Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text(
                          'Add Custom',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _isGeneratingNotifier,
                        builder: (context, isGenerating, _) {
                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              minimumSize: const Size(double.infinity, 45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: isGenerating
                                ? null
                                : _generateAffirmation,
                            child: isGenerating
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CupertinoActivityIndicator(
                                      color: Colors.white,
                                      radius: 8,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Text('Generate'),
                                      SizedBox(width: 8),
                                      HugeIcon(
                                        icon: HugeIcons.strokeRoundedAiEditing,
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
