import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../theme/app_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  final _auth = FirebaseAuth.instance;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return regex.hasMatch(email);
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
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = _emailController.text.trim();

    // Validation
    if (!_isValidEmail(email)) {
      Fluttertoast.showToast(msg: "Please enter a valid email address.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _auth.sendPasswordResetEmail(email: email);
      setState(() => _emailSent = true);
      Fluttertoast.showToast(
        msg: "Password reset email sent! Check your inbox.",
        toastLength: Toast.LENGTH_LONG,
      );
    } on FirebaseAuthException catch (e) {
      String message = "Something went wrong.";
      if (e.code == 'user-not-found') {
        message = 'No account found with this email address.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many requests. Please try again later.';
      } else {
        message = e.message ?? message;
      }
      Fluttertoast.showToast(msg: message);
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: $e");
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
                      // Back Button
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.black87,
                                  size: 24,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const Spacer(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (!_emailSent) ...[
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
                                  Icons.lock_reset_outlined,
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
                                  "Reset Password",
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "Enter your email to receive a reset link",
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
                        const SizedBox(height: 30),

                        // Send Reset Link Button
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
                                onPressed: _isLoading ? null : _sendPasswordResetEmail,
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
                                        "Send Reset Link",
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
                    ] else ...[
                      // Success state
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Center(
                            child: Column(
                              children: [
                                const SizedBox(height: 40),
                                Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    color: AppColors.accentGreen.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.mark_email_read_outlined,
                                    size: 48,
                                    color: AppColors.accentGreen,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                const Text(
                                  "Check Your Email",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "We've sent a password reset link to\n${_emailController.text}",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 40),
                                Container(
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
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: const Text(
                                      "Back to Login",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _emailSent = false;
                                      _emailController.clear();
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                  child: Text(
                                    "Try Different Email",
                                    style: TextStyle(
                                      color: AppColors.accentGreen,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],

                  ],
                ),
              ),
            ),
          ),
        ),

        // Loading overlay
        )
      ],
    );
  }
}
