import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/subscription.dart';
import '../../providers/premium_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_fonts.dart';
import 'premium_upgrade_screen.dart';

class SubscriptionDetailsScreen extends StatefulWidget {
  const SubscriptionDetailsScreen({super.key});

  @override
  State<SubscriptionDetailsScreen> createState() =>
      _SubscriptionDetailsScreenState();
}

class _SubscriptionDetailsScreenState extends State<SubscriptionDetailsScreen> {
  Map<String, dynamic>? _pendingUpdate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPendingUpdate();
    });
  }

  Future<void> _loadPendingUpdate() async {
    if (!mounted) return;
    try {
      final premiumProvider = context.read<PremiumProvider>();
      final pendingUpdate = await premiumProvider.fetchPendingUpdate();
      if (mounted) {
        setState(() => _pendingUpdate = pendingUpdate);
      }
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundScaffold,
      appBar: AppBar(
        title: const Text('Subscription'),
        backgroundColor: AppColors.backgroundScaffold,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              context.read<PremiumProvider>().refreshPremiumStatus();
              _loadPendingUpdate();
            },
          ),
        ],
      ),
      body: Consumer<PremiumProvider>(
        builder: (context, premiumProvider, _) {
          if (!premiumProvider.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }

          final subscription = premiumProvider.currentSubscription;

          if (subscription == null || !premiumProvider.isPremium) {
            return _buildNoSubscriptionView(context);
          }

          return _buildSubscriptionDetailsView(
            context,
            subscription,
            premiumProvider,
          );
        },
      ),
    );
  }

  Widget _buildNoSubscriptionView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 24),
            Text(
              'No Active Subscription',
              style: AppFonts.headlineLarge.copyWith(
                fontWeight: AppFonts.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Upgrade to Premium to access subscription details and invoices.',
              style: AppFonts.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PremiumUpgradeScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text('Upgrade to Premium'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionDetailsView(
    BuildContext context,
    Subscription subscription,
    PremiumProvider premiumProvider,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        await premiumProvider.refreshPremiumStatus();
        await _loadPendingUpdate();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pending Update Alert
            if (_pendingUpdate != null) ...[
              _buildPendingUpdateCard(context, premiumProvider),
              const SizedBox(height: 16),
            ],

            // Combined Subscription Status & Details Card
            _buildSubscriptionCard(subscription), const SizedBox(height: 16),

            // Subscription Actions
            _buildActionsCard(context, subscription, premiumProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingUpdateCard(
    BuildContext context,
    PremiumProvider premiumProvider,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pending Update',
                  style: AppFonts.bodyMedium.copyWith(
                    fontWeight: AppFonts.semiBold,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'You have a scheduled subscription update',
                  style: AppFonts.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              final cancel = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cancel Update'),
                  content: const Text(
                    'Are you sure you want to cancel the pending subscription update?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('No'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Yes, Cancel'),
                    ),
                  ],
                ),
              );

              if (cancel == true && context.mounted) {
                final success = await premiumProvider.cancelPendingUpdate();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Update cancelled successfully'
                            : 'Failed to cancel update',
                      ),
                      backgroundColor: success
                          ? AppColors.accentGreen
                          : AppColors.error,
                    ),
                  );
                  if (success) {
                    await _loadPendingUpdate();
                  }
                }
              }
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(Subscription subscription) {
    final isTrial = subscription.isTrialActive;
    final isPaused = subscription.isPaused;
    final status = subscription.status.toLowerCase();

    // Determine status color and text
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'created':
        statusColor = Colors.grey;
        statusText = 'Created';
        statusIcon = Icons.schedule_rounded;
        break;
      case 'authenticated':
        statusColor = isTrial ? Colors.blue : AppColors.accentGreen;
        statusText = isTrial ? 'Free Trial' : 'Authenticated';
        statusIcon = isTrial
            ? Icons.celebration_rounded
            : Icons.check_circle_rounded;
        break;
      case 'active':
        statusColor = AppColors.accentGreen;
        statusText = 'Active';
        statusIcon = Icons.star_rounded;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'Pending Payment';
        statusIcon = Icons.pending_rounded;
        break;
      case 'halted':
        statusColor = Colors.red;
        statusText = 'Halted';
        statusIcon = Icons.error_rounded;
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusText = 'Cancelled';
        statusIcon = Icons.cancel_rounded;
        break;
      case 'paused':
        statusColor = Colors.orange;
        statusText = 'Paused';
        statusIcon = Icons.pause_circle_outline_rounded;
        break;
      case 'expired':
        statusColor = Colors.red;
        statusText = 'Expired';
        statusIcon = Icons.access_time_rounded;
        break;
      case 'completed':
        statusColor = Colors.grey;
        statusText = 'Completed';
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      default:
        statusColor = isPaused
            ? Colors.orange
            : (isTrial ? Colors.blue : AppColors.accentGreen);
        statusText = isPaused ? 'Paused' : (isTrial ? 'Free Trial' : 'Active');
        statusIcon = isPaused
            ? Icons.pause_circle_outline_rounded
            : (isTrial ? Icons.celebration_rounded : Icons.star_rounded);
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withOpacity(0.08),
            statusColor.withOpacity(0.03),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statusColor.withOpacity(0.2), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header with Icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: AppFonts.titleLarge.copyWith(
                          fontWeight: AppFonts.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subscription.subscriptionType.toUpperCase(),
                        style: AppFonts.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    statusText.toUpperCase(),
                    style: AppFonts.labelSmall.copyWith(
                      color: statusColor,
                      fontWeight: AppFonts.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),

            if (isPaused && subscription.resumeAt != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.info_outline_rounded,
                        color: Colors.orange.shade700,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Will resume on ${DateFormat('MMM dd, yyyy').format(subscription.resumeAt!)}',
                        style: AppFonts.bodySmall.copyWith(
                          color: Colors.orange.shade700,
                          fontWeight: AppFonts.medium,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.border.withOpacity(0),
                    AppColors.border,
                    AppColors.border.withOpacity(0),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Details Section
            Text(
              'Details',
              style: AppFonts.titleMedium.copyWith(
                fontWeight: AppFonts.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            _buildDetailRow(
              'Plan',
              subscription.subscriptionType.toUpperCase(),
              Icons.credit_card_rounded,
            ),
            const SizedBox(height: 18),
            _buildDetailRow(
              'Start Date',
              DateFormat('MMM dd, yyyy').format(subscription.startDate),
              Icons.calendar_today_rounded,
            ),
            if (subscription.trialEndDate != null) ...[
              const SizedBox(height: 18),
              _buildDetailRow(
                'Trial Ends',
                DateFormat('MMM dd, yyyy').format(subscription.trialEndDate!),
                Icons.celebration_rounded,
              ),
            ],
            if (subscription.endDate != null) ...[
              const SizedBox(height: 18),
              _buildDetailRow(
                'Renews On',
                DateFormat('MMM dd, yyyy').format(subscription.endDate!),
                Icons.autorenew_rounded,
              ),
            ],
            if (subscription.currentPeriod != null &&
                subscription.totalCount != null) ...[
              const SizedBox(height: 18),
              _buildDetailRow(
                'Billing Period',
                '${subscription.currentPeriod} / ${subscription.totalCount}',
                Icons.receipt_long_rounded,
              ),
            ],
            const SizedBox(height: 18),
            _buildDetailRow(
              'Auto-Renewal',
              subscription.autoRenewal ? 'Enabled' : 'Disabled',
              Icons.settings_rounded,
              valueColor: subscription.autoRenewal
                  ? AppColors.accentGreen
                  : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.accentGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.accentGreen),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: AppFonts.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (valueColor ?? AppColors.textPrimary).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: AppFonts.bodyMedium.copyWith(
                color: valueColor ?? AppColors.textPrimary,
                fontWeight: AppFonts.bold,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionsCard(
    BuildContext context,
    Subscription subscription,
    PremiumProvider premiumProvider,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.settings_rounded,
                  color: AppColors.accentGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Manage Subscription',
                style: AppFonts.titleMedium.copyWith(
                  fontWeight: AppFonts.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (subscription.isPaused) ...[
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accentGreen,
                      AppColors.accentGreen.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentGreen.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final success = await premiumProvider.resumeSubscription();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Subscription resumed successfully'
                                : 'Failed to resume subscription',
                          ),
                          backgroundColor: success
                              ? AppColors.accentGreen
                              : AppColors.error,
                        ),
                      );
                      if (success) {
                        await premiumProvider.refreshPremiumStatus();
                      }
                    }
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text(
                    'Resume Subscription',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ] else if (!subscription.isPaused && subscription.autoRenewal) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final pause = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Pause Subscription'),
                      content: const Text(
                        'Pausing will temporarily stop your subscription. You can resume it anytime.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Pause'),
                        ),
                      ],
                    ),
                  );

                  if (pause == true && context.mounted) {
                    final success = await premiumProvider.pauseSubscription();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Subscription paused successfully'
                                : 'Failed to pause subscription',
                          ),
                          backgroundColor: success
                              ? AppColors.accentGreen
                              : AppColors.error,
                        ),
                      );
                      if (success) {
                        await premiumProvider.refreshPremiumStatus();
                      }
                    }
                  }
                },
                icon: const Icon(Icons.pause_rounded, size: 20),
                label: const Text(
                  'Pause Subscription',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(
                    color: Colors.orange.withOpacity(0.3),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (subscription.autoRenewal) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final cancel = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Cancel Subscription'),
                      content: const Text(
                        'Cancelling will stop auto-renewal. You\'ll retain access until the end of your current period.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('No'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Yes, Cancel'),
                        ),
                      ],
                    ),
                  );

                  if (cancel == true && context.mounted) {
                    final cancelAtCycleEnd = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Cancel Now or at Cycle End?'),
                        content: const Text(
                          'Do you want to cancel immediately or at the end of the current billing cycle?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('At Cycle End'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Cancel Now'),
                          ),
                        ],
                      ),
                    );

                    if (mounted) {
                      final success = await premiumProvider.cancelSubscription(
                        cancelAtCycleEnd: cancelAtCycleEnd ?? true,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Subscription cancelled successfully'
                                  : 'Failed to cancel subscription',
                            ),
                            backgroundColor: success
                                ? AppColors.accentGreen
                                : AppColors.error,
                          ),
                        );
                        if (success) {
                          await premiumProvider.refreshPremiumStatus();
                        }
                      }
                    }
                  }
                },
                icon: const Icon(Icons.cancel_outlined, size: 20),
                label: const Text(
                  'Cancel Subscription',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Colors.red.withOpacity(0.3),
                    width: 1.5,
                  ),
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
