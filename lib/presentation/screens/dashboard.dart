import 'package:expense_tracker/theme/app_colors.dart';
import 'package:expense_tracker/theme/app_fonts.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:upgrader/upgrader.dart';

import '../../providers/account_provider.dart';
import '../../common/animation_utils.dart';
import '../../common/custom_page_route.dart';
import '../../common/currency_formatter.dart';
import '../../common/currency_provider.dart';
import '../../common/feature_flags.dart';
import '../../common/hive_storage.dart';
import 'edit_transaction.dart';
import '../../models.dart';
import '../../models/category.dart';
import 'search_screen.dart';
import '../../services/notification_service.dart';
import '../../services/update_check_service.dart';
import '../../services/category_icon_service.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/recurring_transactions_widget.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../../providers/premium_provider.dart';
import '../../services/recurring_transaction_service.dart';
import 'premium_upgrade_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  PeriodFilter _filter = PeriodFilter.month;
  DateTimeRange? _customRange;
  bool _isSyncing = false;
  String? _selectedAccountId; // null means "All Accounts"

  // Multi-select state
  bool _isSelectionMode = false;
  Set<String> _selectedTransactionIds = {};

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _deleteBarController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Animation<double>? _deleteBarAnimation;

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

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _deleteBarController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _deleteBarAnimation = CurvedAnimation(
      parent: _deleteBarController,
      curve: Curves.easeOutCubic,
        );

    _fadeController.forward();
    _slideController.forward();

    // Initialize notifications
    _initializeNotifications();

    // Check for app updates
    _checkForUpdates();

    // Check and process recurring transactions
    _checkRecurringTransactions();
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
            debugPrint(
              'UpdateCheck: Update dialog already shown in this session',
            );
          }
        } else {
          debugPrint('UpdateCheck: App is up to date');
        }
      } else {
        debugPrint('UpdateCheck: Could not determine latest version');

        // FOR TESTING: Manual override for closed testing
        // Set this to the version that's live in closed testing
        // Remove this in production or make it configurable via remote config
        const testLatestVersion =
            '1.0.4'; // Change this to match your closed testing version

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
            debugPrint(
              'UpdateCheck: Update dialog already shown in this session (test mode)',
            );
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

  /// Check and process recurring transactions
  Future<void> _checkRecurringTransactions() async {
    if (!FeatureFlags.recurringTransactionsFeatureEnabled) return;

    try {
      // Wait a bit to ensure providers are initialized
      await Future.delayed(const Duration(seconds: 1));
      
      if (!mounted) return;

      final recurringProvider = context.read<RecurringTransactionProvider>();
      final transactionProvider = context.read<TransactionProvider>();

      // Initialize recurring provider if needed
      if (!recurringProvider.isInitialized) {
        await recurringProvider.initialize();
      }

      // Check and process recurring transactions
      final recurringService = RecurringTransactionService();
      await recurringService.checkAndProcessRecurringTransactions(
        recurringProvider,
        transactionProvider,
      );
    } catch (e) {
      debugPrint('Error checking recurring transactions: $e');
    }
  }


  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _deleteBarController.dispose();
    super.dispose();
  }

  Future<void> _deleteSelectedTransactions() async {
    if (_selectedTransactionIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Delete Transactions'),
        content: Text(
          'Are you sure you want to delete ${_selectedTransactionIds.length} transaction${_selectedTransactionIds.length > 1 ? 's' : ''}? This action cannot be undone.',
        ),
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

    if (confirmed == true) {
      final provider = context.read<TransactionProvider>();
      final count = _selectedTransactionIds.length;
      final idsToDelete = Set<String>.from(_selectedTransactionIds);
      
      for (final id in idsToDelete) {
        await provider.remove(id);
      }
      
      _deleteBarController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isSelectionMode = false;
            _selectedTransactionIds.clear();
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$count transaction${count > 1 ? 's' : ''} deleted',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
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

    Widget dashboardContent = AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: false,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          // Prevent elevation change on scroll
          surfaceTintColor: Colors.transparent,
          // Prevent tint color change
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          automaticallyImplyLeading: false,
          // Prevent back button
          title: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Text(
              'Dashboard',
              style: AppFonts.appBarTitle.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
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
            colors: [Color(0xFFF8F9F8), Color(0xFFE8F5E9), Color(0xFFF1F8E9)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16.0,0.0,16.0,16.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    children: [
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        _selectedAccountId == null
                                            ? 'Total Balance'
                                            : '${accountProvider.getAccount(_selectedAccountId!)?.name ?? "Account"} Balance',
                                        style: AppFonts.titleLarge.copyWith(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
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
                                          color:
                                              (_selectedAccountId == null
                                                      ? (income - expense)
                                                      : accountBalance) >=
                                                  0
                                              ? AppColors.accentGreen
                                              : AppColors.error,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 28,
                                          letterSpacing: -0.5,
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
                                          backgroundColor:
                                              AppColors.accentGreen,
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

                      // Recurring Transactions Widget
                      if (FeatureFlags.recurringTransactionsFeatureEnabled) ...[
                        Consumer<RecurringTransactionProvider>(
                          builder: (context, recurringProvider, _) {
                            final pendingRecurring = recurringProvider.getDueRecurringTransactions()
                                .where((recurring) => !recurring.autoApprove)
                                .toList();
                            final activeRecurring = recurringProvider.getActiveRecurringTransactions()
                                .take(3)
                                .toList();

                            if (pendingRecurring.isEmpty && activeRecurring.isEmpty) {
                              return const SizedBox(height: 16);
                            }
                            return const RecurringTransactionsWidget();
                          },
                        ),
                      ],
                      const SizedBox(height: 16),

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
                      // Recent Transactions Header with Search and Filter (only show if transactions exist)

                      if (allTransactions.isNotEmpty) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header and Search/Filter Section
                              Padding(
                                padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header Row with Title and Date Range
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    "Transactions",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  // Date Range Indicator
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentGreen.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 12,
                                          color: AppColors.accentGreen,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _getDateRangeText(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.accentGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Search and Filter Row
                              Row(
                                children: [
                                  // Search Bar
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          CustomPageRoute(
                                            child: const SearchScreen(),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        height: 44,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.backgroundScaffold,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: AppColors.border.withOpacity(
                                              0.6,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.search,
                                              size: 20,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Search transactions...',
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8), // Filter Button
                                  InkWell(
                                    onTap: () =>
                                        _showFilterBottomSheet(context),
                                    child: Container(
                                      height: 40,
                                      width: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.backgroundScaffold,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: AppColors.border.withOpacity(
                                            0.6,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.tune,
                                        size: 20,
                                        color: AppColors.accentGreen,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                              // Delete button when in selection mode
                              if (_isSelectionMode && _selectedTransactionIds.isNotEmpty && _deleteBarAnimation != null)
                                SizeTransition(
                                  sizeFactor: _deleteBarAnimation!,
                                  child: FadeTransition(
                                    opacity: _deleteBarAnimation!,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, -1),
                                        end: Offset.zero,
                                      ).animate(_deleteBarAnimation!),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          border: Border(
                                            bottom: BorderSide(
                                              color: AppColors.border.withOpacity(0.2),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${_selectedTransactionIds.length} selected',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                TextButton.icon(
                                                  onPressed: () {
                                                    _deleteBarController.reverse().then((_) {
                                                      if (mounted) {
                                                        setState(() {
                                                          _isSelectionMode = false;
                                                          _selectedTransactionIds.clear();
                                                        });
                                                      }
                                                    });
                                                  },
                                                  icon: const Icon(Icons.close, size: 18),
                                                  label: const Text('Cancel'),
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: AppColors.textSecondary,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                ElevatedButton.icon(
                                                  onPressed: () => _deleteSelectedTransactions(),
                                                  icon: const Icon(Icons.delete, size: 18),
                                                  label: const Text('Delete'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8,
                                                    ),
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
                              // Transaction List inside the same white container
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: items.isEmpty
                                    ? _buildEmptyState(allTransactions.isEmpty)
                                    : _buildGroupedTransactionList(items, currencySymbol),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Show empty state when no transactions exist
                      items.isEmpty
                          ? _buildEmptyState(allTransactions.isEmpty)
                          : _buildGroupedTransactionList(items, currencySymbol),
                      ],

                      const SizedBox(height: 80),
                      // Extra padding at bottom for FAB
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
          : AnimatedButton(
              onPressed: () => Navigator.of(context).pushNamed('/edit'),
              child: FloatingActionButton(
                onPressed: () => Navigator.of(context).pushNamed('/edit'),
                backgroundColor: AppColors.accentGreen,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
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
                    // Animated Icon with Pulse
                    _PulsingIcon(
                      child: Container(
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
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'No Transactions Yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Start tracking your expenses and income\nto see your financial overview here',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Call to Action Button
                    AnimatedButton(
                      onPressed: () => Navigator.of(context).pushNamed('/edit'),
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pushNamed('/edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(
                        Icons.add_circle_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        'Add Your First Transaction',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    )],
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
              padding: const EdgeInsets.fromLTRB(24.0, 60.0, 24.0, 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Simple Icon
                  Container(
                    width: 70,
                    height: 70,
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
                      Icons.search_off,
                      size: 35,
                      color: AppColors.accentGreen.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    'No Transactions in This Period',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Subtitle
                  Text(
                    'Try selecting a different time period\nto view your transactions',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
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
      shrinkWrap: true,
      // Allow ListView to size itself based on content
      physics: const NeverScrollableScrollPhysics(),
      // Disable scrolling - parent handles it
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final t = items[index];

        final isSelected = _selectedTransactionIds.contains(t.id);

        return StaggeredListAnimation(
          index: index,
          child: _isSelectionMode
              ? Card(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                  elevation: 0,
                  color: isSelected
                      ? AppColors.accentGreen.withOpacity(0.1)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.accentGreen
                          : AppColors.border.withOpacity(0.4),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedTransactionIds.remove(t.id);
                          if (_selectedTransactionIds.isEmpty) {
                            _deleteBarController.reverse().then((_) {
                              if (mounted) {
                                setState(() {
                                  _isSelectionMode = false;
                                });
                              }
                            });
                          }
                        } else {
                          _selectedTransactionIds.add(t.id);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          // Checkbox instead of icon
                          Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.accentGreen
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.accentGreen
                                    : AppColors.border,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 24,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.category,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  t.title.isEmpty ? 'Not Specified' : t.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
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
                                  fontWeight: FontWeight.w700,
                                  color: t.type == TransactionType.income
                                      ? AppColors.accentGreen
                                      : AppColors.error,
                                ),
                              ),
                              Text(
                                DateFormat.yMMMd().format(t.date),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Dismissible(
            key: Key(t.id),
            direction: DismissDirection.endToStart,
            background: AnimatedContainer(
              duration: AnimationUtils.fastDuration,
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
                  Icon(Icons.delete, color: Colors.white, size: 24),
                ],
              ),
            ),
            dismissThresholds: const {
              DismissDirection.endToStart: 0.4,
            },
            resizeDuration: AnimationUtils.normalDuration,
            movementDuration: AnimationUtils.normalDuration,
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                context: context,
                builder: (context) => FadeTransition(
                  opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(
                      parent: ModalRoute.of(context)!.animation!,
                      curve: AnimationUtils.smoothCurve,
                    ),
                  ),
                  child: AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text('Delete Transaction'),
                    content: const Text(
                      'Are you sure you want to delete this transaction? This action cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      AnimatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Delete'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            onDismissed: (direction) async {
              final provider = context.read<TransactionProvider>();
              await provider.remove(t.id);
            },
            child: Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: AppColors.border.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: GestureDetector(
              onLongPress: () {
                setState(() {
                  _isSelectionMode = true;
                  _selectedTransactionIds.add(t.id);
                });
                _deleteBarController.forward();
              },
            child: _AnimatedCard(
              onTap: () {
                      if (_isSelectionMode) {
                    setState(() {
                      if (_selectedTransactionIds.contains(t.id)) {
                        _selectedTransactionIds.remove(t.id);
                        if (_selectedTransactionIds.isEmpty) {
                          _deleteBarController.reverse().then((_) {
                            if (mounted) {
                              setState(() {
                                _isSelectionMode = false;
                              });
                            }
                          });
                        }
                      } else {
                        _selectedTransactionIds.add(t.id);
                      }
                    });
                  } else {
                Navigator.push(
                  context,
                  CustomPageRoute(
                    child: EditTransactionScreen(existing: t),
                  ),
                );
                  }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    // Icon
                    Builder(
                      builder: (context) {
                        final firestoreCategory = _getCategoryFromFirestore(
                          t.category,
                          t.type,
                        );
                        final categoryColor =
                            firestoreCategory?.color ??
                            _getCategoryFromString(t.category).color;
                        final iconPath =
                            firestoreCategory?.iconPath ??
                            _getIconPathFromCategoryName(t.category);

                        return Hero(
                          tag: 'transaction_icon_${t.id}',
                          child: Container(
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
                                width: 24,
                                height: 24,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),

                    // Title, Category + Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.category,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            t.title.isEmpty ? 'Not Specified' : t.title,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
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
                            fontWeight: FontWeight.w700,
                            color: t.type == TransactionType.income
                                ? AppColors.accentGreen
                                : AppColors.error,
                          ),
                        ),

                        Text(
                          DateFormat.yMMMd().format(t.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        )));
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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: backgroundColor.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          // Icon with background
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: backgroundColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: backgroundColor, size: 20),
          ),
          const SizedBox(width: 12),

          // Label + Amount
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    CurrencyFormatter.format(
                      amount: amount,
                      symbol: currency,
                      decimalDigits: 1,
                    ),
                    style: TextStyle(
                      color: backgroundColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getDateRangeText() {
    final range = _currentRange();
    return _getDateRangeTextForRange(range, _filter);
  }

  String _getDateRangeTextForRange(DateTimeRange range, PeriodFilter filter) {
    final start = range.start;
    final end = range.end;

    switch (filter) {
      case PeriodFilter.day:
        return DateFormat('MMM d, yyyy').format(start);
      case PeriodFilter.week:
        if (start.year == end.year && start.month == end.month) {
          return '${DateFormat('MMM d').format(start)} - ${DateFormat('d, yyyy').format(end)}';
        } else if (start.year == end.year) {
          return '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}';
        } else {
          return '${DateFormat('MMM d, yyyy').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}';
        }
      case PeriodFilter.month:
        return DateFormat('MMM d').format(start) +
            ' - ' +
            DateFormat('d, yyyy').format(end);
      case PeriodFilter.year:
        return DateFormat('MMM d, yyyy').format(start) +
            ' - ' +
            DateFormat('MMM d, yyyy').format(end);
      case PeriodFilter.custom:
        if (start.year == end.year &&
            start.month == end.month &&
            start.day == end.day) {
          return DateFormat('MMM d, yyyy').format(start);
        } else if (start.year == end.year && start.month == end.month) {
          return '${DateFormat('MMM d').format(start)} - ${DateFormat('d, yyyy').format(end)}';
        } else if (start.year == end.year) {
          return '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}';
        } else {
          return '${DateFormat('MMM d, yyyy').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}';
        }
    }
  }

  void _showFilterBottomSheet(BuildContext context) {
    final accountProvider = context.read<AccountProvider>();
    final accounts = accountProvider.accounts;

    PeriodFilter tempFilter = _filter;
    String? tempAccountId = _selectedAccountId;
    DateTimeRange? tempCustomRange = _customRange;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.accentGreen.withOpacity(0.15),
                                  AppColors.accentGreen.withOpacity(0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.tune_rounded,
                              color: AppColors.accentGreen,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Filter Transactions',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Customize your view',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.backgroundScaffold,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(
                                Icons.close_rounded,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Time Period Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundScaffold,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.border.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.calendar_today_rounded,
                                    size: 16,
                                    color: AppColors.accentGreen,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Time Period',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            StatefulBuilder(
                              builder: (context, setState) {
                                // Calculate date range for current selection
                                DateTimeRange getTempRange() {
                                  final now = DateTime.now();
                                  switch (tempFilter) {
                                    case PeriodFilter.day:
                                      return DateTimeRange(
                                        start: _startOfDay(now),
                                        end: _endOfDay(now),
                                      );
                                    case PeriodFilter.week:
                                      final start = now.subtract(
                                        Duration(days: now.weekday - 1),
                                      );
                                      final end = start.add(const Duration(days: 6));
                                      return DateTimeRange(
                                        start: _startOfDay(start),
                                        end: _endOfDay(end),
                                      );
                                    case PeriodFilter.month:
                                      final start = DateTime(now.year, now.month, 1);
                                      final end = DateTime(now.year, now.month + 1, 0);
                                      return DateTimeRange(
                                        start: _startOfDay(start),
                                        end: _endOfDay(end),
                                      );
                                    case PeriodFilter.year:
                                      final start = DateTime(now.year, 1, 1);
                                      final end = DateTime(now.year, 12, 31);
                                      return DateTimeRange(
                                        start: _startOfDay(start),
                                        end: _endOfDay(end),
                                      );
                                    case PeriodFilter.custom:
                                      return tempCustomRange ??
                                          DateTimeRange(
                                            start: _startOfDay(now),
                                            end: _endOfDay(now),
                                          );
                                  }
                                }

                                final previewRange = getTempRange();

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (final period in [
                                          PeriodFilter.day,
                                          PeriodFilter.week,
                                          PeriodFilter.month,
                                          PeriodFilter.year,
                                          PeriodFilter.custom,
                                        ])
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () async {
                                                if (period == PeriodFilter.custom) {
                                                  final picked = await showDateRangePicker(
                                                    context: context,
                                                    firstDate: DateTime(2015),
                                                    lastDate: DateTime(2100),
                                                    initialDateRange:
                                                        tempCustomRange ?? _currentRange(),
                                                  );

                                                  if (picked != null) {
                                                    setState(() {
                                                      tempFilter = period;
                                                      tempCustomRange = DateTimeRange(
                                                        start: _startOfDay(picked.start),
                                                        end: _endOfDay(picked.end),
                                                      );
                                                    });
                                                  }
                                                } else {
                                                  setState(() {
                                                    tempFilter = period;
                                                    tempCustomRange = null;
                                                  });
                                                }
                                              },
                                              borderRadius: BorderRadius.circular(14),
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 200),
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 20,
                                                  vertical: 12,
                                                ),
                                                decoration: BoxDecoration(
                                                  gradient: tempFilter == period
                                                      ? LinearGradient(
                                                          colors: [
                                                            AppColors.accentGreen,
                                                            AppColors.accentGreen.withOpacity(0.8),
                                                          ],
                                                        )
                                                      : null,
                                                  color: tempFilter == period
                                                      ? null
                                                      : Colors.white,
                                                  borderRadius: BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: tempFilter == period
                                                        ? AppColors.accentGreen
                                                        : AppColors.border.withOpacity(0.3),
                                                    width: tempFilter == period ? 0 : 1.5,
                                                  ),
                                                  boxShadow: tempFilter == period
                                                      ? [
                                                          BoxShadow(
                                                            color: AppColors.accentGreen.withOpacity(0.3),
                                                            blurRadius: 8,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ]
                                                      : null,
                                                ),
                                                child: Text(
                                                  _labelForFilter(period),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: tempFilter == period
                                                        ? Colors.white
                                                        : AppColors.textPrimary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // Date Preview
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.accentGreen.withOpacity(0.12),
                                            AppColors.accentGreen.withOpacity(0.06),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: AppColors.accentGreen.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: AppColors.accentGreen.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.date_range_rounded,
                                              size: 16,
                                              color: AppColors.accentGreen,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Selected Period',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _getDateRangeTextForRange(
                                                    previewRange,
                                                    tempFilter,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.accentGreen,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (accounts.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundScaffold,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.border.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentGreen.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.account_balance_wallet_rounded,
                                      size: 16,
                                      color: AppColors.accentGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Account',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              StatefulBuilder(
                                builder: (context, setState) => Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    // All Accounts option
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            tempAccountId = null;
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(14),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: tempAccountId == null
                                                ? LinearGradient(
                                                    colors: [
                                                      AppColors.accentGreen,
                                                      AppColors.accentGreen.withOpacity(0.8),
                                                    ],
                                                  )
                                                : null,
                                            color: tempAccountId == null
                                                ? null
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: tempAccountId == null
                                                  ? AppColors.accentGreen
                                                  : AppColors.border.withOpacity(0.3),
                                              width: tempAccountId == null ? 0 : 1.5,
                                            ),
                                            boxShadow: tempAccountId == null
                                                ? [
                                                    BoxShadow(
                                                      color: AppColors.accentGreen.withOpacity(0.3),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: Text(
                                            'All Accounts',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: tempAccountId == null
                                                  ? Colors.white
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Individual accounts
                                    for (final account in accounts)
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              tempAccountId = account.id;
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(14),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: tempAccountId == account.id
                                                  ? LinearGradient(
                                                      colors: [
                                                        AppColors.accentGreen,
                                                        AppColors.accentGreen.withOpacity(0.8),
                                                      ],
                                                    )
                                                  : null,
                                              color: tempAccountId == account.id
                                                  ? null
                                                  : Colors.white,
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: tempAccountId == account.id
                                                    ? AppColors.accentGreen
                                                    : AppColors.border.withOpacity(0.3),
                                                width: tempAccountId == account.id ? 0 : 1.5,
                                              ),
                                              boxShadow: tempAccountId == account.id
                                                  ? [
                                                      BoxShadow(
                                                        color: AppColors.accentGreen.withOpacity(0.3),
                                                        blurRadius: 8,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Text(
                                              account.name,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: tempAccountId == account.id
                                                    ? Colors.white
                                                    : AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      const SizedBox(height: 8),

                      // Apply Button
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accentGreen,
                              AppColors.accentGreen.withOpacity(0.9),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentGreen.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _filter = tempFilter;
                                _selectedAccountId = tempAccountId;
                                _customRange = tempCustomRange;
                              });
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Apply Filters',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Reset Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _filter = PeriodFilter.month;
                              _selectedAccountId = null;
                              _customRange = null;
                            });
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.backgroundScaffold,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.border.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.refresh_rounded,
                                  color: AppColors.textSecondary,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Reset to Default',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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
  return CategoryIconService.getIconPath(categoryName);
}

/// Animated card with tap feedback
class _AnimatedCard extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  final BorderRadius borderRadius;

  const _AnimatedCard({
    required this.onTap,
    required this.child,
    required this.borderRadius,
  });

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: AnimationUtils.fastDuration,
        curve: AnimationUtils.defaultCurve,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: widget.borderRadius,
          splashColor: AppColors.accentGreen.withOpacity(0.1),
          highlightColor: AppColors.accentGreen.withOpacity(0.05),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Pulsing icon widget for empty states
class _PulsingIcon extends StatefulWidget {
  final Widget child;

  const _PulsingIcon({required this.child});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: widget.child,
        );
      },
    );
  }
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
      return 'Custom Period';
  }
}
