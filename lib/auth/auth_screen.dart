// Simplified auth_screen.dart - Production ready

import 'package:email_validator/email_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onlymens/auth/auth_service.dart';
import 'package:onlymens/core/apptheme.dart';
import 'package:onlymens/core/globals.dart';
import 'package:onlymens/utilis/size_config.dart';
import 'package:onlymens/utilis/snackbar.dart';

enum AuthState { signIn, signUp }

AuthState _authState = AuthState.signIn;

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  void toggleState() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: SizeConfig.screenHPadding,
            vertical: SizeConfig.screenVPadding,
          ),
          child: Builder(
            builder: (context) {
              switch (_authState) {
                case AuthState.signIn:
                  return SignIn(toggleState: toggleState);
                case AuthState.signUp:
                  return SignUp(toggleState: toggleState);
              }
            },
          ),
        ),
      ),
    );
  }
}

// Sign In Screen
class SignIn extends StatefulWidget {
  final VoidCallback toggleState;

  const SignIn({super.key, required this.toggleState});
  @override
  _SignInState createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final _signInFormKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_signInFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AuthService.signInWithEmail(
        emailController.text,
        passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        Utilis.showSnackBar(
          e.message ?? 'Sign in failed',
          isErr: true,
        );
      }
    } catch (e) {
      if (mounted) {
        Utilis.showSnackBar('An error occurred', isErr: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _signInFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome Back', style: Theme.of(context).textTheme.titleLarge),
          Text(
            'Continue on your journey to your best self',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: SizeConfig.defaultHeight2),

          AuthTextField(
            label: 'Email *',
            hint: 'Enter your email',
            icon: Icons.email_outlined,
            tFController: emailController,
            validator: (email) =>
                email != null && EmailValidator.validate(email)
                    ? null
                    : "Enter a valid email",
          ),

          AuthTextField(
            label: 'Password *',
            hint: 'Enter your password',
            icon: Icons.lock_outline,
            obscureFunc: true,
            tFController: passwordController,
            validator: (password) => password != null && password.length >= 6
                ? null
                : "Password must be at least 6 characters",
          ),

          SizedBox(height: SizeConfig.defaultHeight1),

          authButton(
            text: 'Sign In',
            onPressed: _isLoading ? () {} : _handleSignIn,
            isPrimary: true,
            isLoading: _isLoading,
          ),

          SizedBox(height: SizeConfig.defaultHeight2),

          authButton(
            text: 'Continue as Guest',
            isPrimary: false,
            onPressed: () async {
              isGuest = true;
              await auth.signOut();
              if (mounted) context.go('/streaks');
            },
          ),

          SocialButtonsSec(),
          SizedBox(height: SizeConfig.defaultHeight2),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: TextStyle(fontSize: 16, color: Colors.grey[400]),
              ),
              GestureDetector(
                onTap: () {
                  _authState = AuthState.signUp;
                  widget.toggleState();
                },
                child: const Text(
                  'Sign Up',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.deepPurpleAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Sign Up Screen
class SignUp extends StatefulWidget {
  final VoidCallback toggleState;

  const SignUp({super.key, required this.toggleState});
  @override
  _SignUpState createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final _signUpFormKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_signUpFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AuthService.signUpWithEmail(
        emailController.text,
        passwordController.text,
      );

      if (mounted) {
        context.go('/onboarding');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        Utilis.showSnackBar(
          e.message ?? 'Sign up failed',
          isErr: true,
        );
      }
    } catch (e) {
      if (mounted) {
        Utilis.showSnackBar('An error occurred', isErr: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _signUpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create Account', style: Theme.of(context).textTheme.titleLarge),
          Text(
            'Join OnlyMens and unlock the best within you',
            style: Theme.of(context).textTheme.titleMedium,
          ),

          AuthTextField(
            label: 'Email *',
            hint: 'Enter your email',
            icon: Icons.email_outlined,
            tFController: emailController,
            validator: (email) =>
                email != null && EmailValidator.validate(email)
                    ? null
                    : "Enter a valid email",
          ),

          AuthTextField(
            label: 'Password *',
            hint: 'Enter your password',
            icon: Icons.lock_outline,
            tFController: passwordController,
            obscureFunc: true,
            validator: (password) => password != null && password.length >= 6
                ? null
                : "Password must be at least 6 characters",
          ),

          SizedBox(height: SizeConfig.defaultHeight2),

          authButton(
            text: 'Sign Up',
            onPressed: _isLoading ? () {} : _handleSignUp,
            isLoading: _isLoading,
          ),

          SizedBox(height: SizeConfig.defaultHeight2),

          authButton(
            text: 'Continue as Guest',
            isPrimary: false,
            onPressed: () async {
              isGuest = true;
              await auth.signOut();
              if (mounted) context.go('/streaks');
            },
          ),

          SocialButtonsSec(isNewUser: true),

          SizedBox(height: SizeConfig.defaultHeight2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Already have an account? ",
                style: TextStyle(fontSize: 16, color: Colors.grey[400]),
              ),
              GestureDetector(
                onTap: () {
                  _authState = AuthState.signIn;
                  widget.toggleState();
                },
                child: const Text(
                  'Sign In',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.deepPurpleAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Social Buttons Section
class SocialButtonsSec extends StatelessWidget {
  const SocialButtonsSec({this.isNewUser = false, super.key});

  final bool isNewUser;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: SizeConfig.screenVPadding),
          child: Row(
            children: [
              SizedBox(width: SizeConfig.screenWidth / 4),
              divider(),
              const Text('    or    '),
              divider(),
            ],
          ),
        ),
        _GoogleSignInButton(isNewUser: isNewUser),
      ],
    );
  }

  Widget divider() {
    return SizedBox(
      width: SizeConfig.screenWidth / 6,
      child: const Divider(thickness: 1),
    );
  }
}

class _GoogleSignInButton extends StatefulWidget {
  final bool isNewUser;

  const _GoogleSignInButton({required this.isNewUser});

  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      await AuthService.signInWithGoogle();

      if (mounted && widget.isNewUser) {
        context.go('/onboarding');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        Utilis.showSnackBar(
          e.message ?? 'Google sign in failed',
          isErr: true,
        );
      }
    } catch (e) {
      if (mounted) {
        Utilis.showSnackBar('Sign in cancelled', isErr: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: SizeConfig.blockHeight * 5,
      width: SizeConfig.screenHeight / 3,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color.fromARGB(255, 85, 85, 85)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const CupertinoActivityIndicator(color: Colors.white)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Image.asset('assets/logos/google_logo.png', height: 24),
                  ),
                  Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[300],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// Auth Button with Loading State
Widget authButton({
  required String text,
  required VoidCallback onPressed,
  bool isPrimary = true,
  bool isLoading = false,
}) {
  return SizedBox(
    width: double.infinity,
    height: 56,
    child: isPrimary
        ? ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: isLoading
                ? const CupertinoActivityIndicator(
                    color: Colors.white,
                    radius: 12,
                  )
                : Text(
                    text,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color.fromARGB(255, 85, 85, 85)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[300],
              ),
            ),
          ),
  );
}

// Auth Text Field
class AuthTextField extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureFunc;
  final TextEditingController? tFController;
  final String? Function(String?)? validator;

  const AuthTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureFunc = false,
    this.tFController,
    this.validator,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscureText = true;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: SizeConfig.paddingSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label),
          SizedBox(height: SizeConfig.blockHeight),
          Form(
            key: _formKey,
            child: TextFormField(
              controller: widget.tFController,
              obscureText: widget.obscureFunc ? _obscureText : false,
              keyboardType: widget.label.toLowerCase().contains('phone')
                  ? TextInputType.phone
                  : TextInputType.emailAddress,
              onChanged: (_) => _formKey.currentState?.validate(),
              validator: widget.validator,
              decoration: InputDecoration(
                hintText: widget.hint,
                prefixIcon: Icon(widget.icon, color: Colors.grey),
                suffixIcon: widget.obscureFunc
                    ? IconButton(
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                        icon: _obscureText
                            ? const Icon(
                                Icons.visibility,
                                color: AppColors.iconMuted,
                              )
                            : const Icon(
                                Icons.visibility_off,
                                color: AppColors.iconMuted,
                              ),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1,
                  ),
                ),
                contentPadding: EdgeInsets.all(SizeConfig.paddingSmall),
              ),
            ),
          ),
        ],
      ),
    );
  }
}