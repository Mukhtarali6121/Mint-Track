import 'package:expense_tracker/presentation/screens/MainPage.dart';
import 'package:expense_tracker/presentation/screens/login/create_account_screen.dart';
import 'package:expense_tracker/presentation/screens/edit_categories_page.dart';
import 'package:expense_tracker/presentation/screens/login/login_Screen.dart';
import 'package:expense_tracker/presentation/screens/login/onboarding_screen.dart';
import 'package:expense_tracker/services/notification_service.dart';
import 'package:expense_tracker/theme/app_colors.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'common/currency_provider.dart';
import 'goal_provider.dart';
import 'package:provider/provider.dart';

import 'common/local_storage.dart';
import 'common/hive_storage.dart';
import 'common/transaction_hive_storage.dart';
import 'common/account_hive_storage.dart';
import 'common/account_migration.dart';
import 'dashboard.dart';
import 'edit_transaction.dart';
import 'search_screen.dart';
import 'presentation/screens/more_screen.dart';
import 'presentation/screens/profile_details_screen.dart';
import 'presentation/screens/terms_and_conditions_screen.dart';
import 'presentation/screens/charts_screen.dart';
import 'presentation/screens/accounts_screen.dart';
import 'firebase_options.dart';
// 1. IMPORT YOUR NEW PROVIDER
import 'transaction_provider.dart';
import 'account_provider.dart';
import 'theme/app_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Crashlytics
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await LocalStorage().init();
  await HiveStorage.init();
  await TransactionHiveStorage.init(); // Adapter registers here safely
  await AccountHiveStorage.init(); // Initialize Account storage
  await NotificationService().initialize();
  
  // Run account migration if needed
  await AccountMigration.migrateToAccounts();
  
  // Check Firebase Auth state (persists across app restarts)
  final FirebaseAuth auth = FirebaseAuth.instance;
  final bool hasFirebaseUser = auth.currentUser != null;
  
  // Get SharedPreferences values
  bool isLoggedIn = LocalStorage().getBool('isLoggedIn');
  bool onboardingCompleted = LocalStorage().getBool('onboarding_completed');
  
  // If Firebase Auth has a current user, they are logged in (regardless of SharedPreferences)
  // Also, if they're logged in, they must have completed onboarding
  if (hasFirebaseUser) {
    isLoggedIn = true;
    // If onboarding_completed was cleared but user is logged in, restore it
    if (!onboardingCompleted) {
      onboardingCompleted = true;
      await LocalStorage().setBool('onboarding_completed', true);
      await LocalStorage().setBool('isLoggedIn', true);
    }
  }
  
  runApp(MyApp(isLoggedIn: isLoggedIn, onboardingCompleted: onboardingCompleted));
}


class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final bool onboardingCompleted;

  const MyApp({super.key, required this.isLoggedIn, required this.onboardingCompleted});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // 2. WRAP WITH MULTIPROVIDER TO HANDLE MULTIPLE PROVIDERS
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => AccountProvider()),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()), // 3. ADD THE NEW CURRENCYPROVIDER
        ChangeNotifierProvider(create: (_) => GoalProvider()),
      ],
      child: MaterialApp(
        title: 'Expense Tracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          fontFamily: AppFonts.fontFamily,
          textTheme: const TextTheme(
            displayLarge: AppFonts.displayLarge,
            displayMedium: AppFonts.displayMedium,
            displaySmall: AppFonts.displaySmall,
            headlineLarge: AppFonts.headlineLarge,
            headlineMedium: AppFonts.headlineMedium,
            headlineSmall: AppFonts.headlineSmall,
            titleLarge: AppFonts.titleLarge,
            titleMedium: AppFonts.titleMedium,
            titleSmall: AppFonts.titleSmall,
            bodyLarge: AppFonts.bodyLarge,
            bodyMedium: AppFonts.bodyMedium,
            bodySmall: AppFonts.bodySmall,
            labelLarge: AppFonts.labelLarge,
            labelMedium: AppFonts.labelMedium,
            labelSmall: AppFonts.labelSmall,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.backgroundScaffold,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: AppFonts.appBarTitle.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          scaffoldBackgroundColor: AppColors.backgroundScaffold,
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            labelStyle: AppFonts.inputLabel,
            hintStyle: AppFonts.inputHint,
            errorStyle: AppFonts.errorText,
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: AppColors.accentGreen,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              textStyle: AppFonts.buttonText,
            ),
          ),
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: AppColors.accentGreen,
            selectionColor: AppColors.accentGreen.withOpacity(0.3),
            selectionHandleColor: AppColors.accentGreen,
          ),
        ),
        home: _getInitialScreen(),
        routes: {
          '/edit': (_) => const EditTransactionScreen(),
          '/search': (_) => const SearchScreen(),
          '/charts': (_) => const ChartsScreen(),
          '/profile': (_) => const PlaceholderScreen(title: 'Profile'),
          // Replace placeholder with real profile details screen
          '/account': (_) => const ProfileDetailsScreen(),
          '/upgrade': (_) => const PlaceholderScreen(title: 'Upgrade Now'),
          '/categories': (_) => const EditCategoriesPage(),
          '/accounts': (_) => const AccountsScreen(),
          '/labels': (_) => const PlaceholderScreen(title: 'Labels'),
          '/scheduled': (_) => const PlaceholderScreen(title: 'Scheduled Transactions'),
          '/currency': (_) => const PlaceholderScreen(title: 'Main Currency'),
          '/manual-wallets': (_) => const PlaceholderScreen(title: 'Manual Wallets'),
          '/bank-wallets': (_) => const PlaceholderScreen(title: 'Bank Accounts & E-Wallets'),
          '/crypto-wallets': (_) => const PlaceholderScreen(title: 'Crypto Wallets'),
          '/advanced': (_) => const PlaceholderScreen(title: 'Advanced'),
          '/help': (_) => const PlaceholderScreen(title: 'Help Center'),
          '/support': (_) => const PlaceholderScreen(title: 'Contact Support'),
          '/terms': (_) => const TermsAndConditionsScreen(),
        },
      ),
    );
  }

  Widget _getInitialScreen() {
    if (!onboardingCompleted) {
      return const OnboardingScreen();
    } else if (isLoggedIn) {
      return const MainPageWidget();
    } else {
      return const LoginScreen();
    }
  }
}
