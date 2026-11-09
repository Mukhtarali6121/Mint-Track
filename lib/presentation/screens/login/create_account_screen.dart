import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/presentation/screens/login/login_Screen.dart';
import 'package:expense_tracker/presentation/screens/set_up_flow.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../theme/app_colors.dart';
import '../../../common/hive_storage.dart';
import '../../../common/transaction_hive_storage.dart';
import '../../../services/data_cleanup_service.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> with TickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  final _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  /// Validators
  bool _isValidFullName(String name) {
    final parts = name.trim().split(" ");
    return parts.length >= 2 && parts.every((p) => p.isNotEmpty);
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return regex.hasMatch(email);
  }

  bool _isValidPassword(String password) {
    return password.length >= 6;
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Sign up function
  Future<void> _signUp() async {
    debugPrint("👉 [SignUp] Register button clicked");
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Validation
    if (!_isValidFullName(username)) {
      debugPrint("❌ [SignUp] Invalid full name: '$username'");
      Fluttertoast.showToast(msg: "Please enter full name (First & Last).");
      return;
    }
    if (!_isValidEmail(email)) {
      debugPrint("❌ [SignUp] Invalid email: '$email'");
      Fluttertoast.showToast(msg: "Enter a valid email.");
      return;
    }
    if (!_isValidPassword(password)) {
      debugPrint("❌ [SignUp] Invalid password length");
      Fluttertoast.showToast(msg: "Password must be at least 6 characters.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint("👉 [SignUp] Step 1: Clearing current auth session & old local data...");
      try {
        await _auth.signOut();
        await DataCleanupService.clearAllData();
      } catch (cleanupErr) {
        debugPrint("⚠️ [SignUp] Error during cleanup (non-fatal): $cleanupErr");
      }

      debugPrint("👉 [SignUp] Step 2: Checking existing sign-in methods for $email...");
      try {
        final methods = await _auth.fetchSignInMethodsForEmail(email);
        debugPrint("👉 [SignUp] Existing methods found: $methods");
        if (methods.isNotEmpty) {
          if (methods.contains('google.com') && !methods.contains('password')) {
            debugPrint("❌ [SignUp] Email registered via Google only");
            Fluttertoast.showToast(
              msg: 'This email is already registered via Google. Please sign in using Google.',
            );
            if (mounted) setState(() => _isLoading = false);
            return;
          }
          debugPrint("⚠️ [SignUp] User already exists according to fetchSignInMethodsForEmail. Attempting sign-in...");
          try {
            final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
            debugPrint("✅ [SignUp] Successfully signed in existing user UID: ${cred.user?.uid}");
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SetupFlow()),
              );
            }
            return;
          } catch (signInErr) {
            debugPrint("❌ [SignUp] Sign-in with existing user failed: $signInErr");
            Fluttertoast.showToast(msg: "User already exists with this email. Please log in.");
            if (mounted) setState(() => _isLoading = false);
            return;
          }
        }
      } catch (methodErr) {
        debugPrint("⚠️ [SignUp] fetchSignInMethodsForEmail failed or blocked (proceeding to createUser): $methodErr");
      }

      debugPrint("👉 [SignUp] Step 3: Calling createUserWithEmailAndPassword...");
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = userCredential.user?.uid ?? _auth.currentUser?.uid;
      debugPrint("✅ [SignUp] Step 4: Auth user created successfully. UID: $uid");

      if (uid != null) {
        debugPrint("👉 [SignUp] Step 5: Saving profile to Firestore & Hive...");
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .set({
            'name': username,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 4));
          debugPrint("✅ [SignUp] Firestore user profile saved.");
        } catch (firestoreError) {
          debugPrint("⚠️ [SignUp] Warning: Failed to save Firestore profile (continuing anyway): $firestoreError");
        }

        try {
          await HiveStorage.saveUserProfile(userId: uid, name: username, email: email);
          debugPrint("✅ [SignUp] Local Hive user profile saved.");
        } catch (hiveError) {
          debugPrint("⚠️ [SignUp] Warning: Failed to save Hive profile (continuing anyway): $hiveError");
        }
      }

      debugPrint("👉 [SignUp] Step 6: Navigating to SetupFlow...");
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SetupFlow()),
        );
        debugPrint("✅ [SignUp] Navigation to SetupFlow executed.");
      } else {
        debugPrint("❌ [SignUp] Widget not mounted when attempting navigation!");
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("❌ [SignUp] FirebaseAuthException: code=${e.code}, message=${e.message}");
      if (e.code == 'email-already-in-use') {
        try {
          debugPrint("👉 [SignUp] Attempting sign-in because email is already in use...");
          final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
          debugPrint("✅ [SignUp] Logged in successfully with existing account: ${cred.user?.uid}");
          Fluttertoast.showToast(msg: "Account already exists. Signed you in!");
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const SetupFlow()),
            );
          }
          return;
        } catch (signInErr) {
          debugPrint("❌ [SignUp] Sign-in fallback failed: $signInErr");
          Fluttertoast.showToast(msg: "Email already in use. Please check your password or login.");
        }
      } else {
        Fluttertoast.showToast(msg: e.message ?? "Registration failed.");
      }
    } catch (e, stack) {
      debugPrint("❌ [SignUp] General Exception caught in _signUp: $e\n$stack");
      Fluttertoast.showToast(msg: "Registration error: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint("👉 [SignUp] _signUp execution completed.");
    }
  }

  Future<void> _signUpWithGoogle() async {
    debugPrint("👉 [GoogleSignUp] Google sign-up initiated");
    setState(() => _isLoading = true);
    try {
      debugPrint("👉 [GoogleSignUp] Step 1: Clearing current auth session & old data...");
      try {
        await _auth.signOut();
        await DataCleanupService.clearAllData();
      } catch (cleanupErr) {
        debugPrint("⚠️ [GoogleSignUp] Error during cleanup (non-fatal): $cleanupErr");
      }

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint("⚠️ [GoogleSignUp] User cancelled Google Sign-In picker");
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      final user = cred.user;
      debugPrint("✅ [GoogleSignUp] User signed in via Google. UID: ${user?.uid}");

      // Save profile to Firestore + Hive
      if (user != null) {
        final displayName = user.displayName ?? _usernameController.text.trim();
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'name': displayName,
            'email': user.email ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 4));
          debugPrint("✅ [GoogleSignUp] Firestore profile saved.");
        } catch (e) {
          debugPrint("⚠️ [GoogleSignUp] Firestore profile save error: $e");
        }

        try {
          await HiveStorage.saveUserProfile(
            userId: user.uid,
            name: displayName,
            email: user.email ?? '',
          );
          debugPrint("✅ [GoogleSignUp] Hive profile saved.");
        } catch (e) {
          debugPrint("⚠️ [GoogleSignUp] Hive profile save error: $e");
        }
      }

      if (!mounted) {
        debugPrint("❌ [GoogleSignUp] Widget not mounted when attempting navigation!");
        return;
      }
      debugPrint("👉 [GoogleSignUp] Navigating to SetupFlow...");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SetupFlow()),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint("❌ [GoogleSignUp] FirebaseAuthException: code=${e.code}, message=${e.message}");
      String msg = e.message ?? 'Google sign-in failed';
      if (e.code == 'account-exists-with-different-credential') {
        final email = e.email;
        if (email != null) {
          final methods = await _auth.fetchSignInMethodsForEmail(email);
          if (methods.contains('password') && methods.contains('google.com')) {
            msg = 'Account exists with Email and Google. Sign in then link accounts in settings.';
          } else if (methods.contains('password')) {
            msg = 'Email already registered with Email/Password. Please login with Email.';
          }
        }
      }
      Fluttertoast.showToast(msg: msg);
    } catch (e, stack) {
      debugPrint("❌ [GoogleSignUp] General error: $e\n$stack");
      Fluttertoast.showToast(msg: 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      // App Logo/Icon
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Center(
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.accentGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.person_add_outlined,
                                size: 32,
                                color: AppColors.accentGreen,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Create Account",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Sign up to start managing your finances",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Username Field
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _usernameController,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                              decoration: InputDecoration(
                                labelText: "Full Name",
                                labelStyle: const TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w400,
                                ),
                                floatingLabelStyle: TextStyle(
                                  color: AppColors.accentGreen,
                                  fontWeight: FontWeight.w400,
                                ),
                                prefixIcon: Icon(
                                  Icons.person_outline,
                                  color: AppColors.accentGreen,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppColors.accentGreen,
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Email Field
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                              decoration: InputDecoration(
                                labelText: "Email Address",
                                labelStyle: const TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w400,
                                ),
                                floatingLabelStyle: TextStyle(
                                  color: AppColors.accentGreen,
                                  fontWeight: FontWeight.w400,
                                ),
                                prefixIcon: Icon(
                                  Icons.email_outlined,
                                  color: AppColors.accentGreen,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppColors.accentGreen,
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Password Field
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                              decoration: InputDecoration(
                                labelText: "Password",
                                labelStyle: const TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w400,
                                ),
                                floatingLabelStyle: TextStyle(
                                  color: AppColors.accentGreen,
                                  fontWeight: FontWeight.w400,
                                ),
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  color: AppColors.accentGreen,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppColors.accentGreen,
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Sign Up Button
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.accentGreen,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _isLoading ? null : _signUp,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      "Create Account",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),
                      // Divider with "Or"
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.grey.withValues(alpha: 0.3),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                "Or",
                                style: TextStyle(
                                  color: Colors.grey.withOpacity(0.6),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.grey.withValues(alpha: 0.3),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Google Sign Up Button
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _signUpWithGoogle,
                              icon: SvgPicture.asset(
                                "assets/images/ic_vector_google.svg",
                                height: 20,
                                width: 20,
                              ),
                              label: const Text(
                                "Continue with Google",
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                      // Login Link
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                              );
                            },
                            child: RichText(
                              text: const TextSpan(
                                text: "Already have an account? ",
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                                children: [
                                  TextSpan(
                                    text: "Sign In",
                                    style: TextStyle(
                                      color: AppColors.accentGreen,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Loading overlay
        ),
        // if (_isLoading)
        //   Positioned.fill(
        //     child: Container(
        //       decoration: BoxDecoration(
        //         gradient: LinearGradient(
        //           begin: Alignment.topCenter,
        //           end: Alignment.bottomCenter,
        //           colors: [
        //             Colors.black.withValues(alpha: 0.3),
        //             Colors.black.withValues(alpha: 0.5),
        //           ],
        //         ),
        //       ),
        //       child: const Center(
        //         child: Column(
        //           mainAxisAlignment: MainAxisAlignment.center,
        //           children: [
        //             CircularProgressIndicator(
        //               valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        //               strokeWidth: 3,
        //             ),
        //             SizedBox(height: 20),
        //             Text(
        //               "Creating your account...",
        //               style: TextStyle(
        //                 color: Colors.white,
        //                 fontSize: 16,
        //                 fontWeight: FontWeight.w500,
        //               ),
        //             ),
        //           ],
        //         ),
        //       ),
        //     ),
        //   ),
      ],
    );
  }
}
