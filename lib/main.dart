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

  // await auth.signOut();
  // await prefs.clear();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // sizes with context init
    SizeConfig().init(context);

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
