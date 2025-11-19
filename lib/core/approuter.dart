// approutes.dart — PRODUCTION VERSION with proper flow

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:onlymens/legal_screen.dart';
import 'package:onlymens/utilis/snackbar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onlymens/auth/auth_service.dart';
import 'package:onlymens/auth/auth_screen.dart';
import 'package:onlymens/features/affirmations/affirmations_pg.dart';
import 'package:onlymens/features/ai_model/presentation/ai_mainpage.dart';
import 'package:onlymens/features/ai_model/game_mode.dart';
import 'package:onlymens/features/betterwbro/chat/messages_page.dart';
import 'package:onlymens/features/betterwbro/presentation/bwb_page.dart';
import 'package:onlymens/features/onboarding_pgs/pricing_pg.dart';
import 'package:onlymens/features/panic_mode/panic_mode_pg.dart';
import 'package:onlymens/features/streaks_page/presentation/streaks_page.dart';
import 'package:onlymens/features/onboarding_pgs/onboarding_pgs.dart';
import 'package:onlymens/guides/blogs.dart';
import 'package:onlymens/profile_page.dart';
import 'package:onlymens/sound_pg.dart';
import 'package:onlymens/utilis/bottom_appbar.dart';

final approutes = GoRouter(
  initialLocation: '/',
  refreshListenable: GoRouterRefreshStream(AuthService.auth.authStateChanges()),

  // =============================================================
  // PRODUCTION ROUTING FLOW
  // =============================================================
  redirect: (context, state) async {
    final loggedIn = AuthService.currentUser != null;
    final loc = state.matchedLocation;

    print('🔄 [ROUTER] loc=$loc, loggedIn=$loggedIn');

    // --- ALLOW THESE ROUTES ALWAYS ---
    if (loc == '/onboarding' || loc == '/pricing' || loc == '/auth') {
      return null;
    }

    // --- NOT LOGGED IN ---
    if (!loggedIn) {
      final prefs = await SharedPreferences.getInstance();
      final onboardingDone = prefs.getBool('onboarding_done') ?? false;

      // Check if user has pending receipt (paid but not signed in)
      final hasPendingReceipt = prefs.getString('pending_receipt') != null;

      if (loc == '/') {
        // Root route - determine where to send them
        if (hasPendingReceipt || onboardingDone) {
          print('📦 Has pending receipt or completed onboarding → /pricing');
          return '/pricing';
        }
        print('🆕 New user → /onboarding');
        return '/onboarding';
      }

      // Trying to access protected routes without login
      if (hasPendingReceipt || onboardingDone) {
        print('⚠️ Not logged in, trying to access $loc → /pricing');
        return '/pricing';
      }

      print('⚠️ Not logged in, trying to access $loc → /onboarding');
      return '/onboarding';
    }

    // --- LOGGED IN ---
    if (loggedIn) {
      // Check subscription status
      final sub = await AuthService.fetchSubscriptionForCurrentUser();

      if (sub == null) {
        print('⚠️ Logged in but no subscription → /pricing');
        if (loc != '/pricing' && loc != '/auth') {
          return '/pricing';
        }
        return null;
      }

      final expiresMs = sub['expiresDateMs'] ?? 0;
      final isActive = expiresMs > DateTime.now().millisecondsSinceEpoch;

      if (!isActive) {
        print('⚠️ Subscription expired → /pricing');
        Future.microtask(() {
          Utilis.showSnackBar("Your subscription has expired", isErr: true);
        });
        if (loc != '/pricing' && loc != '/auth') {
          return '/pricing';
        }

        return null;
      }

      // Active subscription - allow access
      print('✅ Active subscription - allowing access to $loc');

      // Set onboarding done if not already set
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('onboarding_done')) {
        await prefs.setBool('onboarding_done', true);
      }

      // If on root, redirect to streaks
      if (loc == '/') {
        print('✅ Root route with active sub → /streaks');
        return '/streaks';
      }

      return null; // Allow access to requested route
    }

    return null;
  },

  routes: [
    // =============================================================
    // PUBLIC ROUTES (accessible without subscription)
    // =============================================================
    GoRoute(path: '/', builder: (_, __) => const _LoadingScreen()),

    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),

    GoRoute(path: '/pricing', builder: (_, __) => const PricingPage()),

    GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),

    // =============================================================
    // PROTECTED ROUTES (require active subscription)
    // =============================================================

    // Blog detail (can be accessed without subscription)
    GoRoute(
      path: '/blogdetail',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>? ?? {};
        return BlogDetailPage(blogData: data);
      },
    ),

    // Individual protected routes
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
    GoRoute(path: '/messages', builder: (_, __) => const MessagesPage()),
    GoRoute(path: '/legal', builder: (_, __) => const LegalScreen()),


    // =============================================================
    // SHELL ROUTE (BOTTOM NAV + STREAKS FAB)
    // =============================================================
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
              height: 40.h,
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

// =============================================================
// LOADING SCREEN (shown briefly while determining route)
// =============================================================
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// =============================================================
// AUTH STATE LISTENER
// =============================================================
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
