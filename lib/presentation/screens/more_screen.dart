import 'package:expense_tracker/presentation/screens/profile/currency_selection_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../../common/currency_provider.dart';
import '../../common/hive_storage.dart';
import '../../common/transaction_hive_storage.dart';
import '../../services/notification_service.dart';
import '../../services/data_cleanup_service.dart';
import '../../theme/app_colors.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/goal_provider.dart';
import 'login/login_Screen.dart';
import 'goals_screen.dart';
import '../../common/feature_flags.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MoreScreen extends StatefulWidget { // Change this
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState(); // Add this
}

class _MoreScreenState extends State<MoreScreen> with TickerProviderStateMixin {
  bool _isSyncing = false;
  bool _notificationsEnabled = false;
  String _appVersion = 'Loading...';

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  Future<void> _backupData() async {
    setState(() => _isSyncing = true);

    // Show updating snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(width: 16),
            Text('Backing up data...'),
          ],
        ),
        duration: Duration(minutes: 1), // Will be dismissed manually
        backgroundColor: AppColors.accentGreen,
      ),
    );

    try {
      final accountProvider = context.read<AccountProvider>();
      final transactionProvider = context.read<TransactionProvider>();
      // 1. Sync accounts first
      final accountSyncStats = accountProvider.getSyncStatistics();
      bool accountsSynced = true;
      
      if (accountSyncStats['unsynced']! > 0) {
        accountsSynced = await accountProvider.syncAccountsToFirestore();
        if (!accountsSynced) {
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to backup accounts. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }
      
      // 2. Sync goals (if feature is enabled)
      bool goalsSynced = true;
      int unsyncedGoals = 0;
      if (FeatureFlags.goalsFeatureEnabled) {
        final goalProvider = context.read<GoalProvider>();
        final goalSyncStats = goalProvider.getSyncStatistics();
        unsyncedGoals = goalSyncStats['unsynced']!;
        
        if (unsyncedGoals > 0) {
          goalsSynced = await goalProvider.syncGoalsToFirestore();
        }
      }

      // 3. Sync transactions
      final syncStats = transactionProvider.getSyncStatistics();
      bool transactionsSynced = true;

      if (syncStats['unsynced'] == 0 && accountSyncStats['unsynced'] == 0 && unsyncedGoals == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All data is already backed up!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      if (syncStats['unsynced']! > 0) {
        transactionsSynced = await transactionProvider.syncTransactionsToFirestore();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (accountsSynced && transactionsSynced && goalsSynced) {
          final totalSynced = (accountSyncStats['unsynced'] ?? 0) + 
                              (syncStats['unsynced'] ?? 0) + 
                              unsyncedGoals;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully backed up ${accountSyncStats['unsynced'] ?? 0} account(s), ${syncStats['unsynced'] ?? 0} transaction(s)${FeatureFlags.goalsFeatureEnabled ? ', and $unsyncedGoals goal(s)' : ''}!',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to backup data. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    
    // Clear ALL local data (including accounts)
    await DataCleanupService.clearAllData();
    
    // Reset providers to clear in-memory state
    final accountProvider = context.read<AccountProvider>();
    final transactionProvider = context.read<TransactionProvider>();
    await accountProvider.resetAndInitialize();
    await transactionProvider.resetAndInitialize();
    
    if (FeatureFlags.goalsFeatureEnabled) {
      final goalProvider = context.read<GoalProvider>();
      await goalProvider.resetAndInitialize();
    }
    
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _showFeedbackDialog() async {
    final TextEditingController feedbackController = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.feedback,
                        color: AppColors.accentGreen,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Share Your Feedback',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Description text
                Text(
                  'We value your thoughts and suggestions to improve our app.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Feedback input field
                TextField(
                  controller: feedbackController,
                  decoration: InputDecoration(
                    hintText: 'What would you like to tell us?',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.accentGreen, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  maxLines: 5,
                  minLines: 3,
                  style: const TextStyle(fontSize: 16),
                ),
                
                const SizedBox(height: 24),
                
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (feedbackController.text.trim().isNotEmpty) {
                          await _saveFeedback(feedbackController.text.trim(), user?.uid);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Thank you for your feedback!'),
                              backgroundColor: AppColors.accentGreen,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please share your thoughts with us'),
                              backgroundColor: AppColors.warning,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Send Feedback'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveFeedback(String feedback, String? userId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('feedback').add({
        'userId': userId ?? 'anonymous',
        'feedback': feedback,
        'timestamp': FieldValue.serverTimestamp(),
        'userEmail': FirebaseAuth.instance.currentUser?.email ?? '',
      });
    } catch (e) {
      debugPrint('Error saving feedback: $e');
    }
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

    // Check notification status
    _checkNotificationStatus();
    
    // Load app version
    _loadAppVersion();
  }

  /// Load app version from package info
  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'Version ${packageInfo.version}+${packageInfo.buildNumber}';
        });
      }
    } catch (e) {
      debugPrint('Error loading app version: $e');
      if (mounted) {
        setState(() {
          _appVersion = 'Version 1.0.3';
        });
      }
    }
  }


  /// Check if notifications are enabled
  Future<void> _checkNotificationStatus() async {
    try {
      final areEnabled = await NotificationService().areNotificationsEnabled();
      if (mounted) {
        setState(() {
          _notificationsEnabled = areEnabled;
        });
      }
    } catch (e) {
      debugPrint('Error checking notification status: $e');
    }
  }

  /// Toggle notification settings
  Future<void> _toggleNotifications() async {
    try {
      if (_notificationsEnabled) {
        // Disable notifications
        await NotificationService().cancelAllNotifications();
        setState(() {
          _notificationsEnabled = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔕 Notifications disabled'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      } else {
        // Enable notifications
        final granted = await NotificationService().requestPermissions();
        if (granted) {
          await NotificationService().scheduleDailyNotification();
          setState(() {
            _notificationsEnabled = true;
          });
          
          if (mounted) {
            // ScaffoldMessenger.of(context).showSnackBar(
            //   const SnackBar(
            //     content: Text('🔔 Notifications enabled! Daily reminders at 9:00 PM.'),
            //     backgroundColor: AppColors.accentGreen,
            //   ),
            // );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Please enable notifications in device settings'),
                backgroundColor: AppColors.warning,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error toggling notifications: $e');
    }
  }

  /// Show test notification
  Future<void> _showTestNotification() async {
    try {
      await NotificationService().showTestNotification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔔 Test notification sent!'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error showing test notification: $e');
    }
  }

  /// Schedule test notification for 1 minute from now
  Future<void> _scheduleTestNotification() async {
    try {
      await NotificationService().scheduleTestNotificationInOneMinute();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏰ Test notification scheduled for 1 minute from now!'),
            backgroundColor: AppColors.accentGreen,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error scheduling test notification: $e');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final String currencySymbol = currencyProvider.currencySymbol;

    final user = FirebaseAuth.instance.currentUser;
    final setupData = HiveStorage.getSetupData();
    int categoryCount = 0;
    if (setupData != null) {
      categoryCount = setupData.expenseCategories.length + setupData.incomeCategories.length;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
              child: Text(
                'Profile',
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8F9F8),
              Color(0xFFE8F5E9),
              Color(0xFFF1F8E9),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Account',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
            ),
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.accentGreen.withOpacity(0.15),
                      child: const Icon(Icons.person, color: AppColors.accentGreen),
                    ),
                    title: Text(
                      HiveStorage.getUserName().isNotEmpty
                          ? HiveStorage.getUserName()
                          : (user?.displayName ?? 'Guest'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      HiveStorage.getUserEmail().isNotEmpty
                          ? HiveStorage.getUserEmail()
                          : (user?.email ?? ''),
                      style: TextStyle(
                        color: Colors.grey.withOpacity(0.7),
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.chevron_right, size: 20),
                    ),
                    onTap: () async {
                      await Navigator.pushNamed(context, '/account');
                      setState(() {});
                    },
                  ),
                ),
              ),
            ),
          _NavTile(
            icon: Icons.category,
            label: 'Categories',
            route: '/categories',
            trailing: Text(categoryCount.toString()), // Use the variable here
          ),
          _NavTile(
            icon: Icons.account_balance_wallet,
            label: 'Accounts',
            route: '/accounts',
          ),
          if (FeatureFlags.goalsFeatureEnabled)
            _NavTile(
              icon: Icons.flag_outlined,
              label: 'Goals',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GoalsScreen()),
                );
              },
            ),
          // _NavTile(icon: Icons.schedule, label: 'Scheduled Transactions', route: '/scheduled'),
          _NavTile(
            leading: SizedBox(
              width: 24, // Standard icon width for alignment
              child: Center(
                child: Text(
                  currencySymbol,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentGreen,
                  ),
                ),
              ),
            ),
            label: 'Main Currency',
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CurrencySelectionPage(),
                ),
              );

              if (result != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Selected: ${result['currencyCode']} (${result['currencySymbol']})')),
                );
                // Save to Hive or SharedPreferences here
              }
            },
          ),
          _NavTile(
            icon: Icons.backup,
            label: 'Backup Data',
            subtitle: 'Backup my Mint Track data',
            trailing: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.accentGreen,
                      ),
                    ),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _isSyncing ? null : _backupData,
          ),

          const _SectionHeader(title: 'Feedback'),
          _NavTile(
            icon: Icons.feedback,
            label: 'Send Feedback',
            subtitle: 'Share your thoughts and suggestions',
            onTap: _showFeedbackDialog,
          ),

          const _SectionHeader(title: 'Notifications'),
          _NavTile(
            icon: Icons.notifications,
            label: 'Daily Reminders',
            subtitle: _notificationsEnabled ? 'Enabled (9:00 PM)' : 'Disabled',
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (value) => _toggleNotifications(),
              activeColor: AppColors.accentGreen,
            ),
            onTap: _toggleNotifications,
          ),
          // if (_notificationsEnabled) ...[
          //   _NavTile(
          //     icon: Icons.notification_add,
          //     label: 'Test Notification',
          //     subtitle: 'Send a test notification now',
          //     onTap: _showTestNotification,
          //   ),
          //   _NavTile(
          //     icon: Icons.schedule,
          //     label: 'Test Scheduled Notification',
          //     subtitle: 'Schedule a test notification for 1 minute from now',
          //     onTap: _scheduleTestNotification,
          //   ),
          // ],

          const _SectionHeader(title: 'Other'),
          // _NavTile(icon: Icons.build, label: 'Advanced', route: '/advanced'),
          // _NavTile(icon: Icons.help_center, label: 'Help Center', route: '/help'),
          // _NavTile(icon: Icons.support_agent, label: 'Contact Support', route: '/support'),
          _NavTile(icon: Icons.description, label: 'Terms & Policies', route: '/terms'),
          // _NavTile(icon: Icons.description, label: 'Privacy Policy', route: '/terms'),

          const SizedBox(height: 12),
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.redAccent.withOpacity(0.8),
                        Colors.redAccent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    onPressed: () => _logout(context),
                    child: const Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: Text(
                _appVersion,
                style: const TextStyle(color: Colors.black54),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    ));
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    this.icon,
    this.leading, // 1. ADD a new optional 'leading' widget parameter
    required this.label,
    this.subtitle,
    this.route,
    this.trailing,
    this.onTap,
  }) : assert(icon == null || leading == null,
  'Cannot provide both an icon and a leading widget.'); // 2. ADD an assertion to prevent misuse

  final IconData? icon; // Make icon optional
  final Widget? leading; // The new parameter
  final String label;
  final String? subtitle;
  final String? route;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        leading: leading ?? (icon != null
            ? Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.accentGreen, size: 20),
              )
            : null),
        title: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: TextStyle(
                  color: Colors.grey.withOpacity(0.7),
                  fontSize: 14,
                ),
              )
            : null,
        trailing: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: trailing ?? const Icon(Icons.chevron_right, size: 20),
        ),
        onTap: onTap ?? () {
          if (route != null) Navigator.pushNamed(context, route!);
        },
      ),
    );
  }
}


class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          '$title Page',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}


