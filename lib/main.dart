import 'package:feedback/feedback.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:onlymens/core/approuter.dart';
import 'package:onlymens/core/apptheme.dart';
import 'package:onlymens/core/globals.dart';
import 'package:onlymens/firebase_options.dart';
import 'package:onlymens/utilis/snackbar.dart';
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
          title: 'OnlyMens',
          theme: AppTheme2.theme,
          scaffoldMessengerKey: Utilis.messengerKey,
          debugShowCheckedModeBanner: false,
          useInheritedMediaQuery: true,
        ),
      ),
    );
  }
}
