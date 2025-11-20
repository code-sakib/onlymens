// auth_screen.dart - FINAL RESPONSIVE VERSION
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ScreenUtil
import 'package:go_router/go_router.dart';
import 'package:cleanmind/auth/auth_service.dart';
import 'package:cleanmind/core/apptheme.dart';
import 'package:cleanmind/legal_screen.dart';
// removed size_config import as we are using flutter_screenutil
import 'package:cleanmind/utilis/snackbar.dart';

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
        debugPrint('✅ User has active subscription, navigating to /streaks');
        context.go('/streaks');
        return;
      }
    }

    // No active subscription, go to pricing
    if (mounted) {
      debugPrint('⚠️ No active subscription, navigating to /pricing');
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
      debugPrint("Apple error: $e");
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
      debugPrint("Google error: $e");
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // SizeConfig.init(context); // Removed, using ScreenUtil

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w), // Adapted padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Using 0.1.sh for 10% of screen height
              SizedBox(height: 0.1.sh),

              // TITLE
              Text(
                "Last Step!",
                style: TextStyle(
                  fontSize: 36.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              SizedBox(height: 10.h),

              Text(
                "Sign in to keep your data and premium features synced on all your devices.",
                style: TextStyle(fontSize: 16.sp, color: AppColors.textMuted),
              ),

              SizedBox(height: 45.h),

              // APPLE LOGIN BUTTON
              _SignInButton(
                text: "Continue with Apple ",
                assetIcon: "assets/logos/apple_logo.png",
                isLoading: _loadingApple,
                onTap: _loadingApple ? null : _appleLogin,
              ),

              SizedBox(height: 18.h),

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
                  padding: EdgeInsets.only(bottom: 22.h),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LegalScreen()),
                      );
                    },
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.sp,
                        ),
                        children: const [
                          TextSpan(text: "See our  "),
                          TextSpan(
                            text: "Privacy Policy • Terms of Use",
                            style: TextStyle(color: Colors.lightBlue),
                          ),
                          TextSpan(
                            text:
                                "  By continuing, you're agreeing to it. Don't worry, it's all good there.",
                          ),
                        ],
                      ),
                    ),
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
    this.assetIcon,
    required this.onTap,
    required this.isLoading,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56.h,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white30, width: 1.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
        child: isLoading
            ? const CupertinoActivityIndicator(color: Colors.white)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) Icon(icon, size: 22.r, color: Colors.white),
                  if (assetIcon != null)
                    Padding(
                      padding: EdgeInsets.only(right: 8.w),
                      child: Image.asset(assetIcon!, height: 22.h),
                    ),
                  SizedBox(width: 8.w),
                  Text(
                    text,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
