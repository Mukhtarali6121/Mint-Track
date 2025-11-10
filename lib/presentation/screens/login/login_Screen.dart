import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/presentation/screens/dashboard.dart';
import 'package:expense_tracker/presentation/screens/set_up_flow.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/presentation/screens/login/create_account_screen.dart';
import 'package:expense_tracker/presentation/screens/login/forgot_password_screen.dart';
import '../../../common/transaction_hive_storage.dart';
import '../../../models/hive_transaction.dart';
import '../../../theme/app_colors.dart';
import '../../../common/hive_storage.dart';
import '../../../models/setup_data.dart';
import '../../../providers/transaction_provider.dart';
import '../../../services/data_cleanup_service.dart';
import '../../../providers/account_provider.dart';
import '../../../providers/goal_provider.dart';
import '../../../models/account.dart';
import '../../../common/account_hive_storage.dart';
import '../../../common/account_migration.dart';
import '../MainPage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Validation
    if (!_isValidEmail(email)) {
      Fluttertoast.showToast(msg: "Please enter a valid email.");
      return;
    }
    if (!_isValidPassword(password)) {
      Fluttertoast.showToast(msg: "Password must be at least 6 characters.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Clear any old data before login
      await DataCleanupService.clearAllData();
      
      // Sign in user with Firebase Auth
      final userCredential =
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      final userId = userCredential.user?.uid;

      if (userId == null) throw Exception("User ID is null");

      // Save isLoggedIn in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      // Save user profile locally from Firestore if available
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        final name = userDoc.data()?['name'] as String? ?? '';
        final emailFromDb = userDoc.data()?['email'] as String? ?? email;
        await HiveStorage.saveUserProfile(userId: userId, name: name, email: emailFromDb);
      } catch (_) {}

      // 1️⃣ Sync SetupData from Firestore to Hive
      final setupDoc = await FirebaseFirestore.instance
          .collection('SetupData')
          .doc(userId)
          .get();

      if (setupDoc.exists) {
        try {
          final setupData = SetupData.fromMap(setupDoc.data()!, userId);
          await HiveStorage.saveSetupData(setupData);
          debugPrint("Setup data synced to Hive successfully.");
        } catch (e) {
          Fluttertoast.showToast(msg: "Failed to sync setup data: $e");
        }
      }else{
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SetupFlow()),
        );
      }

      // 2️⃣ Fetch transactions from Firestore
      final transactionsSnapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .doc(userId)
          .collection('userTransactions')
          .get();

      if (transactionsSnapshot.docs.isNotEmpty) {
        for (final doc in transactionsSnapshot.docs) {
          final data = doc.data();
          // Convert Firestore data to HiveTransaction
          final transaction = HiveTransaction(
            id: doc.id,
            userId: userId,
            title: data['title'] ?? '',
            amount: (data['amount'] ?? 0).toDouble(),
            date: (data['date'] as Timestamp).toDate(),
            category: data['category'] ?? '',
            type: data['type'] ?? 'expense',
            isSynced: true, // since it comes from Firestore
            createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            accountId: data['accountId'] as String? ?? 'cash',
          );

          await TransactionHiveStorage.saveTransaction(transaction);
        }
        debugPrint("Transactions synced from Firestore to Hive.");
      } else {
        debugPrint("No transactions found in Firestore for this user.");
      }

      // 2️⃣ Fetch accounts from Firestore
      await AccountHiveStorage.init();
      final accountsSnapshot = await FirebaseFirestore.instance
          .collection('accounts')
          .doc(userId)
          .collection('userAccounts')
          .get();

      if (accountsSnapshot.docs.isNotEmpty) {
        for (final doc in accountsSnapshot.docs) {
          final data = doc.data();
          // Convert Firestore data to Account
          final account = Account.fromFirestoreMap(data, doc.id);
          await AccountHiveStorage.saveAccount(account);
        }
        debugPrint("Accounts synced from Firestore to Hive.");
      } else {
        debugPrint("No accounts found in Firestore for this user.");
        // Run migration to create default Cash account
        await AccountMigration.migrateToAccounts();
      }

      // 2️⃣ Fetch goals from Firestore
      final goalProvider = context.read<GoalProvider>();
      await goalProvider.loadGoalsFromFirestore();

      // 3️⃣ Reset and reinitialize TransactionProvider
      if (mounted) {
        final transactionProvider = context.read<TransactionProvider>();
        await transactionProvider.resetAndInitialize();
        
        // Reset and initialize AccountProvider (to clear any old state)
        final accountProvider = context.read<AccountProvider>();
        await accountProvider.resetAndInitialize();
        
        // Reset and initialize GoalProvider
        final goalProvider = context.read<GoalProvider>();
        await goalProvider.resetAndInitialize();
        
        // Run migration if needed (will create Cash account if doesn't exist)
        await AccountMigration.migrateToAccounts();
      }

      // 4️⃣ Navigate to dashboard or setup flow
      if (setupDoc.exists) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainPageWidget()),
            (route) => false, // Remove all previous routes
          );
        }
      } else {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SetupFlow()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = "Something went wrong.";
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided for that user.';
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

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // Clear any old data before login
      await DataCleanupService.clearAllData();
      
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      // Get Google authentication credentials
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // Try to sign in with credential (will work if account exists or create new one)
      final userCredential = await _auth.signInWithCredential(credential);
      
      // Ensure user profile exists in Firestore and cache it locally
      try {
        final u = userCredential.user;
        if (u != null) {
          await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
            'name': u.displayName ?? '',
            'email': u.email ?? '',
          }, SetOptions(merge: true));
          await HiveStorage.saveUserProfile(
            userId: u.uid,
            name: u.displayName ?? '',
            email: u.email ?? '',
          );
        }
      } catch (_) {}

      // Save isLoggedIn
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      // Reuse the same post-login flow as email login: fetch setup + transactions and navigate
      final userId = userCredential.user?.uid;
      if (userId == null) throw Exception('User ID is null');

      final setupDoc = await FirebaseFirestore.instance
          .collection('SetupData')
          .doc(userId)
          .get();

      if (setupDoc.exists) {
        try {
          final setupData = SetupData.fromMap(setupDoc.data()!, userId);
          await HiveStorage.saveSetupData(setupData);
        } catch (_) {}
      }

      // Fetch accounts from Firestore
      await AccountHiveStorage.init();
      final accountsSnapshot = await FirebaseFirestore.instance
          .collection('accounts')
          .doc(userId)
          .collection('userAccounts')
          .get();

      if (accountsSnapshot.docs.isNotEmpty) {
        for (final doc in accountsSnapshot.docs) {
          final data = doc.data();
          // Convert Firestore data to Account
          final account = Account.fromFirestoreMap(data, doc.id);
          await AccountHiveStorage.saveAccount(account);
        }
        debugPrint("Accounts synced from Firestore to Hive.");
      } else {
        debugPrint("No accounts found in Firestore for this user.");
        // Run migration to create default Cash account
        await AccountMigration.migrateToAccounts();
      }

      final transactionsSnapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .doc(userId)
          .collection('userTransactions')
          .get();

      if (transactionsSnapshot.docs.isNotEmpty) {
        for (final doc in transactionsSnapshot.docs) {
          final data = doc.data();
          final transaction = HiveTransaction(
            id: doc.id,
            userId: userId,
            title: data['title'] ?? '',
            amount: (data['amount'] ?? 0).toDouble(),
            date: (data['date'] as Timestamp).toDate(),
            category: data['category'] ?? '',
            type: data['type'] ?? 'expense',
            isSynced: true,
            createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            accountId: data['accountId'] as String? ?? 'cash',
          );
          await TransactionHiveStorage.saveTransaction(transaction);
        }
      }

      if (!mounted) return;
      
      // Reset and reinitialize TransactionProvider
      final transactionProvider = context.read<TransactionProvider>();
      await transactionProvider.resetAndInitialize();
      
      // Reset and initialize AccountProvider (to clear any old state)
      final accountProvider = context.read<AccountProvider>();
      await accountProvider.resetAndInitialize();
      
      // Reset and initialize GoalProvider
      final goalProvider = context.read<GoalProvider>();
      await goalProvider.resetAndInitialize();
      await goalProvider.loadGoalsFromFirestore();
      
      // Run migration if needed (will create Cash account if doesn't exist)
      await AccountMigration.migrateToAccounts();
      
      if (setupDoc.exists) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainPageWidget()),
          (route) => false, // Remove all previous routes
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SetupFlow()),
        );
      }
    } on FirebaseAuthException catch (e) {
      // If the user previously registered with email/password and now uses Google, Firebase will link automatically if same email.
      // If email/password exists and Google is not allowed, show specific guidance.
      final code = e.code;
      String msg = e.message ?? 'Sign-in failed';
      if (code == 'account-exists-with-different-credential') {
        // Fetch methods for the email to give better guidance
        final email = e.email;
        if (email != null) {
          final methods = await _auth.fetchSignInMethodsForEmail(email);
          if (methods.contains('password')) {
            msg = 'This email is linked with Email/Password. Please use Email login and then link Google from settings.';
          } else if (methods.contains('google.com')) {
            msg = 'This email is linked with Google Sign-In. Please use Google to log in.';
          }
        }
      }
      Fluttertoast.showToast(msg: msg);
    } catch (e) {
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
                                Icons.account_balance_wallet_outlined,
                                size: 32,
                                color: AppColors.accentGreen,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Welcome Back",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Login to continue your financial journey",
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
                      const SizedBox(height: 16),
                      // Forgot Password Link
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ForgotPasswordScreen(),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            child: Text(
                              "Forgot Password?",
                              style: TextStyle(
                                color: AppColors.accentGreen,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Login Button
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
                              onPressed: _isLoading ? null : _signIn,
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
                                "Sign In",
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
                                      Colors.grey.withOpacity(0.3),
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
                                      Colors.grey.withOpacity(0.3),
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

                      // Google Sign In Button
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
                              onPressed: _isLoading ? null : _signInWithGoogle,
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
                      // Sign Up Link
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CreateAccountScreen(),
                                ),
                              );
                            },
                            child: RichText(
                              text: const TextSpan(
                                text: "Don't have an account? ",
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                                children: [
                                  TextSpan(
                                    text: "Sign Up",
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
        ),
        // *** ADDED CODE SNIPPET STARTS HERE ***
        // if (_isLoading)
        //   Positioned.fill(
        //     child: Container(
        //       decoration: BoxDecoration(
        //         gradient: LinearGradient(
        //           begin: Alignment.topCenter,
        //           end: Alignment.bottomCenter,
        //           colors: [
        //             Colors.black.withOpacity(0.3),
        //             Colors.black.withOpacity(0.5),
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
        //               "Signing you in...",
        //               style: TextStyle(
        //                 color: Colors.white,
        //                 fontSize: 16,
        //                 fontWeight: FontWeight.w500,
        //                 decoration: TextDecoration.none, // Added to remove underline in Stack
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