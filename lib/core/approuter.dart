// approutes.dart — FINAL MERGED VERSION (DEV FLOW + REAL ROUTES, NO SIZECONFIG)

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:onlymens/auth/auth_service.dart';
import 'package:onlymens/auth/auth_screen.dart';
import 'package:onlymens/features/affirmations/affirmations_pg.dart';

import 'package:onlymens/features/ai_model/presentation/ai_mainpage.dart';
import 'package:onlymens/features/ai_model/game_mode.dart';

import 'package:onlymens/features/betterwbro/presentation/bwb_page.dart';
import 'package:onlymens/features/panic_mode/panic_mode_pg.dart';
import 'package:onlymens/features/streaks_page/presentation/streaks_page.dart';

import 'package:onlymens/features/onboarding_pgs/onboarding_pgs.dart';
import 'package:onlymens/guides/blogs.dart';
import 'package:onlymens/meditation_pg.dart';
import 'package:onlymens/profile_page.dart';
import 'package:onlymens/sound_pg.dart';

import 'package:onlymens/utilis/bottom_appbar.dart';

final approutes = GoRouter(
  initialLocation: '/',
  refreshListenable: GoRouterRefreshStream(AuthService.auth.authStateChanges()),

  // =============================================================
  // DEV MODE ROUTING FLOW
  // - New users → Auth → Streaks
  // - Skip onboarding & pricing fully
  // - Logged-in users always go to streaks
  // =============================================================
  redirect: (context, state) async {
    final loggedIn = AuthService.currentUser != null;
    final loc = state.matchedLocation;

    print('🔄 [DEV MODE] Redirect: loc=$loc, loggedIn=$loggedIn');

    // --- NOT LOGGED IN ---
    if (!loggedIn) {
      if (loc == '/') return null; // allow auth
      print('⚠️ Not logged in → redirect to /');
      return '/';
    }

    // --- LOGGED IN ---
    if (loggedIn) {
      if (loc == '/') {
        print('✅ Logged in → redirect to /streaks');
        return '/streaks';
      }
      return null; // allow all other routes
    }

    return null;
  },

  routes: [
    // AUTH PAGE
    GoRoute(path: '/', builder: (_, __) => const AuthScreen()),

    // Dev routes (unlocked in DEV MODE)
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/aimodel', builder: (_, __) => const AiMainpage()),
    GoRoute(path: '/bwb', builder: (_, __) => BWBPage()),
    GoRoute(path: '/profile', builder: (_, __) => ProfilePage()),
    GoRoute(
      path: '/affirmations',
      builder: (_, __) => const AffirmationsPage(),
    ),
    GoRoute(path: '/panicpg', builder: (_, __) => const PanicModePg()),
    GoRoute(path: '/meditation', builder: (_, __) => RainScreen()),
    GoRoute(path: '/game1', builder: (_, __) => const PongGame()),
    GoRoute(path: '/game2', builder: (_, __) => const QuickDrawGame()),
    GoRoute(
      path: '/blogdetail',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>? ?? {};
        return BlogDetailPage(blogData: data);
      },
    ),

    // SHELL ROUTE (BOTTOM NAV + STREAKS FAB)
    ShellRoute(
      builder: (context, state, child) {
        return Scaffold(
          body: child,
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.transparent,
            shape: const CircleBorder(),
            onPressed: () => context.go('/streaks'),
            child: Lottie.asset(
              'assets/lottie/fire.json',
              height: 40.h, // removed SizeConfig
              width: 40.w,
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: bottomAppBar(
            currentRoute: state.matchedLocation,
            onHomePressed: () => context.go('/streaks'),
            onAiPressed: () => context.go('/aimodel'),
            onChatPressed: () => context.go('/bwb'),
          ),
        );
      },
      routes: [
        GoRoute(path: '/streaks', builder: (_, __) => const StreaksPage()),
      ],
    ),
  ],
);

/// GoRouter listens to auth state changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) {
      print('🔔 Auth state changed → refresh router');
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
