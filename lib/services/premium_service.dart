import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../common/premium_constants.dart';
import '../models/subscription.dart';
import '../models/invoice.dart';
import 'razorpay_subscription_service.dart';

/// Service for managing premium subscriptions via Razorpay
class PremiumService {
  static final PremiumService _instance = PremiumService._internal();
  factory PremiumService() => _instance;
  static PremiumService get instance => _instance;
  
  PremiumService._internal();

  late Razorpay _razorpay;
  bool _isInitialized = false;
  bool _isPremium = false;
  Subscription? _currentSubscription;
  Function(PaymentSuccessResponse)? _onPaymentSuccess;
  Function(PaymentFailureResponse)? _onPaymentFailure;
  Function(ExternalWalletResponse)? _onExternalWallet;

  bool get isInitialized => _isInitialized;
  bool get isPremium => _isPremium;
  Subscription? get currentSubscription => _currentSubscription;

  /// Initialize Razorpay SDK
  Future<void> initialize() async {
    if (_isInitialized) {
      // If already initialized, refresh premium status for current user
      await _checkPremiumStatus();
      return;
    }

    try {
      _razorpay = Razorpay();
      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
      
      // Check current premium status from Firestore
      await _checkPremiumStatus();
      
      _isInitialized = true;
      debugPrint('PremiumService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing PremiumService: $e');
      _isPremium = false;
      _isInitialized = true;
    }
  }

  /// Reset premium status (call on logout)
  Future<void> reset() async {
    debugPrint('PremiumService: Resetting premium status');
    _isPremium = false;
    _currentSubscription = null;
    // Note: We don't reset _isInitialized or dispose Razorpay here
    // as the service may be reused for the next user
  }

  /// Check current premium status from Firestore
  Future<void> _checkPremiumStatus() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        _isPremium = false;
        _currentSubscription = null;
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final subscriptionDoc = await firestore
          .collection('subscriptions')
          .doc(userId)
          .get();

      if (subscriptionDoc.exists) {
        final data = subscriptionDoc.data()!;
        _currentSubscription = Subscription.fromFirestoreMap(data, userId);
        _isPremium = _currentSubscription!.hasPremiumAccess;
      } else {
        _isPremium = false;
        _currentSubscription = null;
      }
      
      debugPrint('Premium status: $_isPremium');
    } catch (e) {
      debugPrint('Error checking premium status: $e');
      _isPremium = false;
      _currentSubscription = null;
    }
  }

  /// Handle payment success
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('Payment success: ${response.paymentId}');
    _onPaymentSuccess?.call(response);
  }

  /// Handle payment error
  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('Payment error: ${response.message}');
    _onPaymentFailure?.call(response);
  }

  /// Handle external wallet
  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('External wallet: ${response.walletName}');
    _onExternalWallet?.call(response);
  }

  /// Create a subscription link or order for payment
  /// Returns subscription link or order details
  Future<Map<String, dynamic>?> createSubscriptionOrder({
    required String planId,
    required String subscriptionType,
    required int amount,
    bool startTrial = true,
    bool useSubscriptionLink = false,
  }) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Check if this is the test plan - if so, disable trial
      final isTestPlan = planId == PremiumConstants.testPlanId;
      final shouldStartTrial = isTestPlan ? false : startTrial;
      
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('🔵 CREATING SUBSCRIPTION ORDER');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('Plan ID: $planId');
      debugPrint('Subscription Type: $subscriptionType');
      debugPrint('Amount: $amount');
      debugPrint('Is Test Plan: $isTestPlan');
      debugPrint('Start Trial (requested): $startTrial');
      debugPrint('Start Trial (final): $shouldStartTrial');
      debugPrint('Use Subscription Link: $useSubscriptionLink');
      debugPrint('Expected Monthly Plan ID: ${PremiumConstants.monthlyPlanId}');
      debugPrint('Expected Yearly Plan ID: ${PremiumConstants.yearlyPlanId}');
      debugPrint('Expected Lifetime Plan ID: ${PremiumConstants.lifetimePlanId}');
      debugPrint('Test Plan ID: ${PremiumConstants.testPlanId}');
      debugPrint('═══════════════════════════════════════════════════════════');

      if (useSubscriptionLink) {
        // Step 1: Create subscription first
        debugPrint('📝 Step 1: Creating Razorpay subscription...');
        try {
          final subscriptionService = RazorpaySubscriptionService.instance;
          
          // Calculate total_count based on subscription type
          int totalCount;
          if (subscriptionType == 'lifetime') {
            totalCount = 999; // Large number for lifetime
          } else if (subscriptionType == 'monthly') {
            totalCount = 12; // 12 months = 1 year
          } else if (subscriptionType == 'weekly') {
            totalCount = 52; // 52 weeks = 1 year
          } else {
            totalCount = 1; // 1 year
          }

          // Calculate dates for trial period
          final now = DateTime.now();
          final expireBy = now.add(const Duration(days: 30)); // Authorization payment expiry
          
          // If starting with trial, set start_at to trial end date (7 days from now)
          // This ensures billing starts after the trial period
          // For test plan, don't set start_at (billing starts immediately)
          DateTime? startAt;
          if (shouldStartTrial) {
            startAt = now.add(Duration(days: PremiumConstants.FREE_TRIAL_DAYS));
            debugPrint('📅 Trial period: ${PremiumConstants.FREE_TRIAL_DAYS} days');
            debugPrint('📅 Subscription will start at: ${startAt.toIso8601String()}');
            debugPrint('📅 Start At (Unix timestamp): ${(startAt.millisecondsSinceEpoch / 1000).round()}');
          } else {
            debugPrint('📅 No trial period - billing starts immediately');
          }

          // Get user email for notify_info
          final userEmail = FirebaseAuth.instance.currentUser?.email;
          Map<String, dynamic>? notifyInfo;
          if (userEmail != null && userEmail.isNotEmpty) {
            notifyInfo = {
              'notify_email': userEmail,
              // Don't include notify_phone as per user request
            };
            debugPrint('📧 Adding notify_info with email: $userEmail');
          }

          // Create subscription first
          debugPrint('🔍 Using Plan ID for subscription creation: $planId');
          final subscriptionResponse = await subscriptionService.createSubscription(
            planId: planId,
            totalCount: totalCount,
            quantity: 1,
            customerNotify: true,
            startAt: startAt, // Set to trial end date if trial is enabled
            expireBy: expireBy,
            notes: {
              'user_id': userId,
              'subscription_type': subscriptionType,
              'start_trial': shouldStartTrial.toString(),
            },
            notifyInfo: notifyInfo, // Add notify_info with user email
          );

          debugPrint('✅ Subscription created: $subscriptionResponse');
          
          // Extract subscription data
          final subscriptionId = subscriptionResponse['id'] as String?;
          final subscriptionShortUrl = subscriptionResponse['short_url'] as String?;

          if (subscriptionId == null) {
            throw Exception('Subscription created but no ID returned');
          }

          // The subscription response already includes short_url, no need for second API call
          debugPrint('✅ Subscription link (short_url) from response: $subscriptionShortUrl');

          if (subscriptionShortUrl != null) {
            return {
              'subscriptionLink': subscriptionShortUrl,
              'subscriptionId': subscriptionId,
              'amount': amount,
              'planId': planId,
              'subscriptionType': subscriptionType,
              'startTrial': shouldStartTrial,
            };
          } else {
            throw Exception('Subscription created but no short_url returned');
          }
        } catch (e) {
          debugPrint('❌ Error in subscription link flow: $e');
          debugPrint('⚠️ Falling back to order creation...');
          // Fall back to order creation
        }
      }

      // Create order via Razorpay API (fallback or for one-time payments)
      debugPrint('📝 Creating Razorpay order...');
      Map<String, dynamic>? orderData;
      try {
        orderData = await _createRazorpayOrder(amount, subscriptionType);
        debugPrint('✅ Order created: $orderData');
      } catch (e) {
        debugPrint('❌ Error creating Razorpay order: $e');
        throw Exception('Failed to create payment order: ${e.toString()}');
      }
      
      if (orderData != null && orderData['id'] != null) {
        debugPrint('✅ Returning order data');
        return {
          'orderId': orderData['id'],
          'amount': amount,
          'planId': planId,
          'subscriptionType': subscriptionType,
          'startTrial': shouldStartTrial,
        };
      }
      
      throw Exception('Failed to create Razorpay order');
    } catch (e) {
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('❌ ERROR CREATING SUBSCRIPTION ORDER');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('Error: $e');
      debugPrint('═══════════════════════════════════════════════════════════');
      rethrow;
    }
  }

  /// Create Razorpay order
  /// Note: For production, this should be done via backend API for security
  /// This implementation creates orders directly (works for testing)
  Future<Map<String, dynamic>?> _createRazorpayOrder(int amount, String subscriptionType) async {
    try {
      // Create order using Razorpay API
      // Note: In production, move this to your backend to keep secret key secure
      final url = Uri.parse('https://api.razorpay.com/v1/orders');
      
      final body = jsonEncode({
        'amount': amount, // amount in paise
        'currency': 'INR',
        'receipt': 'receipt_${DateTime.now().millisecondsSinceEpoch}',
        'notes': {
          'subscription_type': subscriptionType,
          'user_id': FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
        },
      });

      // Create basic auth header (key_id:key_secret)
      final credentials = base64Encode(
        utf8.encode('${PremiumConstants.razorpayKeyId}:${PremiumConstants.razorpayKeySecret}'),
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $credentials',
        },
        body: body,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout. Please check your internet connection.');
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        debugPrint('Razorpay order created: ${responseData['id']}');
        return responseData;
      } else {
        debugPrint('Failed to create Razorpay order: ${response.statusCode} - ${response.body}');
        // Try to parse error message
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['error']?['description'] ?? 'Failed to create order';
          throw Exception(errorMessage);
        } catch (_) {
          throw Exception('Failed to create order. Status: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('Error creating Razorpay order: $e');
      rethrow;
    }
  }

  /// Open Razorpay payment gateway
  Future<void> openPaymentGateway({
    required String orderId,
    required int amount,
    required String subscriptionType,
    Function(PaymentSuccessResponse)? onSuccess,
    Function(PaymentFailureResponse)? onFailure,
    Function(ExternalWalletResponse)? onExternalWallet,
  }) async {
    try {
      _onPaymentSuccess = onSuccess;
      _onPaymentFailure = onFailure;
      _onExternalWallet = onExternalWallet;

      final options = {
        'key': PremiumConstants.razorpayKeyId,
        'amount': amount, // amount in paise
        'name': 'Expense Tracker',
        'description': 'Premium Subscription - $subscriptionType',
        'order_id': orderId,
        'prefill': {
          'contact': '',
          'email': FirebaseAuth.instance.currentUser?.email ?? '',
        },
        'external': {
          'wallets': ['paytm']
        }
      };

      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening payment gateway: $e');
      // PaymentFailureResponse is created by Razorpay SDK when payment fails
      // For initialization errors (like this), we can't create PaymentFailureResponse
      // So we'll handle it by calling the error handler with a string message
      // The caller (PremiumProvider) will convert this to the appropriate format
      // For now, we'll just let the exception propagate and handle it in the provider
      throw Exception('Failed to open payment gateway: $e');
    }
  }

  /// Handle successful payment and activate subscription
  Future<void> handlePaymentSuccess({
    required String paymentId,
    required String orderId,
    required String subscriptionType,
    required String planId,
    bool startTrial = true,
    String? razorpaySubscriptionId,
  }) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        debugPrint('❌ handlePaymentSuccess: User not logged in');
        return;
      }

      // Check if this is the test plan - if so, disable trial
      final isTestPlan = planId == PremiumConstants.testPlanId;
      final shouldStartTrial = isTestPlan ? false : startTrial;
      
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('🟢 HANDLING PAYMENT SUCCESS');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('Payment ID: $paymentId');
      debugPrint('Order ID: $orderId');
      debugPrint('Plan ID: $planId');
      debugPrint('Is Test Plan: $isTestPlan');
      debugPrint('Subscription Type: $subscriptionType');
      debugPrint('Start Trial (requested): $startTrial');
      debugPrint('Start Trial (final): $shouldStartTrial');
      debugPrint('Existing Razorpay Subscription ID: $razorpaySubscriptionId');
      debugPrint('═══════════════════════════════════════════════════════════');

      // Get current timestamp - used throughout the method
      final now = DateTime.now();

      final subscriptionService = RazorpaySubscriptionService.instance;
      Map<String, dynamic>? razorpayData;
      String? actualSubscriptionId = razorpaySubscriptionId;

      // If we don't have a subscription ID, create one after payment
      if (actualSubscriptionId == null) {
        debugPrint('📝 No existing subscription ID. Creating Razorpay subscription...');
        try {
          // Calculate total_count based on subscription type
          // For lifetime, use a large number or null (infinite)
          int totalCount;
          if (subscriptionType == 'lifetime') {
            totalCount = 999; // Large number for lifetime
          } else if (subscriptionType == 'monthly') {
            totalCount = 12; // 12 months = 1 year
          } else if (subscriptionType == 'weekly') {
            totalCount = 52; // 52 weeks = 1 year
          } else {
            totalCount = 1; // 1 year
          }

          // Calculate expire_by (30 days from now for authorization payment)
          final expireBy = now.add(const Duration(days: 30));

          // Create subscription in Razorpay
          // Note: For subscriptions with trial, we might want to set start_at to trial end date
          // But for now, we'll start immediately after payment
          final subscriptionResponse = await subscriptionService.createSubscription(
            planId: planId,
            totalCount: totalCount,
            quantity: 1,
            customerNotify: true, // Boolean, not string
            expireBy: expireBy, // Authorization payment expiry
            notes: {
              'user_id': userId,
              'subscription_type': subscriptionType,
              'start_trial': shouldStartTrial.toString(),
              'payment_id': paymentId,
              'order_id': orderId,
            },
          );

          debugPrint('✅ Razorpay subscription created successfully');
          debugPrint('Subscription Response: $subscriptionResponse');
          
          actualSubscriptionId = subscriptionResponse['id'] as String?;
          razorpayData = subscriptionResponse;
          
          debugPrint('New Subscription ID: $actualSubscriptionId');
        } catch (e) {
          debugPrint('❌ Error creating Razorpay subscription: $e');
          debugPrint('⚠️ Continuing with local subscription creation...');
        }
      } else {
        // If we have a subscription ID, fetch full details
        debugPrint('📥 Fetching existing subscription details...');
        try {
          razorpayData = await subscriptionService.fetchSubscriptionById(actualSubscriptionId);
          debugPrint('✅ Subscription details fetched: $razorpayData');
        } catch (e) {
          debugPrint('❌ Error fetching subscription details: $e');
        }
      }

      // Create subscription after successful payment
      final trialEndDate = shouldStartTrial 
          ? now.add(Duration(days: PremiumConstants.FREE_TRIAL_DAYS))
          : null;

      // Parse Razorpay subscription data if available
      // Default status: if trial, it will be "authenticated" after payment, otherwise "active"
      String status = shouldStartTrial ? 'authenticated' : 'active';
      DateTime? endDate;
      bool isPaused = false;
      int? currentPeriod;
      int? totalCount;

      if (razorpayData != null) {
        // Use actual Razorpay status (created, authenticated, active, pending, halted, cancelled, paused, expired, completed)
        status = razorpayData['status'] as String? ?? status;
        isPaused = razorpayData['pause_at'] != null;
        currentPeriod = razorpayData['current_start'] != null ? 1 : null; // Simplified
        totalCount = razorpayData['total_count'] as int?;
        
        debugPrint('📊 Parsed Razorpay subscription status: $status');
        debugPrint('📊 Is Paused: $isPaused');
        debugPrint('📊 Current Period: $currentPeriod');
        debugPrint('📊 Total Count: $totalCount');
        
        if (razorpayData['end_at'] != null) {
          endDate = DateTime.fromMillisecondsSinceEpoch(
            (razorpayData['end_at'] as int) * 1000,
          );
        } else if (subscriptionType != 'lifetime') {
          if (subscriptionType == 'weekly') {
            endDate = now.add(const Duration(days: 7));
          } else if (subscriptionType == 'monthly') {
            endDate = now.add(const Duration(days: 30));
          } else {
            endDate = now.add(const Duration(days: 365));
          }
        }
      } else {
        if (subscriptionType == 'lifetime') {
          endDate = null;
        } else if (subscriptionType == 'weekly') {
          endDate = now.add(const Duration(days: 7));
        } else if (subscriptionType == 'monthly') {
          endDate = now.add(const Duration(days: 30));
        } else {
          endDate = now.add(const Duration(days: 365));
        }
      }

      final subscription = Subscription(
        id: userId,
        userId: userId,
        planId: planId,
        subscriptionType: subscriptionType,
        status: status,
        startDate: now,
        endDate: endDate,
        trialEndDate: trialEndDate,
        isTrialActive: shouldStartTrial,
        autoRenewal: subscriptionType != 'lifetime',
        razorpaySubscriptionId: actualSubscriptionId ?? paymentId,
        razorpayCustomerId: razorpayData?['customer_id'] as String?,
        isPaused: isPaused,
        currentPeriod: currentPeriod,
        totalCount: totalCount,
        razorpayData: razorpayData,
        createdAt: now,
      );

      debugPrint('💾 Saving subscription to Firestore...');
      debugPrint('Subscription Data: ${subscription.toFirestoreMap()}');
      
      await _saveSubscriptionToFirestore(subscription);
      
      _currentSubscription = subscription;
      _isPremium = subscription.hasPremiumAccess;
      
      debugPrint('✅ Subscription saved successfully');
      debugPrint('Premium Status: $_isPremium');
      debugPrint('Subscription ID: ${subscription.razorpaySubscriptionId}');
      debugPrint('═══════════════════════════════════════════════════════════');
    } catch (e) {
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('❌ ERROR HANDLING PAYMENT SUCCESS');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('Error: $e');
      debugPrint('═══════════════════════════════════════════════════════════');
      rethrow;
    }
  }

  /// Save subscription to Firestore
  Future<void> _saveSubscriptionToFirestore(Subscription subscription) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('subscriptions')
          .doc(subscription.userId)
          .set(subscription.toFirestoreMap());
    } catch (e) {
      debugPrint('Error saving subscription to Firestore: $e');
      rethrow;
    }
  }

  /// Get subscription plans
  List<Map<String, dynamic>> getSubscriptionPlans() {
    return [
      {
        'id': PremiumConstants.weeklyPlanId,
        'type': PremiumConstants.subscriptionTypeWeekly,
        'name': 'Weekly',
        'amount': PremiumConstants.weeklyAmount,
        'amountDisplay': '₹${(PremiumConstants.weeklyAmount / 100).toStringAsFixed(2)}',
        'period': 'per week',
        'trialDays': 0, // Weekly plan has no trial (test plan)
      },
      {
        'id': PremiumConstants.monthlyPlanId,
        'type': PremiumConstants.subscriptionTypeMonthly,
        'name': 'Monthly',
        'amount': PremiumConstants.monthlyAmount,
        'amountDisplay': '₹${(PremiumConstants.monthlyAmount / 100).toStringAsFixed(2)}',
        'period': 'per month',
        'trialDays': PremiumConstants.FREE_TRIAL_DAYS,
      },
      {
        'id': PremiumConstants.yearlyPlanId,
        'type': PremiumConstants.subscriptionTypeYearly,
        'name': 'Yearly',
        'amount': PremiumConstants.yearlyAmount,
        'amountDisplay': '₹${(PremiumConstants.yearlyAmount / 100).toStringAsFixed(2)}',
        'period': 'per year',
        'trialDays': PremiumConstants.FREE_TRIAL_DAYS,
        'isBestValue': true,
      },
      {
        'id': PremiumConstants.lifetimePlanId,
        'type': PremiumConstants.subscriptionTypeLifetime,
        'name': 'Lifetime',
        'amount': PremiumConstants.lifetimeAmount,
        'amountDisplay': '₹${(PremiumConstants.lifetimeAmount / 100).toStringAsFixed(2)}',
        'period': 'one-time payment',
        'trialDays': PremiumConstants.FREE_TRIAL_DAYS,
      },
    ];
  }

  /// Refresh premium status
  Future<void> refreshPremiumStatus() async {
    await _checkPremiumStatus();
  }

  /// Cancel subscription
  Future<bool> cancelSubscription({bool cancelAtCycleEnd = true}) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null || _currentSubscription == null) {
        return false;
      }

      // Cancel via Razorpay API if subscription ID exists
      if (_currentSubscription!.razorpaySubscriptionId != null) {
        try {
          final subscriptionService = RazorpaySubscriptionService.instance;
          await subscriptionService.cancelSubscription(
            _currentSubscription!.razorpaySubscriptionId!,
            cancelAtCycleEnd: cancelAtCycleEnd,
          );
        } catch (e) {
          debugPrint('Error cancelling subscription via Razorpay: $e');
          // Continue to update Firestore even if API call fails
        }
      }

      final firestore = FirebaseFirestore.instance;
      final updatedSubscription = _currentSubscription!.copyWith(
        status: cancelAtCycleEnd ? 'active' : 'cancelled',
        autoRenewal: false,
        updatedAt: DateTime.now(),
      );

      await firestore
          .collection('subscriptions')
          .doc(userId)
          .update(updatedSubscription.toFirestoreMap());

      _currentSubscription = updatedSubscription;
      _isPremium = updatedSubscription.hasPremiumAccess;
      
      return true;
    } catch (e) {
      debugPrint('Error cancelling subscription: $e');
      return false;
    }
  }

  /// Pause subscription
  Future<bool> pauseSubscription({DateTime? pauseAt}) async {
    try {
      if (_currentSubscription?.razorpaySubscriptionId == null) {
        return false;
      }

      final subscriptionService = RazorpaySubscriptionService.instance;
      await subscriptionService.pauseSubscription(
        _currentSubscription!.razorpaySubscriptionId!,
        pauseAt: pauseAt,
      );

      await _syncSubscriptionFromRazorpay();
      return true;
    } catch (e) {
      debugPrint('Error pausing subscription: $e');
      return false;
    }
  }

  /// Resume subscription
  Future<bool> resumeSubscription({DateTime? resumeAt}) async {
    try {
      if (_currentSubscription?.razorpaySubscriptionId == null) {
        return false;
      }

      final subscriptionService = RazorpaySubscriptionService.instance;
      await subscriptionService.resumeSubscription(
        _currentSubscription!.razorpaySubscriptionId!,
        resumeAt: resumeAt,
      );

      await _syncSubscriptionFromRazorpay();
      return true;
    } catch (e) {
      debugPrint('Error resuming subscription: $e');
      return false;
    }
  }

  /// Update subscription
  Future<bool> updateSubscription({
    String? planId,
    int? quantity,
    DateTime? startAt,
    DateTime? expireBy,
    Map<String, dynamic>? notes,
  }) async {
    try {
      if (_currentSubscription?.razorpaySubscriptionId == null) {
        return false;
      }

      final subscriptionService = RazorpaySubscriptionService.instance;
      await subscriptionService.updateSubscription(
        _currentSubscription!.razorpaySubscriptionId!,
        planId: planId,
        quantity: quantity,
        startAt: startAt,
        expireBy: expireBy,
        notes: notes,
      );

      await _syncSubscriptionFromRazorpay();
      return true;
    } catch (e) {
      debugPrint('Error updating subscription: $e');
      return false;
    }
  }

  /// Fetch subscription invoices
  Future<List<Invoice>> fetchSubscriptionInvoices({
    int? count,
    int? skip,
  }) async {
    try {
      if (_currentSubscription?.razorpaySubscriptionId == null) {
        return [];
      }

      final subscriptionService = RazorpaySubscriptionService.instance;
      final response = await subscriptionService.fetchSubscriptionInvoices(
        _currentSubscription!.razorpaySubscriptionId!,
        count: count,
        skip: skip,
      );

      final items = response['items'] as List<dynamic>? ?? [];
      debugPrint('📄 Found ${items.length} invoices');
      final invoices = items.map((item) {
        try {
          return Invoice.fromRazorpayData(item as Map<String, dynamic>);
        } catch (e) {
          debugPrint('❌ Error parsing invoice: $e');
          debugPrint('Invoice data: $item');
          rethrow;
        }
      }).toList();
      debugPrint('✅ Successfully parsed ${invoices.length} invoices');
      return invoices;
    } catch (e) {
      debugPrint('Error fetching subscription invoices: $e');
      return [];
    }
  }

  /// Fetch pending update details
  Future<Map<String, dynamic>?> fetchPendingUpdate() async {
    try {
      if (_currentSubscription?.razorpaySubscriptionId == null) {
        return null;
      }

      final subscriptionService = RazorpaySubscriptionService.instance;
      return await subscriptionService.fetchPendingUpdate(
        _currentSubscription!.razorpaySubscriptionId!,
      );
    } catch (e) {
      debugPrint('Error fetching pending update: $e');
      return null;
    }
  }

  /// Cancel pending update
  Future<bool> cancelPendingUpdate() async {
    try {
      if (_currentSubscription?.razorpaySubscriptionId == null) {
        return false;
      }

      final subscriptionService = RazorpaySubscriptionService.instance;
      await subscriptionService.cancelUpdate(
        _currentSubscription!.razorpaySubscriptionId!,
      );

      await _syncSubscriptionFromRazorpay();
      return true;
    } catch (e) {
      debugPrint('Error cancelling pending update: $e');
      return false;
    }
  }

  /// Link offer to subscription
  Future<bool> linkOfferToSubscription(String offerId) async {
    try {
      if (_currentSubscription?.razorpaySubscriptionId == null) {
        return false;
      }

      final subscriptionService = RazorpaySubscriptionService.instance;
      await subscriptionService.linkOfferToSubscription(
        _currentSubscription!.razorpaySubscriptionId!,
        offerId,
      );

      await _syncSubscriptionFromRazorpay();
      return true;
    } catch (e) {
      debugPrint('Error linking offer to subscription: $e');
      return false;
    }
  }

  /// Delete offer from subscription
  Future<bool> deleteOfferFromSubscription(String offerId) async {
    try {
      if (_currentSubscription?.razorpaySubscriptionId == null) {
        return false;
      }

      final subscriptionService = RazorpaySubscriptionService.instance;
      await subscriptionService.deleteOfferFromSubscription(
        _currentSubscription!.razorpaySubscriptionId!,
        offerId,
      );

      await _syncSubscriptionFromRazorpay();
      return true;
    } catch (e) {
      debugPrint('Error deleting offer from subscription: $e');
      return false;
    }
  }

  /// Sync subscription data from Razorpay
  Future<void> _syncSubscriptionFromRazorpay() async {
    try {
      if (_currentSubscription?.razorpaySubscriptionId == null) {
        return;
      }

      final subscriptionService = RazorpaySubscriptionService.instance;
      final razorpayData = await subscriptionService.fetchSubscriptionById(
        _currentSubscription!.razorpaySubscriptionId!,
      );

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Update subscription with latest Razorpay data
      final now = DateTime.now();
      final status = razorpayData['status'] as String? ?? 'active';
      final isPaused = razorpayData['pause_at'] != null;
      final pausedAt = razorpayData['pause_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch((razorpayData['pause_at'] as int) * 1000)
          : null;
      final resumeAt = razorpayData['resume_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch((razorpayData['resume_at'] as int) * 1000)
          : null;

      final updatedSubscription = _currentSubscription!.copyWith(
        status: status,
        isPaused: isPaused,
        pausedAt: pausedAt,
        resumeAt: resumeAt,
        razorpayData: razorpayData,
        updatedAt: now,
      );

      await _saveSubscriptionToFirestore(updatedSubscription);
      _currentSubscription = updatedSubscription;
      _isPremium = updatedSubscription.hasPremiumAccess;
    } catch (e) {
      debugPrint('Error syncing subscription from Razorpay: $e');
    }
  }

  /// Dispose Razorpay instance
  void dispose() {
    if (_isInitialized) {
      _razorpay.clear();
    }
  }
}
