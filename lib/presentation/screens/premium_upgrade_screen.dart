import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../providers/premium_provider.dart';
import '../../services/premium_service.dart';
import '../../services/razorpay_subscription_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_fonts.dart';
import '../../common/premium_constants.dart';
import 'package:intl/intl.dart';
import 'webview_screen.dart';

class PremiumUpgradeScreen extends StatefulWidget {
  const PremiumUpgradeScreen({super.key});

  @override
  State<PremiumUpgradeScreen> createState() => _PremiumUpgradeScreenState();
}

class _PremiumUpgradeScreenState extends State<PremiumUpgradeScreen> {
  bool _isLoading = false;
  bool _isPurchasing = false;
  String? _selectedPlanId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPlans();
    });
  }

  Future<void> _loadPlans() async {
    final premiumProvider = context.read<PremiumProvider>();
    if (!premiumProvider.isInitialized) {
      await premiumProvider.initialize();
    }
    setState(() {});
  }

  Future<void> _handlePurchase(Map<String, dynamic> plan) async {
    if (_isPurchasing) return;

    setState(() {
      _isPurchasing = true;
      _selectedPlanId = plan['id'] as String;
    });

    try {
      final premiumProvider = context.read<PremiumProvider>();
      final planId = plan['id'] as String;
      
      // Check if this is the test plan - if so, disable trial
      final isTestPlan = planId == PremiumConstants.testPlanId;
      final shouldStartTrial = !isTestPlan; // Test plan has no trial
      
      // Create subscription order
      final orderData = await premiumProvider.createSubscriptionOrder(
        planId: planId,
        subscriptionType: plan['type'] as String,
        amount: plan['amount'] as int,
        startTrial: shouldStartTrial,
      );

      if (orderData != null && mounted) {
        debugPrint('🔵 orderData ${orderData}');

        final subscriptionLink = orderData['subscriptionLink'] as String?;
        final subscriptionId = orderData['subscriptionId'] as String?;
        final orderId = orderData['orderId'] as String?;
        final planId = orderData['planId'] as String?;
        final subscriptionType = orderData['subscriptionType'] as String?;
        final startTrial = orderData['startTrial'] as bool? ?? true;
        
        // If we have a subscription link, open it in WebView
        if (subscriptionLink != null && subscriptionId != null) {
          debugPrint('🔗 Opening subscription link in WebView: $subscriptionLink');
          debugPrint('📝 Subscription ID: $subscriptionId');
          
          if (mounted) {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WebViewScreen(
                  url: subscriptionLink,
                  title: 'Complete Payment',
                ),
              ),
            );
            
            // When user returns from WebView, check subscription status
            if (mounted) {
              debugPrint('🔄 Checking subscription status after payment...');
              
              // Fetch subscription from Razorpay to check payment status
              try {
                final subscriptionService = RazorpaySubscriptionService.instance;
                final razorpaySubscription = await subscriptionService.fetchSubscriptionById(subscriptionId);
                
                debugPrint('📊 Subscription status from Razorpay: ${razorpaySubscription['status']}');
                
                // If subscription is active or authenticated, update Firestore
                final status = razorpaySubscription['status'] as String?;
                if (status == 'active' || status == 'authenticated') {
                  debugPrint('✅ Payment successful! Updating subscription...');
                  
                  // Handle payment success to update Firestore
                  await PremiumService.instance.handlePaymentSuccess(
                    paymentId: razorpaySubscription['id'] as String? ?? subscriptionId,
                    orderId: subscriptionId,
                    subscriptionType: subscriptionType ?? plan['type'] as String,
                    planId: planId ?? plan['id'] as String,
                    startTrial: startTrial,
                    razorpaySubscriptionId: subscriptionId,
                  );
                }
              } catch (e) {
                debugPrint('❌ Error checking subscription status: $e');
              }
              
              // Refresh premium status
              await premiumProvider.refreshPremiumStatus();
              
              // Show success message if payment was completed
              if (premiumProvider.isPremium) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payment successful! Your subscription is now active.'),
                      backgroundColor: AppColors.accentGreen,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              } else {
                // Show message to wait a bit if status hasn't updated yet
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payment processing... Please wait a moment and refresh.'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              }
            }
          }
        } else if (orderId != null) {
          // Fallback to old payment gateway flow if no subscription link
          // Open Razorpay payment gateway FIRST
          await premiumProvider.openPaymentGateway(
            orderId: orderId,
            amount: plan['amount'] as int,
            subscriptionType: plan['type'] as String,
            planId: planId ?? plan['id'] as String,
            startTrial: startTrial,
            onSuccess: () {
              // Payment successful - refresh status to show premium active view
              if (mounted) {
                premiumProvider.refreshPremiumStatus();
                // The Consumer will automatically rebuild to show premium active view
              }
            },
            onFailure: (error) {
              if (mounted) {
                // Show error dialog instead of snackbar
                _showPaymentErrorDialog(context, error);
              }
            },
          );
        } else {
          // If order creation fails, show error
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to create order. Please try again.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create subscription. Please try again.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        // Show the actual error message
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage.isNotEmpty 
                  ? errorMessage 
                  : 'Failed to create subscription. Please check your internet connection and try again.',
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _selectedPlanId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundScaffold,
      appBar: AppBar(
        title: const Text('Upgrade to Premium'),
        backgroundColor: AppColors.backgroundScaffold,
      ),
      body: Consumer<PremiumProvider>(
        builder: (context, premiumProvider, _) {
          if (premiumProvider.isPremium) {
            return _buildPremiumActiveView(premiumProvider);
          }

          final plans = premiumProvider.subscriptionPlans;
          if (plans.isEmpty) {
            return _buildLoadingView();
          }

          return _buildUpgradeView(plans, premiumProvider);
        },
      ),
    );
  }

  Widget _buildPremiumActiveView(PremiumProvider premiumProvider) {
    final subscription = premiumProvider.currentSubscription;
    final isTrial = subscription?.isTrialActive ?? false;
    final trialEndDate = subscription?.trialEndDate;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accentGreen.withOpacity(0.1),
            AppColors.backgroundScaffold,
            AppColors.accentGreen.withOpacity(0.05),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Animated Premium Badge
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.accentGreen,
                        AppColors.accentGreen.withOpacity(0.7),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentGreen.withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 70,
                        color: Colors.white,
                      ),
                      if (isTrial)
                        Positioned(
                          bottom: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.celebration_rounded,
                                  size: 14,
                                  color: AppColors.accentGreen,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'TRIAL',
                                  style: AppFonts.labelSmall.copyWith(
                                    color: AppColors.accentGreen,
                                    fontWeight: AppFonts.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // Title
                Text(
                  isTrial ? '🎉 Free Trial Activated!' : '✨ Premium Active',
                  style: AppFonts.displayMedium.copyWith(
                    fontWeight: AppFonts.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Subtitle
                if (isTrial && trialEndDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accentGreen.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Your free trial ends on',
                          style: AppFonts.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMMM dd, yyyy').format(trialEndDate),
                          style: AppFonts.titleLarge.copyWith(
                            fontWeight: AppFonts.bold,
                            color: AppColors.accentGreen,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    'You have access to all premium features!',
                    style: AppFonts.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 32),
                // Features Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What you get:',
                        style: AppFonts.titleLarge.copyWith(
                          fontWeight: AppFonts.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureRow(Icons.flag_rounded, 'Unlimited Goals'),
                      const SizedBox(height: 12),
                      _buildFeatureRow(Icons.account_balance_wallet_rounded, '2 Premium Accounts'),
                      const SizedBox(height: 12),
                      _buildFeatureRow(Icons.category_rounded, '50 Categories'),
                      const SizedBox(height: 12),
                      _buildFeatureRow(Icons.insights_rounded, 'Advanced Analytics'),
                    ],
                  ),
                ),
                if (subscription != null && subscription.autoRenewal) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accentGreen.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.autorenew_rounded,
                          color: AppColors.accentGreen,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auto-renewal enabled',
                                style: AppFonts.bodyMedium.copyWith(
                                  color: AppColors.accentGreen,
                                  fontWeight: AppFonts.semiBold,
                                ),
                              ),
                              Text(
                                'Your subscription will renew automatically',
                                style: AppFonts.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                // Done Button
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentGreen,
                        AppColors.accentGreen.withOpacity(0.8),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentGreen.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Get Started',
                      style: AppFonts.buttonText.copyWith(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: AppFonts.bold,
                      ),
                    ),
                  ),
                ),
            if (subscription != null && subscription.autoRenewal)
              TextButton(
                onPressed: () async {
                  final cancel = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Cancel Subscription'),
                      content: const Text(
                        'Are you sure you want to cancel your subscription? You will lose access to premium features after the current period ends.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('No'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Yes, Cancel'),
                        ),
                      ],
                    ),
                  );
                  
                  if (cancel == true) {
                    final success = await premiumProvider.cancelSubscription();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Subscription cancelled successfully'
                                : 'Failed to cancel subscription',
                          ),
                          backgroundColor:
                              success ? AppColors.accentGreen : AppColors.error,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Cancel Subscription'),
              ),
          ],
        ),
      ),
    )));
  }

  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildUpgradeView(
      List<Map<String, dynamic>> plans, PremiumProvider premiumProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _buildHeader(),
          const SizedBox(height: 32),

          // Free trial banner
          _buildFreeTrialBanner(),
          const SizedBox(height: 24),

          // Features list
          _buildFeaturesList(),
          const SizedBox(height: 32),

          // Subscription packages
          ...plans.map((plan) => _buildPlanCard(plan)),

          const SizedBox(height: 24),

          // Terms and privacy
          _buildTermsText(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.accentGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.star,
            size: 64,
            color: AppColors.accentGreen,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Unlock Premium Features',
          style: AppFonts.headlineLarge.copyWith(
            fontWeight: AppFonts.bold,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Start your 7-day free trial today',
          style: AppFonts.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFreeTrialBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.celebration,
            color: AppColors.accentGreen,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${PremiumConstants.FREE_TRIAL_DAYS}-Day Free Trial',
                  style: AppFonts.titleLarge.copyWith(
                    fontWeight: AppFonts.bold,
                    color: AppColors.accentGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Try all premium features free for ${PremiumConstants.FREE_TRIAL_DAYS} days. Cancel anytime.',
                  style: AppFonts.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      'Unlimited accounts',
      'Unlimited recurring transactions',
      'Advanced charts and analytics',
      'Goals and savings tracking',
      'Priority support',
      'Ad-free experience',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Premium Features',
            style: AppFonts.titleLarge.copyWith(
              fontWeight: AppFonts.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppColors.accentGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        feature,
                        style: AppFonts.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final isSelected = _selectedPlanId == plan['id'];
    final isPurchasing = _isPurchasing && isSelected;
    final isBestValue = plan['isBestValue'] as bool? ?? false;
    final trialDays = plan['trialDays'] as int? ?? PremiumConstants.FREE_TRIAL_DAYS;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.accentGreen : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          if (isBestValue)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: Text(
                  'BEST VALUE',
                  style: AppFonts.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: AppFonts.bold,
                  ),
                ),
              ),
            ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isPurchasing ? null : () => _handlePurchase(plan),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan['name'] as String,
                      style: AppFonts.titleLarge.copyWith(
                        fontWeight: AppFonts.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      plan['amountDisplay'] as String,
                      style: AppFonts.headlineMedium.copyWith(
                        fontWeight: AppFonts.bold,
                        color: AppColors.accentGreen,
                      ),
                    ),
                    Text(
                      plan['period'] as String,
                      style: AppFonts.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Free trial info
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.celebration,
                            size: 16,
                            color: AppColors.accentGreen,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$trialDays-day free trial, then ${plan['amountDisplay']} ${plan['period']}',
                              style: AppFonts.bodySmall.copyWith(
                                color: AppColors.accentGreen,
                                fontWeight: AppFonts.medium,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Auto-renewal info
                    Row(
                      children: [
                        Icon(
                          Icons.autorenew,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            plan['type'] == 'lifetime'
                                ? 'One-time payment, no renewal'
                                : 'Auto-renews unless cancelled',
                            style: AppFonts.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isPurchasing ? null : () => _handlePurchase(plan),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: isPurchasing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                plan['type'] == 'lifetime'
                                    ? 'Buy Now'
                                    : 'Start Free Trial',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Text(
            'Start your ${PremiumConstants.FREE_TRIAL_DAYS}-day free trial. No charges during trial period. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.',
            style: AppFonts.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'You can cancel your subscription anytime from your account settings.',
            style: AppFonts.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.accentGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: AppColors.accentGreen,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppFonts.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  void _showPaymentErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Payment Failed'),
            ),
          ],
        ),
        content: Text(
          error.isNotEmpty 
              ? error 
              : 'Payment could not be processed. Please try again.',
          style: AppFonts.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Optionally retry payment
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
