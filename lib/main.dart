import 'package:feedback/feedback.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:onlymens/core/approuter.dart';
import 'package:onlymens/core/apptheme.dart';
import 'package:onlymens/core/globals.dart';
import 'package:onlymens/firebase_options.dart';
import 'package:onlymens/utilis/size_config.dart';
import 'package:onlymens/utilis/snackbar.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // .env loaded
  await dotenv.load(fileName: ".env");

  // init shared prefs
  prefs = await SharedPreferences.getInstance();

  // Set status bar + nav bar theme + portrait mode
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // After user authentication
  // await AvatarManager.initializeForNewUser();

  // await auth.signOut();
  // await prefs.clear();
  runApp(
    BetterFeedback(
      theme: FeedbackThemeData(
        background: Colors.black.withOpacity(0.7),
        feedbackSheetColor: Colors.grey,
        drawColors: [Colors.red, Colors.blue, Colors.green, Colors.yellow],
        activeFeedbackModeColor: Colors.deepPurple,
      ),
      child: const MyApp(),
    ),
  );
  //  seedAllLevelGuides();
  // seedBlogsComplete()
  // updateMUsersWithWesternData();

  // uploadSeedPosts();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // sizes with context init
    SizeConfig.init(context);

    hasInternet.then((value) {
      if (!value) {
        print('no internet');
      } else {
        print(' internet available');
      }
    });

    return SafeArea(
      child: MaterialApp.router(
        routerConfig: approutes,
        title: 'OnlyMens',
        theme: AppTheme2.theme,
        scaffoldMessengerKey: Utilis.messengerKey,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

Future<void> seedDummyUsers() async {
  final firestore = FirebaseFirestore.instance;

  // random names
  final names = [
    "Aarav",
    "Vivaan",
    "Aditya",
    "Ishaan",
    "Kabir",
    "Ananya",
    "Diya",
    "Aanya",
    "Myra",
    "Sara",
    "Aryan",
    "Rohan",
    "Saanvi",
    "Aadhya",
    "Krishna",
    "Arjun",
    "Meera",
    "Riya",
    "Kavya",
    "Dev",
  ];

  // random images
  final imageUrls = [
    "https://randomuser.me/api/portraits/men/1.jpg",
    "https://randomuser.me/api/portraits/men/2.jpg",
    "https://randomuser.me/api/portraits/women/3.jpg",
    "https://randomuser.me/api/portraits/women/4.jpg",
    "https://randomuser.me/api/portraits/men/5.jpg",
    "https://randomuser.me/api/portraits/women/6.jpg",
  ];

  final random = Random();

  for (int i = 1; i <= 20; i++) {
    final userId = "user$i";
    final name = names[random.nextInt(names.length)];
    final img = imageUrls[random.nextInt(imageUrls.length)];

    await firestore
        .collection('users')
        .doc('mUsers') // fixed parent doc
        .collection('userList') // subcollection
        .doc(userId) // doc id user1..user20
        .set({"userId": userId, "name": name, "img": img, "status": "offline"});

    print("✅ Added $userId to mUsers/userList/");
  }
}

p() {
  final Map<String, int> dailyData = {
    '2025-08-31': 2,
    '2025-09-01': 3,
    '2025-09-02': 1,
    '2025-09-03': 0,
    '2025-09-04': 3,
    '2025-09-05': 2,
    '2025-09-06': 3,
    '2025-09-07': 2,
    '2025-09-08': 1,
    '2025-09-09': 3,
    '2025-09-10': 0,
    '2025-09-11': 1,
    '2025-09-12': 2,
    '2025-09-13': 3,
    '2025-09-14': 3,
    '2025-09-15': 0,
    '2025-09-16': 2,
    '2025-09-17': 1,
    '2025-09-18': 3,
    '2025-09-19': 3,
    '2025-09-20': 1,
    '2025-09-21': 0,
    '2025-09-22': 3,
    '2025-09-23': 2,
    '2025-09-24': 2,
    '2025-09-25': 1,
    '2025-09-26': 3,
    '2025-09-27': 0,
    '2025-09-28': 3,
    '2025-09-29': 1,
    '2025-09-30': 2,
    '2025-10-01': 3,
    '2025-10-02': 2,
    '2025-10-03': 0,
    '2025-10-04': 3,
    '2025-10-05': 3,
    '2025-10-06': 1,
    '2025-10-07': 2,
    '2025-10-08': 3,
    '2025-10-09': 0,
    '2025-10-10': 2,
    '2025-10-11': 3,
    '2025-10-12': 3,
    '2025-10-13': 1,
    '2025-10-14': 2,
    '2025-10-15': 0,
    '2025-10-16': 2,
    '2025-10-17': 1,
    '2025-10-18': 0,
    '2025-10-19': 2,
    '2025-10-20': 3,
    '2025-10-21': 2,
    '2025-10-22': 2,
    '2025-10-23': 0,
    '2025-10-24': 0,
    '2025-10-25': 3,
    '2025-10-26': 3,
    '2025-10-27': 3,
    '2025-10-28': 3,
    '2025-10-29': 3,
    '2025-10-30': 3,
    '2025-10-31': 3,
    '2025-11-01': 3,
  };

  cloudDB
      .collection('users')
      .doc('y7cs7Ul45lRVmzCykxsIPiO5XqD2')
      .collection('streaks')
      .doc('total')
      .set({'dailyData': dailyData}, SetOptions(merge: true))
      .onError((e, s) {
        print(s);
      });
}

/// Call this once (or from an admin/debug screen) to seed/update all 4 level guide docs.
Future<void> seedAllLevelGuides() async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  const Map<int, String> levelRanges = {
    1: '1-7',
    2: '8-14',
    3: '15-22',
    4: '23-30',
  };

  // Suggested guides for each level (4 tips when possible; helper will normalize).
  final Map<int, List<String>> suggestedTips = {
    1: [
      'On this first step be gentle with yourself — change takes time.',
      'When urges strike, pause and breathe: try to ignore impulsive thoughts for 5 minutes.',
      'Do a short activity (walk, splash water, push-ups) to break the loop.',
      'Reduce immediate triggers: remove or block easy access to them.',
    ],
    2: [
      'You\'re building momentum — create a simple morning routine to anchor the day.',
      'Use a 20–30 minute workout or brisk walk to lift mood and reduce cravings.',
      'Journal triggers and small wins to spot patterns and keep motivation.',
      'Set small weekly goals and reward yourself on consistency (not perfection).',
    ],
    3: [
      'Deepen your practice: try 10–15 minutes of mindfulness or focused breathing.',
      'Strengthen social support — share progress with a trusted person or group.',
      'Plan and rehearse coping strategies for high-risk situations.',
      'Intentionally practice identity statements: "I am someone who..." and act on them.',
    ],
    4: [
      'You\'re doing great — keep consistency, not intensity; steady wins.',
      'Help or mentor someone earlier in their journey — teaching reinforces habit.',
      'Define long-term values and daily disciplines that align with them.',
      'Celebrate progress and set scalable growth targets for the next phase.',
    ],
  };

  // Helper: ensure tips length is between 3 and 4.
  List<String> normalizeTips(List<String> tips) {
    final List<String> t = List<String>.from(tips);
    if (t.length > 4) return t.sublist(0, 4);
    if (t.length >= 3) return t;
    // If less than 3, pad with thoughtful fallbacks
    final List<String> fallbacks = [
      'Keep showing up — small consistent actions add up.',
      'If you slip, treat it as feedback and plan one concrete next step.',
      'Reach out for support when things feel overwhelming.',
    ];
    int i = 0;
    while (t.length < 3 && i < fallbacks.length) {
      t.add(fallbacks[i++]);
    }
    return t;
  }

  final WriteBatch batch = firestore.batch();

  try {
    for (final entry in levelRanges.entries) {
      final int level = entry.key;
      final String rangeKey = entry.value;
      final List<String> tips = normalizeTips(suggestedTips[level] ?? []);

      final docRef = firestore.collection('lvlguide').doc(rangeKey);

      batch.set(
        docRef,
        {
          'title': 'Level $level Guide (Days $rangeKey)',
          'guide': tips,
          'level': level,
          'dayRange': rangeKey,
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      ); // merge: true to avoid wiping other admin fields
    }

    await batch.commit();
    print('✅ Successfully seeded/updated all lvlguide documents.');
  } catch (e) {
    print('❌ Failed to seed lvlguide docs: $e');
  }
}

Future<void> seedTodayBlogs() async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  try {
    final docRef = firestore.collection('blogs').doc('today');

    await docRef.set({
      '1': {
        'title': 'How Porn Paves the Way to Misery',
        'excerpt':
            'Understanding the psychological and physiological impact of pornography addiction and its devastating effects on mental health, relationships, and personal growth.',
        'iconName': 'psychology',
        'colorHex': '#F44336',
        'route': '/blog/misery',
      },
      '2': {
        'title': 'Rewiring Your Brain: The Science of Recovery',
        'excerpt':
            'Discover how neuroplasticity can help you rebuild neural pathways, restore dopamine sensitivity, and reclaim control over your life.',
        'iconName': 'psychology_alt',
        'colorHex': '#2196F3',
        'route': '/blog/rewiring',
      },
      '3': {
        'title': 'Building Unshakeable Self-Discipline',
        'excerpt':
            'Practical strategies and mindset shifts to develop iron-will discipline that helps you resist urges and build lasting positive habits.',
        'iconName': 'fitness_center',
        'colorHex': '#4CAF50',
        'route': '/blog/discipline',
      },
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print('✅ Successfully seeded blogs/today document with 3 featured blogs.');
  } catch (e) {
    print('❌ Failed to seed blogs/today: $e');
  }
}

Future<void> seedAllBlogs() async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final Map<String, Map<String, dynamic>> allBlogs = {
    'blog1': {
      'title': 'How Porn Paves the Way to Misery',
      'excerpt':
          'Understanding the psychological and physiological impact of pornography addiction and its devastating effects on mental health, relationships, and personal growth.',
      'iconName': 'psychology',
      'colorHex': '#F44336',
      'route': '/blog/misery',
      'category': 'Understanding Addiction',
      'readTime': '8 min',
    },
    'blog2': {
      'title': 'Rewiring Your Brain: The Science of Recovery',
      'excerpt':
          'Discover how neuroplasticity can help you rebuild neural pathways, restore dopamine sensitivity, and reclaim control over your life.',
      'iconName': 'psychology_alt',
      'colorHex': '#2196F3',
      'route': '/blog/rewiring',
      'category': 'Neuroscience',
      'readTime': '10 min',
    },
    'blog3': {
      'title': 'Building Unshakeable Self-Discipline',
      'excerpt':
          'Practical strategies and mindset shifts to develop iron-will discipline that helps you resist urges and build lasting positive habits.',
      'iconName': 'fitness_center',
      'colorHex': '#4CAF50',
      'route': '/blog/discipline',
      'category': 'Habit Building',
      'readTime': '7 min',
    },
    'blog4': {
      'title': 'Understanding Triggers and Patterns',
      'excerpt':
          'Learn to identify your personal triggers, understand the cycle of addiction, and develop awareness strategies to break free from automatic responses.',
      'iconName': 'lightbulb',
      'colorHex': '#FF9800',
      'route': '/blog/triggers',
      'category': 'Self-Awareness',
      'readTime': '6 min',
    },
    'blog5': {
      'title': 'The Power of Community Support',
      'excerpt':
          'Why recovery is easier together. Discover how accountability partners, support groups, and shared experiences accelerate healing and prevent relapse.',
      'iconName': 'favorite',
      'colorHex': '#E91E63',
      'route': '/blog/community',
      'category': 'Support Systems',
      'readTime': '5 min',
    },
    'blog6': {
      'title': 'Mindfulness for Urge Management',
      'excerpt':
          'Master meditation and mindfulness techniques that help you observe urges without acting on them, creating space between stimulus and response.',
      'iconName': 'self_improvement',
      'colorHex': '#9C27B0',
      'route': '/blog/mindfulness',
      'category': 'Mindfulness',
      'readTime': '9 min',
    },
  };

  try {
    final docRef = firestore.collection('blogs').doc('all');

    final Map<String, dynamic> dataWithTimestamp = Map.from(allBlogs);
    dataWithTimestamp['createdAt'] = FieldValue.serverTimestamp();
    dataWithTimestamp['lastUpdated'] = FieldValue.serverTimestamp();

    await docRef.set(dataWithTimestamp, SetOptions(merge: true));

    print(
      '✅ Successfully seeded blogs/all document with ${allBlogs.length} blogs.',
    );
  } catch (e) {
    print('❌ Failed to seed blogs/all: $e');
  }
}

Future<void> updateMUsersWithWesternData() async {
  final firestore = FirebaseFirestore.instance;
  final userListRef = firestore
      .collection('users')
      .doc('mUsers')
      .collection('userList');

  final random = Random();

  // 20 realistic Western male names
  final List<String> names = [
    'Jake',
    'Ethan',
    'Ryan',
    'Liam',
    'Noah',
    'Mason',
    'Lucas',
    'Owen',
    'Logan',
    'Jack',
    'Henry',
    'Leo',
    'Caleb',
    'Aiden',
    'Nathan',
    'Hunter',
    'Connor',
    'Carter',
    'Elijah',
    'Max',
  ];

  final allDocs = await userListRef.get();
  print('Found ${allDocs.docs.length} users to update...');

  WriteBatch batch = firestore.batch();
  int batchCount = 0;

  for (int i = 0; i < allDocs.docs.length; i++) {
    final doc = allDocs.docs[i];
    final uid = doc.id;
    final name = names[i % names.length];

    final statusOptions = ['Online', 'Away', 'Busy'];
    final status = statusOptions[random.nextInt(statusOptions.length)];

    // Ensure totalStreaks > streaks
    final streaks = random.nextInt(15); // 0–14
    final totalStreaks =
        streaks + random.nextInt(50 - streaks) + 1; // > streaks

    final updateData = {
      'uid': uid,
      'name': name,
      'status': status,
      'img': 'https://picsum.photos/200?random=$i',
      'streaks': streaks,
      'totalStreaks': totalStreaks,
      'mUsers': true,
    };

    batch.update(doc.reference, updateData);
    batchCount++;

    // Commit every 400 docs to stay under Firestore’s batch limit
    if (batchCount >= 400) {
      await batch.commit();
      batch = firestore.batch();
      batchCount = 0;
      print('⚡ Partial batch committed.');
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  print('🎯 All mUsers updated with western names, streaks, and valid totals!');
}

Future<void> uploadSeedPosts() async {
  final firestore = FirebaseFirestore.instance;
  print('🚀 Starting seed data upload...');

  final Random rand = Random();

  final List<String> dates = ['2025-11-09', '2025-11-08', '2025-11-07'];

  // Pool of realistic + username-style names
  final List<String> names = [
    'Alex Morgan',
    'MichaelH_23',
    'RyanCole',
    'Jordan_92',
    'ChrisVega',
    'David_Ross',
    'SamBennett',
    'KevinFoxx',
    'TylerG_10',
    'MarcusLane',
    'NoahReed',
    'LiamCarter',
    'LoganP_44',
    'JakeSummers',
    'EthanBlake',
    'Max343',
    'John_232',
    'AidenBrooks',
    'MasonWilde',
    'LeoFord',
    'Petra_01',
    'HunterX',
    'ConnorJ_7',
    'Nate_09',
    'RicoMann',
  ];

  final List<String> sampleTexts = [
    "Day {D} complete! Feeling stronger every day. 💪",
    "Starting fresh again — this time it feels different. 🔥",
    "Just hit {D} days! Grateful for the journey.",
    "Temptations come and go, but I stay solid.",
    "Small wins build the biggest change. 💯",
    "Every relapse teaches something. Keep learning, keep moving.",
    "I can feel my mind getting clearer each week.",
    "One day at a time. The fight is worth it. 🙏",
    "Community strength > urges. Stay strong brothers!",
    "Reset. Rebuild. Rise. Always forward. ⚔️",
  ];

  int globalPostIndex = 1;
  int successCount = 0;

  for (final date in dates) {
    print('📅 Uploading posts for $date...');

    final int postCount = 3 + rand.nextInt(2); // 3–4 posts per date
    final dateParts = date.split('-');
    final dateBase = DateTime.utc(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );

    for (int i = 0; i < postCount; i++) {
      final int index = globalPostIndex;
      final String postId = 'post_$index';
      final String userId = 'default_user_$index';

      // Randomize name (mix of human + username handles)
      final String name = names[rand.nextInt(names.length)];
      final int streaks = rand.nextInt(30); // 0–29
      final int likes = rand.nextInt(10);
      final int views = rand.nextInt(100);

      // 30% chance to use pravatar (real), rest picsum
      final bool usePravatar = rand.nextInt(10) < 3;
      final String dpUrl = usePravatar
          ? 'https://i.pravatar.cc/150?img=${rand.nextInt(70) + 1}'
          : 'https://picsum.photos/200?random=$index';

      // Create text
      String postText = sampleTexts[rand.nextInt(sampleTexts.length)]
          .replaceAll('{D}', streaks.toString());

      // Spread timestamps
      final int minuteOffset = i * 120 + rand.nextInt(120);
      final int timestamp = dateBase
          .add(Duration(minutes: minuteOffset))
          .millisecondsSinceEpoch;

      final postData = {
        'userId': userId,
        'name': name,
        'dp': dpUrl,
        'postText': postText,
        'streaks': streaks,
        'viewCount': views,
        'likes': likes,
        'timestamp': timestamp,
      };

      try {
        await firestore
            .collection('posts')
            .doc('default')
            .collection(date)
            .doc(postId)
            .set(postData);

        print('✅ Uploaded $postId ($userId, name: $name)');
        successCount++;
      } catch (e) {
        print('❌ Error uploading $postId: $e');
      }

      globalPostIndex++;
    }
  }

  print('🎯 All seed data uploaded successfully! Total posts: $successCount');
}
