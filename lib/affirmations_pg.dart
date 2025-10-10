import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

class AffirmationsPage extends StatefulWidget {
  const AffirmationsPage({super.key});

  @override
  State<AffirmationsPage> createState() => _AffirmationsPageState();
}

class _AffirmationsPageState extends State<AffirmationsPage> {
  static final List<Map<String, String>> affirmationsList = const [
    {
      'title': 'Daily Affirmation',
      'subtitle': '''
Becoming better every day.
My daily actions shape my future.
I choose mental strength over short pleasures.
I’m becoming the person I want to be.
Progress, not perfection.
Peace and discipline guide my path.
              ''',
    },
    {
      'title': 'Affirmation 2',
      'subtitle': '''
Small steps lead to big change.
I’m consistent and disciplined.
I build habits that strengthen me.
My daily actions shape my future.
I’m becoming the person I want to be.
Progress, not perfection.
Each day, I show up for myself.
''',
    },
  ];

  static int currentAff = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              "assets/affirmations/base_img.jpg",
            ), // your image file
            fit: BoxFit.cover, // makes it fill the screen
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
                    icon: Icon(CupertinoIcons.back, color: Colors.white),
                    alignment: Alignment.topRight,
                  ),
                  Text(
                    'Recite Affirmations',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Builder(
                    builder: (ctx) => IconButton(
                      onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                      icon: HugeIcon(
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    height: 1.6, // Better line spacing
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
                                  icon: Icon(
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

                // optional footer
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
                    onPressed: () {
                      // generate affirmation action
                      // replace with your generation logic
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Generate'),
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
