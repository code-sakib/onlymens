import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:onlymens/affirmations_pg.dart';
import 'package:onlymens/auth/auth_screen.dart';
import 'package:onlymens/core/globals.dart';
import 'package:onlymens/features/ai_model/presentation/ai_mainpage.dart';
import 'package:onlymens/features/betterwbro/presentation/bwb_page.dart';
import 'package:onlymens/features/onboarding_pgs/onboarding_pgs.dart';
import 'package:onlymens/features/streaks_page/presentation/streaks_page.dart';
import 'package:onlymens/panic_mode_pg.dart';
import 'package:onlymens/profile_page.dart';
import 'package:onlymens/utilis/bottom_appbar.dart';
import 'package:onlymens/utilis/size_config.dart';

final approutes = GoRouter(
  initialLocation: '/streaks',
  refreshListenable: GoRouterRefreshStream(auth.authStateChanges()),
  redirect: (context, state) {
    final isLoggedIn = auth.currentUser != null;
    final isAuthRoute = state.matchedLocation == '/';

    // Check if onboarding is completed
    final bool onboardingDone = prefs.getBool('onboarding_done') ?? false;
    if (!onboardingDone) return '/onboarding';


    // Allow guest mode
    if (isGuest) {
      if (isAuthRoute) return '/streaks';
      return null;
    }

    // Not logged in and trying to access protected route
    if (!isLoggedIn && !isAuthRoute) {
      return '/';
    }

    // Logged in and on auth page, redirect to streaks
    if (isLoggedIn && isAuthRoute) {
      return '/streaks';
    }

    return null; // No redirect needed
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

    // Shell route wraps all authenticated routes with bottom bar
    ShellRoute(
      builder: (context, state, child) {
        SizeConfig().init(context);

        return Scaffold(
          body: child,
          floatingActionButton: FloatingActionButton(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
        GoRoute(path: '/bwb', builder: (context, state) => BWBPage()),
        GoRoute(
          path: '/aimodel',
          builder: (context, state) => const AiMainpage(),
        ),

        // Additional routes that also get bottom bar
        GoRoute(path: '/profile', builder: (context, state) => ProfilePage()),
        GoRoute(
          path: '/affirmations',
          builder: (context, state) => const AffirmationsPage(),
        ),
        GoRoute(
          path: '/panicpg',
          builder: (context, state) => const PanicModePg(),
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
            // You can add your app logo here
            // Image.asset('assets/logo.png', height: 100),
            // const SizedBox(height: 40),
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
