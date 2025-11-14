// auth_screen.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:onlymens/auth/auth_service.dart';
import 'package:onlymens/core/apptheme.dart';
import 'package:onlymens/utilis/size_config.dart';
import 'package:onlymens/utilis/snackbar.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _loadingApple = false;
  bool _loadingGoogle = false;

  Future<void> _handleSuccessfulLogin(String method) async {
    Utilis.showSnackBar("Signed in with $method");
    
    // Check if user has active subscription
    final sub = await AuthService.fetchSubscriptionForCurrentUser();
    if (sub != null) {
      final expiresMs = sub['expiresDateMs'] ?? 0;
      final isActive = expiresMs > DateTime.now().millisecondsSinceEpoch;
      
      if (isActive && mounted) {
        print('✅ User has active subscription, navigating to /streaks');
        context.go('/streaks');
        return;
      }
    }
    
    // No active subscription, go to pricing
    if (mounted) {
      print('⚠️ No active subscription, navigating to /pricing');
      context.go('/pricing');
    }
  }

  Future<void> _appleLogin() async {
    setState(() => _loadingApple = true);
    try {
      await AuthService.signInWithApple();
      await _handleSuccessfulLogin("Apple");
    } catch (e) {
      Utilis.showSnackBar("Apple Sign-In failed", isErr: true);
      print("Apple error: $e");
    } finally {
      if (mounted) setState(() => _loadingApple = false);
    }
  }

  Future<void> _googleLogin() async {
    setState(() => _loadingGoogle = true);
    try {
      await AuthService.signInWithGoogle();
      await _handleSuccessfulLogin("Google");
    } catch (e) {
      Utilis.showSnackBar("Google Sign-In failed", isErr: true);
      print("Google error: $e");
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig.init(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 22,
            vertical: SizeConfig.screenVPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: SizeConfig.screenHeight * 0.1),

              // TITLE
              Text(
                "Welcome",
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 10),

              Text(
                "Sign in to continue your journey.",
                style: TextStyle(fontSize: 16, color: AppColors.textMuted),
              ),

              const SizedBox(height: 45),

              // APPLE LOGIN BUTTON
              _SignInButton(
                text: "Continue with Apple ",
                assetIcon: "assets/logos/apple_logo.png",
                isLoading: _loadingApple,
                onTap: _loadingApple ? null : _appleLogin,
              ),

              const SizedBox(height: 18),

              // GOOGLE LOGIN BUTTON
              _SignInButton(
                text: "Continue with Google",
                assetIcon: "assets/logos/google_logo.png",
                isLoading: _loadingGoogle,
                onTap: _loadingGoogle ? null : _googleLogin,
              ),

              const Spacer(),

              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 22.0),
                  child: Text(
                    "By continuing, you agree to our Terms & Privacy Policy",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final String? assetIcon;
  final VoidCallback? onTap;
  final bool isLoading;

  const _SignInButton({
    required this.text,
    this.icon,
    this.assetIcon,
    required this.onTap,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white30, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const CupertinoActivityIndicator(color: Colors.white)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) Icon(icon, size: 22, color: Colors.white),
                  if (assetIcon != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Image.asset(assetIcon!, height: 22),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}