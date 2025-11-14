// approutes.dart - FIXED VERSION
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onlymens/auth/auth_service.dart';
import 'package:onlymens/core/globals.dart';
import 'package:onlymens/features/onboarding_pgs/onboarding_pgs.dart';
import 'package:onlymens/auth/auth_screen.dart';
import 'package:onlymens/features/onboarding_pgs/pricing_pg.dart';
import 'package:onlymens/features/streaks_page/presentation/streaks_page.dart';
import 'package:onlymens/features/ai_model/presentation/ai_mainpage.dart';
import 'package:onlymens/utilis/bottom_appbar.dart';
import 'package:onlymens/features/betterwbro/presentation/bwb_page.dart';
import 'package:onlymens/features/betterwbro/chat/messages_page.dart';

final approutes = GoRouter(
  initialLocation: '/',
  refreshListenable: GoRouterRefreshStream(AuthService.auth.authStateChanges()),
  redirect: (context, state) async {
    final loggedIn = AuthService.currentUser != null;
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    final loc = state.matchedLocation;

    print('🔄 Redirect: loc=$loc, loggedIn=$loggedIn, onboardingDone=$onboardingDone');

    // ==========================================
    // STEP 1: First time users → Onboarding flow
    // ==========================================
    if (!onboardingDone) {
      // Allow: /onboarding, /pricing, /auth
      if (loc == '/onboarding' || loc == '/pricing' || loc == '/') {
        return '/onboarding'; // Stay on current route
      }
      // Redirect to onboarding for any other route
      return '/onboarding';
    }

    // ==========================================
    // STEP 2: Onboarding completed, check subscription
    // ==========================================
    
    // Check if user has valid subscription
    Map<String, dynamic>? sub;
    bool hasActiveSubscription = false;
    
    if (loggedIn) {
      sub = await AuthService.fetchSubscriptionForCurrentUser();
      if (sub != null) {
        final expiresMs = sub['expiresDateMs'] ?? 0;
        hasActiveSubscription = expiresMs > DateTime.now().millisecondsSinceEpoch;
        print('📱 Subscription: active=$hasActiveSubscription, expiresMs=$expiresMs');
      }
    }

    // ==========================================
    // STEP 3: Route logic based on auth + subscription
    // ==========================================

    // --- Not logged in ---
    if (!loggedIn) {
      // Allow public routes
      if (loc == '/' || loc == '/pricing') {
        return null;
      }
      // Redirect protected routes to auth
      return '/';
    }

    // --- Logged in but NO active subscription ---
    if (!hasActiveSubscription) {
      // Allow: pricing page (to purchase), auth page
      if (loc == '/pricing' || loc == '/') {
        return null;
      }
      // Redirect to pricing for protected routes
      return '/pricing';
    }

    // --- Logged in WITH active subscription ---
    if (hasActiveSubscription) {
      // If on auth or pricing, redirect to main app
      if (loc == '/' || loc == '/pricing') {
        return '/streaks';
      }
      // Allow access to all protected routes
      return null;
    }

    return null;
  },
  routes: [
    // Public routes
    GoRoute(
      path: '/',
      builder: (_, __) => const AuthScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (_, __) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/pricing',
      builder: (_, __) => const PricingPage(),
    ),

    // Protected routes (require subscription)
    GoRoute(
      path: '/aimodel',
      builder: (_, __) => const AiMainpage(),
    ),
    GoRoute(
      path: '/bwb',
      builder: (_, __) => BWBPage(),
    ),
    GoRoute(
      path: '/messages',
      builder: (_, __) => MessagesPage(),
    ),

    // Shell route with bottom nav
    ShellRoute(
      builder: (context, state, child) {
        return Scaffold(
          body: child,
          bottomNavigationBar: bottomAppBar(
            currentRoute: state.matchedLocation,
            onHomePressed: () => context.go('/streaks'),
            onAiPressed: () => context.go('/aimodel'),
            onChatPressed: () => context.go('/bwb'),
          ),
        );
      },
      routes: [
        GoRoute(
          path: '/streaks',
          builder: (_, __) => const StreaksPage(),
        ),
      ],
    ),
  ],
);

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) {
      print('🔔 Auth state changed, refreshing routes');
      notifyListeners();
    });
  }
  late final StreamSubscription _subscription;
  
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}