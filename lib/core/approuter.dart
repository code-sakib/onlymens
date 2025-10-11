// COMPLETE FIXED approutes.dart

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:onlymens/affirmations_pg.dart';
import 'package:onlymens/auth/auth_screen.dart';
import 'package:onlymens/core/globals.dart';
import 'package:onlymens/features/ai_model/game_mode.dart';
import 'package:onlymens/features/ai_model/presentation/ai_mainpage.dart';
import 'package:onlymens/features/betterwbro/presentation/bwb_page.dart';
import 'package:onlymens/features/onboarding_pgs/onboarding_pgs.dart';
import 'package:onlymens/features/streaks_page/presentation/streaks_page.dart';
import 'package:onlymens/meditation_pg.dart';
import 'package:onlymens/panic_mode_pg.dart';
import 'package:onlymens/profile_page.dart';
import 'package:onlymens/utilis/bottom_appbar.dart';
import 'package:onlymens/utilis/size_config.dart';

final approutes = GoRouter(
  initialLocation: '/',
  refreshListenable: GoRouterRefreshStream(auth.authStateChanges()),
  redirect: (context, state) {
    final isLoggedIn = auth.currentUser != null;
    final isAuthRoute = state.matchedLocation == '/';
    final isOnboardingRoute = state.matchedLocation == '/onboarding';

    // Check if onboarding is completed
    final bool onboardingDone = prefs.getBool('onboarding_done') ?? false;

    print(
      '🔄 Redirect check: logged=$isLoggedIn, guest=$isGuest, route=${state.matchedLocation}, onboarding=$onboardingDone',
    );

    // GUEST MODE - Allow guest to access all routes except auth
    if (isGuest) {
      if (isAuthRoute) {
        print('✅ Guest redirected to /streaks');
        return '/streaks';
      }
      print('✅ Guest allowed to ${state.matchedLocation}');
      return null; // Allow access to current route
    }

    if (!onboardingDone) {
      return '/onboarding';
    }

    // NOT LOGGED IN - Redirect to auth page
    if (!isLoggedIn) {
      if (!isAuthRoute) {
        print('❌ Not logged in, redirecting to /');
        return '/';
      }
      print('✅ Show auth screen');
      return null; // Stay on auth page
    }

    // LOGGED IN USER
    if (isLoggedIn) {
      // If on auth page, decide where to go
      if (isAuthRoute) {
        // Check if onboarding is needed
        if (!onboardingDone || obSelectedValues.isEmpty) {
          print('✅ New user, redirecting to /onboarding');
          return '/onboarding';
        }
        // Onboarding done or has data, go to streaks
        print('✅ Logged in user redirected to /streaks');
        return '/streaks';
      }

      // If trying to access onboarding but already completed
      if (isOnboardingRoute && onboardingDone) {
        print('✅ Onboarding done, redirecting to /streaks');
        return '/streaks';
      }

      print('✅ Logged in user allowed to ${state.matchedLocation}');
      return null; // Allow access to requested route
    }

    // Default: no redirect
    return null;
  },
  routes: [
    // Auth route with loading wrapper
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthScreenWithLoading(),
    ),

    // Onboarding - standalone without bottom bar
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),

    GoRoute(path: '/aimodel', builder: (context, state) => const AiMainpage()),

    // Additional routes that also get bottom bar
    GoRoute(path: '/profile', builder: (context, state) => ProfilePage()),
    GoRoute(
      path: '/affirmations',
      builder: (context, state) => const AffirmationsPage(),
    ),
    GoRoute(path: '/panicpg', builder: (context, state) => const PanicModePg()),
    GoRoute(path: '/game1', builder: (context, state) => const PongGame()),
    GoRoute(path: '/game2', builder: (context, state) => const QuickDrawGame()),
    GoRoute(path: '/bwb', builder: (context, state) => BwbPage2()),
    GoRoute(path: '/meditation', builder: (context, state) => MeditationPg()),

    // Shell route wraps all authenticated routes with bottom bar
    ShellRoute(
      builder: (context, state, child) {
        SizeConfig().init(context);

        return Scaffold(
          body: child,
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.transparent,
            shape: const CircleBorder(),
            onPressed: () => context.go('/streaks'),
            child: Lottie.asset(
              'assets/lottie/fire.json',
              width: SizeConfig.fireIconSize,
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: bottomAppBar(
            currentRoute: state.matchedLocation,
            onChatPressed: () => context.go('/bwb'),
            onAiPressed: () => context.go('/aimodel'),
            onHomePressed: () => context.go('/streaks'),
          ),
        );
      },
      routes: [
        // Main 3 routes with bottom bar
        GoRoute(
          path: '/streaks',
          builder: (context, state) => const StreaksPage(),
        ),
      ],
    ),
  ],
);

// Helper class to make GoRouter listen to auth state changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// Auth Screen Wrapper with Loading State
class AuthScreenWithLoading extends StatelessWidget {
  const AuthScreenWithLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: auth.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AuthLoadingScreen();
        }

        // Show auth screen when state is determined
        return const AuthScreen();
      },
    );
  }
}

// Loading Screen shown during authentication
class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CupertinoActivityIndicator(
              radius: 20,
              color: Colors.deepPurpleAccent,
            ),
            const SizedBox(height: 20),
            Text(
              'Loading...',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}
