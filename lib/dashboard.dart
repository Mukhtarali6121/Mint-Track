import 'package:expense_tracker/theme/app_colors.dart';
import 'package:expense_tracker/theme/app_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:upgrader/upgrader.dart';

import 'package:package_info_plus/package_info_plus.dart';

import 'services/update_check_service.dart';
import 'common/currency_formatter.dart';
import 'common/currency_provider.dart';
import 'common/hive_storage.dart';
import 'edit_transaction.dart';
import 'models.dart';
import 'models/category.dart';
import 'services/notification_service.dart';
import 'transaction_provider.dart';
import 'account_provider.dart';
import 'widgets/goals_widget.dart';
import 'common/feature_flags.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  PeriodFilter _filter = PeriodFilter.month;
  DateTimeRange? _customRange;
  bool _isSyncing = false;
  String? _selectedAccountId; // null means "All Accounts"

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;



  DateTimeRange _currentRange() {
    final now = DateTime.now();
    switch (_filter) {
      case PeriodFilter.day:
        return DateTimeRange(start: _startOfDay(now), end: _endOfDay(now));
      case PeriodFilter.week:
        final start = now.subtract(Duration(days: now.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return DateTimeRange(start: _startOfDay(start), end: _endOfDay(end));
      case PeriodFilter.month:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0);
        return DateTimeRange(start: _startOfDay(start), end: _endOfDay(end));
      case PeriodFilter.year:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31);
        return DateTimeRange(start: _startOfDay(start), end: _endOfDay(end));
      case PeriodFilter.custom:
        return _customRange ??
            DateTimeRange(start: _startOfDay(now), end: _endOfDay(now));
    }
  }

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  @override
  void initState() {
    super.initState();
    // Reset dropdown to month
    _filter = PeriodFilter.month;
    Future.microtask(() => context.read<TransactionProvider>().initialize());

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

    // Initialize notifications
    _initializeNotifications();
    
    // Check for app updates
    _checkForUpdates();
  }
  
  /// Check for app updates from Play Store
  Future<void> _checkForUpdates() async {
    // Wait a bit to ensure the widget tree is built
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    try {
      final updateService = UpdateCheckService();
      final packageName = await updateService.getPackageName();
      final currentVersion = await updateService.getCurrentVersion();
      
      debugPrint('UpdateCheck: Current version: $currentVersion');
      debugPrint('UpdateCheck: Package name: $packageName');
      
      // Try to get latest version from Play Store
      final latestVersion = await updateService.checkForUpdate(packageName);
      
      if (latestVersion != null) {
        debugPrint('UpdateCheck: Latest version found: $latestVersion');
        
        // Compare versions
        if (updateService.isVersionNewer(currentVersion, latestVersion)) {
          debugPrint('UpdateCheck: Update available!');
          
          // Check if dialog has already been shown in this session
          if (!updateService.hasShownUpdateDialog && mounted) {
            // Show custom update dialog
            await UpdateCheckService.showUpdateDialog(
              context,
              currentVersion: currentVersion,
              newVersion: latestVersion,
              packageName: packageName,
            );
          } else {
            debugPrint('UpdateCheck: Update dialog already shown in this session');
          }
        } else {
          debugPrint('UpdateCheck: App is up to date');
        }
      } else {
        debugPrint('UpdateCheck: Could not determine latest version');
        
        // FOR TESTING: Manual override for closed testing
        // Set this to the version that's live in closed testing
        // Remove this in production or make it configurable via remote config
        const testLatestVersion = '1.0.4'; // Change this to match your closed testing version
        
        if (updateService.isVersionNewer(currentVersion, testLatestVersion)) {
          debugPrint('UpdateCheck: Test mode - Update available!');
          
          // Check if dialog has already been shown in this session
          if (!updateService.hasShownUpdateDialog && mounted) {
            await UpdateCheckService.showUpdateDialog(
              context,
              currentVersion: currentVersion,
              newVersion: testLatestVersion,
              packageName: packageName,
            );
          } else {
            debugPrint('UpdateCheck: Update dialog already shown in this session (test mode)');
          }
        } else {
          debugPrint('UpdateCheck: App is up to date (test mode)');
        }
      }
    } catch (e) {
      debugPrint('UpdateCheck: Error checking updates: $e');
    }
    
    // UpgraderAlert will also check automatically (for production when app is public)
  }

  /// Initialize notification service and request permissions
  Future<void> _initializeNotifications() async {
    try {
      // Initialize notification service
      await NotificationService().initialize();

      // Check if notifications are already enabled
      final areEnabled = await NotificationService().areNotificationsEnabled();

      if (!areEnabled) {
        // Request notification permissions
        final granted = await NotificationService().requestPermissions();

        if (granted) {
          // Schedule daily notification at 9:00 PM
          await NotificationService().scheduleDailyNotification();

          // Show a welcome notification
         /* await NotificationService().showTestNotification();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🔔 Notifications enabled! You\'ll receive daily reminders at 9:00 PM.'),
                backgroundColor: AppColors.accentGreen,
                duration: Duration(seconds: 3),
              ),
            );
          }*/
        } else {
          /*if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Notifications disabled. Enable them in settings to get daily reminders.'),
                backgroundColor: AppColors.warning,
                duration: Duration(seconds: 3),
              ),
            );
          }*/
        }
      } else {
        // Notifications already enabled, reschedule the daily notification
        await NotificationService().rescheduleDailyNotification();
      }
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _syncTransactions() async {
    setState(() => _isSyncing = true);

    try {
      final provider = context.read<TransactionProvider>();
      final syncStats = provider.getSyncStatistics();

      if (syncStats['unsynced'] == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All transactions are already synced!'),
            ),
          );
        }
        return;
      }

      final success = await provider.syncTransactionsToFirestore();

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully synced ${syncStats['unsynced']} transactions!',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to sync transactions. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: $e'),
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

  @override
  Widget build(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final String currencySymbol = currencyProvider.currencySymbol;

    final provider = context.watch<TransactionProvider>();
    final accountProvider = context.watch<AccountProvider>();
    final range = _currentRange();
    var items = provider.inRange(range.start, range.end);
    
    // Filter by selected account if one is selected
    if (_selectedAccountId != null) {
      items = items.where((e) => e.accountId == _selectedAccountId).toList();
    }
    
    final allTransactions = provider.items;
    final accounts = accountProvider.accounts;

    // Calculate totals based on filtered items
    final income = items
        .where((e) => e.type == TransactionType.income)
        .fold(0.0, (p, e) => p + e.amount);
    final expense = items
        .where((e) => e.type == TransactionType.expense)
        .fold(0.0, (p, e) => p + e.amount);
    
    // If account is selected, get account-specific balance
    double accountBalance = 0.0;
    if (_selectedAccountId != null) {
      accountBalance = provider.getAccountBalance(_selectedAccountId!);
    }

    // Only show update check on Android
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    
    Widget dashboardContent = Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: false,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0, // Prevent elevation change on scroll
          surfaceTintColor: Colors.transparent, // Prevent tint color change
          automaticallyImplyLeading: false, // Prevent back button
          title: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Text(
                'Dashboard',
                style: AppFonts.appBarTitle.copyWith(
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          centerTitle: true,
        ),
        body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8F9F8),
              Color(0xFFE8F5E9),
              Color(0xFFF1F8E9),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Column(
                    children: [
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.white.withOpacity(0.9),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  _selectedAccountId == null 
                                      ? 'Total Balance' 
                                      : '${accountProvider.getAccount(_selectedAccountId!)?.name ?? "Account"} Balance',
                                  style: AppFonts.titleLarge.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.format(
                                    amount: _selectedAccountId == null 
                                        ? (income - expense)
                                        : accountBalance,
                                    symbol: currencySymbol,
                                    decimalDigits: 1,
                                    spaceBetween: true,
                                  ),
                                  style: AppFonts.titleLarge.copyWith(
                                    color: (_selectedAccountId == null ? (income - expense) : accountBalance) >= 0
                                        ? Colors.teal
                                        : Colors.redAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryTile(
                                    label: 'Expenses',
                                    amount: expense,
                                    backgroundColor: AppColors.error,
                                    icon: Icons.arrow_upward,
                                    iconColor: Colors.white,
                                    currency: currencySymbol,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSummaryTile(
                                    label: 'Income',
                                    amount: income,
                                    backgroundColor: AppColors.accentGreen,
                                    icon: Icons.arrow_downward,
                                    iconColor: Colors.white,
                                    currency: currencySymbol,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Goals Widget
                if (FeatureFlags.goalsFeatureEnabled) ...[
                  const GoalsWidget(),
                  const SizedBox(height: 16),
                ],

                // Sync Status Indicator
                // Consumer<TransactionProvider>(
                //   builder: (context, provider, child) {
                //     final syncStats = provider.getSyncStatistics();
                //     final unsyncedCount = syncStats['unsynced'] ?? 0;
                //
                //     if (unsyncedCount > 0) {
                //       return Container(
                //         margin: const EdgeInsets.only(bottom: 16),
                //         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                //         decoration: BoxDecoration(
                //           color: Colors.orange.shade50,
                //           borderRadius: BorderRadius.circular(12),
                //           border: Border.all(color: Colors.orange.shade200),
                //         ),
                //         child: Row(
                //           children: [
                //             Icon(Icons.cloud_off, color: Colors.orange.shade600, size: 20),
                //             const SizedBox(width: 8),
                //             Expanded(
                //               child: Text(
                //                 '$unsyncedCount transactions not synced',
                //                 style: TextStyle(
                //                   color: Colors.orange.shade700,
                //                   fontWeight: FontWeight.w500,
                //                 ),
                //               ),
                //             ),
                //             TextButton(
                //               onPressed: _isSyncing ? null : _syncTransactions,
                //               child: Text(
                //                 'Sync Now',
                //                 style: TextStyle(
                //                   color: Colors.orange.shade700,
                //                   fontWeight: FontWeight.bold,
                //                 ),
                //               ),
                //             ),
                //           ],
                //         ),
                //       );
                //     }
                //
                //     return const SizedBox.shrink();
                //   },
                // ),
                // Enhanced Transactions Header & Filters Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        Colors.white.withOpacity(0.95),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row with Title and Icon
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accentGreen.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.receipt_long,
                              color: AppColors.accentGreen,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "Transactions",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Filters Row
                      Row(
                        children: [
                          // Period Filter
                          Expanded(
                            child: Container(
                              height: 50,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundScaffold,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.accentGreen.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                    color: AppColors.accentGreen,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButton<PeriodFilter>(
                                      value: _filter,
                                      isExpanded: true,
                                      underline: const SizedBox.shrink(),
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      icon: Icon(
                                        Icons.keyboard_arrow_down,
                                        color: AppColors.accentGreen,
                                      ),
                                      items: [
                                        PeriodFilter.day,
                                        PeriodFilter.week,
                                        PeriodFilter.month,
                                        PeriodFilter.year,
                                        PeriodFilter.custom,
                                      ].map((PeriodFilter filter) {
                                        return DropdownMenuItem<PeriodFilter>(
                                          value: filter,
                                          child: Text(
                                            _labelForFilter(filter),
                                            style: TextStyle(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (PeriodFilter? newValue) async {
                                        if (newValue == null) return;

                                        if (newValue == PeriodFilter.custom) {
                                          final picked = await showDateRangePicker(
                                            context: context,
                                            firstDate: DateTime(2015),
                                            lastDate: DateTime(2100),
                                            initialDateRange: _currentRange(),
                                          );

                                          if (picked != null) {
                                            setState(() {
                                              _filter = newValue;
                                              _customRange = DateTimeRange(
                                                start: _startOfDay(picked.start),
                                                end: _endOfDay(picked.end),
                                              );
                                            });
                                          }
                                        } else {
                                          setState(() {
                                            _filter = newValue;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Account Filter (only if accounts exist)
                          if (accounts.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                height: 50,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundScaffold,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.accentGreen.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.account_balance_wallet,
                                      size: 18,
                                      color: AppColors.accentGreen,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: DropdownButton<String>(
                                        value: _selectedAccountId,
                                        isExpanded: true,
                                        underline: const SizedBox.shrink(),
                                        hint: Text(
                                          'All Accounts',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        icon: Icon(
                                          Icons.keyboard_arrow_down,
                                          color: AppColors.accentGreen,
                                        ),
                                        items: [
                                          DropdownMenuItem<String>(
                                            value: null,
                                            child: Text(
                                              'All Accounts',
                                              style: TextStyle(
                                                color: AppColors.textPrimary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          ...accounts.map((account) {
                                            return DropdownMenuItem<String>(
                                              value: account.id,
                                              child: Text(
                                                account.name,
                                                style: TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ],
                                        onChanged: (String? newValue) {
                                          setState(() {
                                            _selectedAccountId = newValue;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Transaction List (no longer Expanded, just part of scrollable content)
                items.isEmpty
                    ? _buildEmptyState(allTransactions.isEmpty)
                    : _buildGroupedTransactionList(items, currencySymbol),
                
                const SizedBox(height: 80), // Extra padding at bottom for FAB
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
        floatingActionButton: allTransactions.isEmpty
            ? null
            : FloatingActionButton(
          onPressed: () => Navigator.of(context).pushNamed('/edit'),
          backgroundColor: AppColors.accentGreen,
          // your desired color
          child: const Icon(Icons.add, color: Colors.white),
        ),
      );
    
    // Wrap with UpgradeAlert only on Android
    if (isAndroid) {
      return UpgradeAlert(
        upgrader: Upgrader(
          // For Android, upgrader automatically checks Play Store using package name
          // It queries the Play Store web page using the app's package name
          durationUntilAlertAgain: const Duration(days: 3),
          // Enable debug mode to see what's happening in logs
          debugLogging: true,
        ),
        child: dashboardContent,
      );
    }
    
    return dashboardContent;
  }

  Widget _buildEmptyState(bool hasNoTransactionsAtAll) {
    if (hasNoTransactionsAtAll) {
      // Show enhanced UI when user has no transactions at all
      return FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                      // Animated Icon
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accentGreen.withOpacity(0.1),
                              AppColors.accentGreen.withOpacity(0.05),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentGreen.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.receipt_long_outlined,
                          size: 50,
                          color: AppColors.accentGreen.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        'No Transactions Yet',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Subtitle
                      Text(
                        'Start tracking your expenses and income\nto see your financial overview here',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Call to Action Button
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accentGreen,
                              AppColors.accentGreen.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentGreen.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pushNamed('/edit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: Colors.white,
                            size: 22,
                          ),
                          label: const Text(
                            'Add Your First Transaction',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
    } else {
      // Show simple message when user has transactions but none in selected period
      return FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Simple Icon
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.search_off,
                      size: 35,
                      color: Colors.grey.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    'No Transactions in This Period',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Subtitle
                  Text(
                    'Try selecting a different time period\nto view your transactions',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  /// 🧾 Grouped Transaction List by Date
  Widget _buildGroupedTransactionList(
      List<TransactionItem> items,
      String currencySymbol,
      ) {
    // Sort items by date descending
    items.sort((a, b) => b.date.compareTo(a.date));

    return ListView.builder(
      shrinkWrap: true, // Allow ListView to size itself based on content
      physics: const NeverScrollableScrollPhysics(), // Disable scrolling - parent handles it
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final t = items[index];

        return Dismissible(
          key: Key(t.id),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.delete,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete Transaction'),
                content: const Text('Are you sure you want to delete this transaction? This action cannot be undone.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) async {
            final provider = context.read<TransactionProvider>();
            await provider.remove(t.id);
          },
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
            elevation: 2,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditTransactionScreen(existing: t),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Icon
                    Builder(
                      builder: (context) {
                        final firestoreCategory = _getCategoryFromFirestore(t.category, t.type);
                        final categoryColor = firestoreCategory?.color ?? _getCategoryFromString(t.category).color;
                        final iconPath = firestoreCategory?.iconPath ?? _getIconPathFromCategoryName(t.category);

                        return Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: SvgPicture.asset(
                              iconPath,
                              colorFilter: ColorFilter.mode(
                                categoryColor,
                                BlendMode.srcIn,
                              ),
                              width: 22,
                              height: 22,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 16),

                    // Title, Category + Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.category,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            t.title.isEmpty ? 'Not Specified' : t.title,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${t.type == TransactionType.income ? '+' : '-'} ${CurrencyFormatter.format(amount: t.amount, symbol: currencySymbol, decimalDigits: 2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: t.type == TransactionType.income
                                ? Colors.teal
                                : Colors.redAccent,
                          ),
                        ),

                        Text(
                          DateFormat.yMMMd().format(t.date),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  Widget _buildSummaryTile({
    required String label,
    required double amount,
    required Color backgroundColor,
    required IconData icon,
    required Color iconColor,
    required String currency,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            backgroundColor.withOpacity(0.8),
            backgroundColor,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Arrow icon in circle
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 10),

          // Label + Amount
          // --- MODIFICATION START ---
          // Use Flexible to allow the Column to shrink if needed.
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    CurrencyFormatter.format(
                      amount: amount,
                      symbol: currency,
                      decimalDigits: 1,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // --- MODIFICATION END ---
        ],
      ),
    );
  }

}

Category? _getCategoryFromFirestore(String categoryName, TransactionType type) {
  final setupData = HiveStorage.getSetupData();
  if (setupData == null) return null;

  final categories = type == TransactionType.expense
      ? setupData.expenseCategories
      : setupData.incomeCategories;

  try {
    return categories.firstWhere((category) => category.name == categoryName);
  } catch (e) {
    return null;
  }
}

TransactionCategory _getCategoryFromString(String categoryName) {
  // 👇 Add this line to debug
  debugPrint('DEBUG: Received categoryName = "$categoryName"');

  return TransactionCategory.values.firstWhere(
        (e) => e.displayName == categoryName,
    orElse: () {
      // This part only runs if no match was found above
      debugPrint('INFO: Match failed. Defaulting to "Others".');
      return TransactionCategory.others;
    },
  );
}

// Helper method to get SVG icon path from category name
String _getIconPathFromCategoryName(String categoryName) {
  // Map category names to their corresponding SVG file paths
  const Map<String, String> iconMap = {
    // Expense categories
    'Food': 'assets/images/ic_vector_food.svg',
    'Drinks': 'assets/images/ic_vector_drink.svg',
    'Transportation': 'assets/images/ic_vector_transportation.svg',
    'Housing': 'assets/images/ic_vector_home.svg',
    'Shopping': 'assets/images/ic_vector_shopping_bag.svg',
    'Health': 'assets/images/ic_vector_health.svg',
    'Fitness': 'assets/images/ic_vector_fitness.svg',
    'Entertainment': 'assets/images/ic_vector_entertainment.svg',
    'Games': 'assets/images/ic_vector_game.svg',
    'Education': 'assets/images/ic_vector_education.svg',
    'Loans': 'assets/images/ic_vector_loan.svg',
    'Savings': 'assets/images/ic_vector_investment.svg',
    'Investments': 'assets/images/ic_vector_investment.svg',
    'Travel': 'assets/images/ic_vector_travel.svg',
    'Gifts': 'assets/images/ic_vector_gifts.svg',
    'Donations': 'assets/images/ic_vector_donate.svg',
    'Beauty': 'assets/images/ic_vector_beauty.svg',
    'Taxes': 'assets/images/ic_vector_tax.svg',
    'Others': 'assets/images/ic_vector_other.svg',

    // Income categories
    'Salary': 'assets/images/ic_vector_salary.svg',
    'Business': 'assets/images/ic_vector_business.svg',
    'Interest Income': 'assets/images/ic_vector_interest_income.svg',
    'Rental Income': 'assets/images/ic_vector_rental_income.svg',
  };

  return iconMap[categoryName] ?? 'assets/images/ic_vector_other.svg';
}

String _labelForFilter(PeriodFilter filter) {
  switch (filter) {
    case PeriodFilter.day:
      return 'Day';
    case PeriodFilter.week:
      return 'Week';
    case PeriodFilter.month:
      return 'Month';
    case PeriodFilter.year:
      return 'Year';
    case PeriodFilter.custom:
      return 'Period';
  }
}