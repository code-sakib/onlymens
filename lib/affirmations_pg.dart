import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
// Import your affirmation service
// import 'services/affirmation_service.dart';

class AffirmationsPage extends StatefulWidget {
  const AffirmationsPage({super.key});

  @override
  State<AffirmationsPage> createState() => _AffirmationsPageState();
}

class _AffirmationsPageState extends State<AffirmationsPage> {
  final List<Map<String, String>> affirmationsList = [
    {
      'title': 'Daily Affirmation',
      'subtitle': '''
Becoming better every day.
My daily actions shape my future.
I choose mental strength over short pleasures.
I'm becoming the person I want to be.
Progress, not perfection.
Peace and discipline guide my path.
              ''',
    },
    {
      'title': 'Affirmation 2',
      'subtitle': '''
Small steps lead to big change.
I'm consistent and disciplined.
I build habits that strengthen me.
My daily actions shape my future.
I'm becoming the person I want to be.
Progress, not perfection.
Each day, I show up for myself.
''',
    },
  ];

  int currentAff = 0;
  bool isGenerating = false;
  // final AffirmationService _affirmationService = AffirmationService();

  Future<void> _generateAffirmation() async {
    setState(() {
      isGenerating = true;
    });

    try {
      // Replace with your actual service call
      // final generatedText = await _affirmationService.generateAffirmation();

      // Simulated delay for demo - remove this in production
      await Future.delayed(const Duration(seconds: 2));

      // Mock generated affirmation - replace with actual API response
      final generatedText = '''
I am stronger than my urges.
Every day without relapse is a victory.
I respect myself and my future.
My mind is my greatest asset.
I choose clarity over temporary pleasure.
Discipline today, freedom tomorrow.
      ''';

      if (mounted) {
        setState(() {
          isGenerating = false;
        });
        _showAffirmationDialog(generatedText);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isGenerating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate affirmation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAffirmationDialog(String generatedText) {
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedAiEditing,
                    color: Colors.deepPurple,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Generated Affirmation',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
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
                    onPressed: () {
                      _addGeneratedAffirmation(generatedText);
                      Navigator.of(dialogContext).pop();
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
    );
  }

  void _addGeneratedAffirmation(String affirmationText) {
    setState(() {
      final newAffirmation = {
        'title': 'Generated Affirmation ${affirmationsList.length}',
        'subtitle': affirmationText,
      };
      affirmationsList.add(newAffirmation);
      currentAff = affirmationsList.length - 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Affirmation added successfully!'),
        backgroundColor: Colors.deepPurple,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/affirmations/base_img.jpg"),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(CupertinoIcons.back, color: Colors.white),
                    alignment: Alignment.topRight,
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
                      alignment: Alignment.topRight,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 120,
                  horizontal: 10,
                ),
                child: Text(
                  affirmationsList[currentAff]['subtitle']!,
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
                ),
              ),
            ],
          ),
        ),
      ),
      endDrawer: Builder(
        builder: (drawerContext) {
          final double drawerWidth =
              MediaQuery.of(drawerContext).size.width / 2;

          return Drawer(
            width: drawerWidth,
            backgroundColor: Theme.of(drawerContext).scaffoldBackgroundColor,
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
                  child: ListView.separated(
                    itemCount: affirmationsList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (_, index) {
                      final currentItem = affirmationsList[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ListTile(
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
                              setState(() {
                                currentAff = index;
                              });
                              Navigator.of(drawerContext).pop();
                            },
                          ),
                          affirmationsList.length - 1 == index
                              ? IconButton(
                                  onPressed: () {},
                                  icon: const Icon(
                                    Icons.add_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isGenerating ? null : _generateAffirmation,
                    child: isGenerating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text('Generate'),
                              SizedBox(width: 8),
                              HugeIcon(icon: HugeIcons.strokeRoundedAiEditing),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
