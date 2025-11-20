import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feedback/feedback.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cleanmind/core/approuter.dart';
import 'package:cleanmind/core/apptheme.dart';
import 'package:cleanmind/core/globals.dart';
import 'package:cleanmind/firebase_options.dart';
import 'package:cleanmind/utilis/snackbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await dotenv.load(fileName: ".env");
  prefs = await SharedPreferences.getInstance();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // p();
  // c();/
  // seedAllPosts();

  
  // await deleteAllPost/sFromCollection('mUsers');
  // seedDefaultPosts();

  // seedThreeRealPosts();
  
  

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

  // seedThreeRealPosts();
}

c() {
  final Map<String, int> dailyData = {
    "2025-10-30": 1,
    "2025-10-31": 0,
    "2025-11-01": 0,

    // Filled missing dates
    "2025-11-02": 1,
    "2025-11-03": 0,
    "2025-11-04": 2,
    "2025-11-05": 1,
    "2025-11-06": 0,
    "2025-11-07": 2,
    "2025-11-08": 1,
    "2025-11-09": 0,

    // Your given values
    "2025-11-10": 3,
    "2025-11-11": 3,
    "2025-11-12": 3,
    "2025-11-13": 3,
    "2025-11-14": 3,
    "2025-11-15": 3,
  };

  cloudDB
      .collection('users')
      .doc('y7cs7Ul45lRVmzCykxsIPiO5XqD2')
      .collection('streaks')
      .doc('total')
      .set({"dailyData": dailyData}, SetOptions(merge: true))
      .onError((e, s) => print(s));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    hasInternet.then((value) {
      debugPrint(value ? 'Internet available' : 'No internet');
    });

    return ScreenUtilInit(
      designSize: const Size(390, 844), // iPhone 13 / Figma baseline
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, __) => SafeArea(
        child: MaterialApp.router(
          routerConfig: approutes,
          title: 'CleanMind',
          theme: AppTheme.theme,
          scaffoldMessengerKey: Utilis.messengerKey,
          debugShowCheckedModeBanner: false,
          useInheritedMediaQuery: true,
        ),
      ),
    );
  }
}

p() async {
  final DateTime start = DateTime(2025, 8, 31);
  final DateTime today = DateTime.now();

  // Override specific values you already have
  final Map<String, int> overrides = {
    "2025-10-30": 1,
    "2025-10-31": 0,
    "2025-11-01": 0,
    "2025-11-10": 3,
    "2025-11-11": 3,
    "2025-11-12": 3,
    "2025-11-13": 3,
    "2025-11-14": 3,
    "2025-11-15": 3,
  };

  final random = Random();
  final Map<String, int> dailyData = {};

  // Build all dates
  DateTime cursor = start;
  while (!cursor.isAfter(today)) {
    final key =
        "${cursor.year}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}";
    dailyData[key] = random.nextInt(3); // default 0–2
    cursor = cursor.add(Duration(days: 1));
  }

  // Apply overrides
  overrides.forEach((k, v) => dailyData[k] = v);

  // Ensure exactly 14 days of 3
  const targetThrees = 14;
  final currentThreeDates = dailyData.entries
      .where((e) => e.value == 3)
      .map((e) => e.key)
      .toList();
  int missing = targetThrees - currentThreeDates.length;

  if (missing > 0) {
    final candidates =
        dailyData.entries
            .where((e) => e.value != 3 && !overrides.containsKey(e.key))
            .map((e) => e.key)
            .toList()
          ..shuffle(random);

    for (int i = 0; i < missing; i++) {
      dailyData[candidates[i]] = 3;
    }
  }

  final sorted = Map.fromEntries(
    dailyData.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );

  final doc = cloudDB
      .collection('users')
      .doc('dCcTHpREK6dvZBd...') // your user
      .collection('streaks')
      .doc('total');

  // ❗ Important: overwrite the entire document so no old fields remain
  await doc.set({'dailyData': sorted}); // NO merge!

  print(
    "Uploaded ${sorted.length} days; 3's = ${sorted.values.where((v) => v == 3).length}",
  );
}

/// Remove duplicate posts from both rUsers and mUsers collections
/// Run this once by calling it from main(), then comment it out
Future<void> removeDuplicatePosts() async {
  final firestore = FirebaseFirestore.instance;

  print('🧹 Starting duplicate removal...');

  // Clean rUsers collection
  await _cleanCollection(firestore, 'posts/rUsers/all', 'rUsers');

  // Clean mUsers collection
  await _cleanCollection(firestore, 'posts/mUsers/all', 'mUsers');

  print('✅ Duplicate removal complete!');
}

Future<void> _cleanCollection(
  FirebaseFirestore firestore,
  String path,
  String collectionName,
) async {
  print('🔍 Checking $collectionName for duplicates...');

  final collection = firestore
      .collection('posts')
      .doc(collectionName == 'rUsers' ? 'rUsers' : 'mUsers')
      .collection('all');

  final snapshot = await collection.get();

  if (snapshot.docs.isEmpty) {
    print('ℹ️  No posts in $collectionName');
    return;
  }

  print('📊 Found ${snapshot.docs.length} posts in $collectionName');

  // Track seen posts by unique key
  final Map<String, String> seenPosts = {}; // key -> firstDocId
  final List<String> duplicatesToDelete = [];

  for (var doc in snapshot.docs) {
    final data = doc.data();
    final postText = data['postText']?.toString() ?? '';
    final userId = data['userId']?.toString() ?? '';
    final timestamp = data['timestamp'] ?? 0;

    // Create unique key based on content
    final uniqueKey = '$userId-$postText-$timestamp';

    if (seenPosts.containsKey(uniqueKey)) {
      // This is a duplicate
      duplicatesToDelete.add(doc.id);
      print('❌ Duplicate found: ${doc.id}');
    } else {
      // First occurrence - keep it
      seenPosts[uniqueKey] = doc.id;
    }
  }

  if (duplicatesToDelete.isEmpty) {
    print('✨ No duplicates found in $collectionName');
    return;
  }

  print(
    '🗑️  Deleting ${duplicatesToDelete.length} duplicates from $collectionName...',
  );

  // Delete in batches of 500 (Firestore batch limit)
  const batchSize = 500;

  for (int i = 0; i < duplicatesToDelete.length; i += batchSize) {
    final batch = firestore.batch();
    final end = (i + batchSize < duplicatesToDelete.length)
        ? i + batchSize
        : duplicatesToDelete.length;

    for (int j = i; j < end; j++) {
      final docRef = collection.doc(duplicatesToDelete[j]);
      batch.delete(docRef);
    }

    await batch.commit();
    print('✅ Deleted batch ${(i ~/ batchSize) + 1}');
  }

  print(
    '✅ $collectionName cleaned! Removed ${duplicatesToDelete.length} duplicates',
  );
  print(
    '📊 Remaining posts: ${snapshot.docs.length - duplicatesToDelete.length}',
  );
}

/// Alternative: Remove ALL posts from a collection (use with caution!)
Future<void> deleteAllPostsFromCollection(String collectionName) async {
  final firestore = FirebaseFirestore.instance;

  print('⚠️  Deleting ALL posts from $collectionName...');

  final collection = firestore
      .collection('posts')
      .doc(collectionName)
      .collection('all');

  final snapshot = await collection.get();

  if (snapshot.docs.isEmpty) {
    print('ℹ️  Collection $collectionName is already empty');
    return;
  }

  print('🗑️  Found ${snapshot.docs.length} posts to delete');

  // Delete in batches
  const batchSize = 500;
  int totalDeleted = 0;

  for (int i = 0; i < snapshot.docs.length; i += batchSize) {
    final batch = firestore.batch();
    final end = (i + batchSize < snapshot.docs.length)
        ? i + batchSize
        : snapshot.docs.length;

    for (int j = i; j < end; j++) {
      batch.delete(snapshot.docs[j].reference);
    }

    await batch.commit();
    totalDeleted += (end - i);
    print('✅ Deleted $totalDeleted / ${snapshot.docs.length} posts');
  }

  print('✅ All posts deleted from $collectionName!');
}

/// Clean up duplicates from user's personal posts collection
Future<void> cleanUserPersonalPosts(String userId) async {
  final firestore = FirebaseFirestore.instance;

  print('🧹 Cleaning personal posts for user: $userId');

  final collection = firestore
      .collection('users')
      .doc(userId)
      .collection('posts');

  final snapshot = await collection.get();

  if (snapshot.docs.isEmpty) {
    print('ℹ️  No posts found for this user');
    return;
  }

  print('📊 Found ${snapshot.docs.length} posts');

  final Map<String, String> seenPosts = {};
  final List<String> duplicatesToDelete = [];

  for (var doc in snapshot.docs) {
    final data = doc.data();
    final postText = data['postText']?.toString() ?? '';
    final timestamp = data['timestamp'] ?? 0;

    final uniqueKey = '$postText-$timestamp';

    if (seenPosts.containsKey(uniqueKey)) {
      duplicatesToDelete.add(doc.id);
      print('❌ Duplicate found: ${doc.id}');
    } else {
      seenPosts[uniqueKey] = doc.id;
    }
  }

  if (duplicatesToDelete.isEmpty) {
    print('✨ No duplicates in user posts');
    return;
  }

  print('🗑️  Deleting ${duplicatesToDelete.length} duplicates...');

  final batch = firestore.batch();
  for (var docId in duplicatesToDelete) {
    batch.delete(collection.doc(docId));
  }

  await batch.commit();
  print('✅ User posts cleaned!');
}

Future<void> seedDefaultPosts() async {
  final firestore = FirebaseFirestore.instance;

  final samplePosts = [
    {
      "name": "Evan Carter",
      "postText":
          "Woke up with a clear mind today. Small progress but it matters.",
      "dp": "https://picsum.photos/200?random=101",
      "streaks": 3,
      "likes": 1,
      "viewCount": 17,
    },
    {
      "name": "Noah Jensen",
      "postText": "Skipped social media this morning. Felt way more focused.",
      "dp": "https://picsum.photos/200?random=102",
      "streaks": 5,
      "likes": 0,
      "viewCount": 22,
    },
    {
      "name": "Liam Howard",
      "postText": "Had urges but held myself together. Staying committed.",
      "dp": "https://picsum.photos/200?random=103",
      "streaks": 7,
      "likes": 2,
      "viewCount": 31,
    },
    {
      "name": "Mason Rivera",
      "postText": "Felt tired all day but I didn’t relapse. Proud of that.",
      "dp": "https://picsum.photos/200?random=104",
      "streaks": 4,
      "likes": 1,
      "viewCount": 19,
    },
    {
      "name": "Carter Lewis",
      "postText":
          "Went for a walk instead of scrolling. Helps more than I expected.",
      "dp": "https://picsum.photos/200?random=105",
      "streaks": 6,
      "likes": 0,
      "viewCount": 28,
    },
    {
      "name": "Wyatt Brooks",
      "postText": "Cleaned my room today. Feels good to take control again.",
      "dp": "https://picsum.photos/200?random=106",
      "streaks": 2,
      "likes": 0,
      "viewCount": 14,
    },
    {
      "name": "Hunter Walsh",
      "postText": "Did some journaling at night. Helps me stay grounded.",
      "dp": "https://picsum.photos/200?random=107",
      "streaks": 9,
      "likes": 3,
      "viewCount": 36,
    },
    {
      "name": "Grayson Miller",
      "postText":
          "Focusing on sleep and hydration this week. Trying to rebuild.",
      "dp": "https://picsum.photos/200?random=108",
      "streaks": 1,
      "likes": 0,
      "viewCount": 11,
    },
    {
      "name": "Colton Hayes",
      "postText":
          "Didn’t feel like talking to anyone today, but I stayed strong.",
      "dp": "https://picsum.photos/200?random=109",
      "streaks": 8,
      "likes": 2,
      "viewCount": 33,
    },
    {
      "name": "Jayden Ross",
      "postText": "Another day clean. Slow progress is still progress.",
      "dp": "https://picsum.photos/200?random=110",
      "streaks": 10,
      "likes": 4,
      "viewCount": 45,
    },
  ];

  int i = 0;

  for (var post in samplePosts) {
    final id = firestore
        .collection("posts")
        .doc("mUsers")
        .collection("all")
        .doc()
        .id;

    await firestore
        .collection("posts")
        .doc("mUsers")
        .collection("all")
        .doc(id)
        .set({
          ...post,
          "postId": id,
          "userId": "default_user",
          "isDefault": true,
          "source": "default",
          "timestamp": DateTime.now().millisecondsSinceEpoch - (i * 3000),
        });

    i++;
  }

  print("✔ Default posts seeded!");
}

Future<void> seedRealUserPosts() async {
  final firestore = FirebaseFirestore.instance;

  final sampleRealPosts = [
    {
      "dp": "https://picsum.photos/200?random=201",
      "name": "Ethan Miller",
      "postText": "Stayed offline most of the day. Felt calmer, more present.",
      "streaks": 4,
      "userId": "user_001",
      "viewCount": 22,
    },
    {
      "dp": "https://picsum.photos/200?random=202",
      "name": "Aiden Brooks",
      "postText": "Had urges but went for a walk instead. Small win today.",
      "streaks": 2,
      "userId": "user_002",
      "viewCount": 18,
    },
    {
      "dp": "https://picsum.photos/200?random=203",
      "name": "Owen Parker",
      "postText": "Drank more water and worked out. Feeling clearer mentally.",
      "streaks": 6,
      "userId": "user_003",
      "viewCount": 30,
    },
    {
      "dp": "https://picsum.photos/200?random=204",
      "name": "Lucas Adams",
      "postText": "Mood was low today but I didn’t slip. Proud of that.",
      "streaks": 3,
      "userId": "user_004",
      "viewCount": 11,
    },
    {
      "dp": "https://picsum.photos/200?random=205",
      "name": "Jack Thompson",
      "postText": "Had a productive day. Less time on phone = less urges.",
      "streaks": 7,
      "userId": "user_005",
      "viewCount": 26,
    },
    {
      "dp": "https://picsum.photos/200?random=206",
      "name": "Mason Reed",
      "postText": "Trying to stay consistent. One hour at a time.",
      "streaks": 1,
      "userId": "user_006",
      "viewCount": 9,
    },
    {
      "dp": "https://picsum.photos/200?random=207",
      "name": "Ryan Mitchell",
      "postText": "Gym session helped today. Energy felt better.",
      "streaks": 5,
      "userId": "user_007",
      "viewCount": 17,
    },
    {
      "dp": "https://picsum.photos/200?random=208",
      "name": "Caleb Foster",
      "postText":
          "Cooked a healthy meal instead of doomscrolling. That felt good.",
      "streaks": 8,
      "userId": "user_008",
      "viewCount": 33,
    },
    {
      "dp": "https://picsum.photos/200?random=209",
      "name": "Henry Collins",
      "postText": "Didn’t expect to make it this far. Feeling hopeful.",
      "streaks": 10,
      "userId": "user_009",
      "viewCount": 42,
    },
    {
      "dp": "https://picsum.photos/200?random=210",
      "name": "Logan Wright",
      "postText": "Today was tough… but I stayed clean. That’s a win.",
      "streaks": 2,
      "userId": "user_010",
      "viewCount": 13,
    },
  ];

  int i = 0;

  for (var post in sampleRealPosts) {
    final id = firestore.collection("posts").doc().id;

    await firestore
        .collection("posts")
        .doc("rUsers")
        .collection("all")
        .doc(id)
        .set({
          ...post,
          "postId": id,
          "timestamp": DateTime.now().millisecondsSinceEpoch - (i * 5000),
          "likes": 0,
          "isDefault": false,
        });

    i++;
  }

  print("✔ Real user-like posts seeded!");
}

Future<void> deleteAllRealUserPosts() async {
  final firestore = FirebaseFirestore.instance;

  final collectionRef = firestore
      .collection("posts")
      .doc("rUsers")
      .collection("all");

  final querySnapshot = await collectionRef.get();

  WriteBatch batch = firestore.batch();

  for (var doc in querySnapshot.docs) {
    batch.delete(doc.reference);
  }

  await batch.commit();

  print("🗑 All real-user posts deleted!");
}

Future<void> seedAllPosts() async {
  await seedDefaultPosts();
  await seedRealUserPosts();
  print("🔥 All sample posts seeded successfully!");
}

Future<void> seedThreeRealPosts() async {
  final firestore = FirebaseFirestore.instance;

  final samplePosts = [
    {
      "dp": "https://picsum.photos/200?random=301",
      "name": "Daniel West",
      "postText": "Stayed strong today. Fewer urges than yesterday.",
      "streaks": 3,
      "userId": "user_A",
      "viewCount": 15,
    },
    {
      "dp": "https://picsum.photos/200?random=302",
      "name": "Jordan Flynn",
      "postText": "Drank more water and avoided scrolling. Felt good.",
      "streaks": 5,
      "userId": "user_B",
      "viewCount": 21,
    },
    {
      "dp": "https://picsum.photos/200?random=303",
      "name": "Sam Rhodes",
      "postText": "Took a long walk instead of giving in. Proud moment.",
      "streaks": 2,
      "userId": "user_C",
      "viewCount": 12,
    },
  ];

  int i = 0;

  for (var post in samplePosts) {
    final id = firestore.collection("posts").doc().id;

    await firestore
        .collection("posts")
        .doc("rUsers")
        .collection("all")
        .doc(id)
        .set({
          ...post,
          "postId": id,
          "timestamp": DateTime.now().millisecondsSinceEpoch - (i * 4000),
          "likes": 0,
          "isDefault": false,
        });

    i++;
  }

  print("✔ Seeded 3 posts in rUsers!");
}
