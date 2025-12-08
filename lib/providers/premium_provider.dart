import 'package:flutter/foundation.dart';
import '../services/premium_service.dart';
import '../models/subscription.dart';
import '../models/invoice.dart';

/// Provider for managing premium subscription state
/// Wraps PremiumService to provide reactive updates to the UI
class PremiumProvider extends ChangeNotifier {
  PremiumProvider() {
    _setupListener();
  }

  bool _isInitialized = false;
  bool _isPremium = false;
  Subscription? _currentSubscription;
  List<Map<String, dynamic>> _subscriptionPlans = [];

  bool get isInitialized => _isInitialized;
  bool get isPremium => _isPremium;
  Subscription? get currentSubscription => _currentSubscription;
  List<Map<String, dynamic>> get subscriptionPlans => _subscriptionPlans;

  /// Initialize the provider and check premium status
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Ensure PremiumService is initialized
      if (!PremiumService.instance.isInitialized) {
        await PremiumService.instance.initialize();
      }

      // Get current status
      _isPremium = PremiumService.instance.isPremium;
      _currentSubscription = PremiumService.instance.currentSubscription;

      // Load subscription plans
      _subscriptionPlans = PremiumService.instance.getSubscriptionPlans();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing PremiumProvider: $e');
      _isPremium = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Set up listener for premium status changes
  void _setupListener() {
    // PremiumService handles status updates internally
    // We'll refresh when needed
  }

  /// Refresh premium status
  Future<void> refreshPremiumStatus() async {
    try {
      await PremiumService.instance.refreshPremiumStatus();
      _isPremium = PremiumService.instance.isPremium;
      _currentSubscription = PremiumService.instance.currentSubscription;
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing premium status: $e');
    }
  }

  /// Create subscription order
  Future<Map<String, dynamic>?> createSubscriptionOrder({
    required String planId,
    required String subscriptionType,
    required int amount,
    bool startTrial = true,
  }) async {
    try {
      final result = await PremiumService.instance.createSubscriptionOrder(
        planId: planId,
        subscriptionType: subscriptionType,
        amount: amount,
        startTrial: startTrial,
        useSubscriptionLink: true
      );

      if (result != null) {
        _isPremium = PremiumService.instance.isPremium;
        _currentSubscription = PremiumService.instance.currentSubscription;
        notifyListeners();
      }

      return result;
    } catch (e) {
      debugPrint('Error creating subscription order: $e');
      // Re-throw the exception so the UI can show the actual error message
      rethrow;
    }
  }

  /// Open payment gateway
  Future<void> openPaymentGateway({
    required String orderId,
    required int amount,
    required String subscriptionType,
    String? planId,
    bool startTrial = true,
    Function()? onSuccess,
    Function(String)? onFailure,
  }) async {
    try {
      await PremiumService.instance.openPaymentGateway(
        orderId: orderId,
        amount: amount,
        subscriptionType: subscriptionType,
        onSuccess: (response) async {
          // Handle payment success - get plan details from orderData if available
          // For now, we'll pass the subscriptionType and create subscription
          try {
            await PremiumService.instance.handlePaymentSuccess(
              paymentId: response.paymentId ?? '',
              orderId: orderId,
              subscriptionType: subscriptionType,
              planId: planId ?? 'plan_$subscriptionType',
              startTrial: startTrial,
            );
            
            // Refresh status
            await refreshPremiumStatus();
            
            onSuccess?.call();
          } catch (e) {
            debugPrint('Error handling payment success: $e');
            onFailure?.call('Payment succeeded but failed to activate subscription. Please contact support.');
          }
        },
        onFailure: (response) {
          // Extract error message from PaymentFailureResponse
          // The response.message is a getter, not a constructor parameter
          final errorMessage = response.message ?? 'Payment failed';
          onFailure?.call(errorMessage);
        },
        onExternalWallet: (response) {
          debugPrint('External wallet selected: ${response.walletName}');
        },
      );
    } catch (e) {
      debugPrint('Error opening payment gateway: $e');
      // Handle initialization errors (not payment errors from Razorpay SDK)
      onFailure?.call(e.toString());
    }
  }

  /// Cancel subscription
  Future<bool> cancelSubscription({bool cancelAtCycleEnd = true}) async {
    try {
      final success = await PremiumService.instance.cancelSubscription(
        cancelAtCycleEnd: cancelAtCycleEnd,
      );
      if (success) {
        _isPremium = PremiumService.instance.isPremium;
        _currentSubscription = PremiumService.instance.currentSubscription;
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Error cancelling subscription: $e');
      return false;
    }
  }

  /// Pause subscription
  Future<bool> pauseSubscription({DateTime? pauseAt}) async {
    try {
      final success = await PremiumService.instance.pauseSubscription(pauseAt: pauseAt);
      if (success) {
        _isPremium = PremiumService.instance.isPremium;
        _currentSubscription = PremiumService.instance.currentSubscription;
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Error pausing subscription: $e');
      return false;
    }
  }

  /// Resume subscription
  Future<bool> resumeSubscription({DateTime? resumeAt}) async {
    try {
      final success = await PremiumService.instance.resumeSubscription(resumeAt: resumeAt);
      if (success) {
        _isPremium = PremiumService.instance.isPremium;
        _currentSubscription = PremiumService.instance.currentSubscription;
        notifyListeners();
      }
      return success;
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
      final success = await PremiumService.instance.updateSubscription(
        planId: planId,
        quantity: quantity,
        startAt: startAt,
        expireBy: expireBy,
        notes: notes,
      );
      if (success) {
        _isPremium = PremiumService.instance.isPremium;
        _currentSubscription = PremiumService.instance.currentSubscription;
        notifyListeners();
      }
      return success;
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
      return await PremiumService.instance.fetchSubscriptionInvoices(
        count: count,
        skip: skip,
      );
    } catch (e) {
      debugPrint('Error fetching subscription invoices: $e');
      return [];
    }
  }

  /// Fetch pending update details
  Future<Map<String, dynamic>?> fetchPendingUpdate() async {
    try {
      return await PremiumService.instance.fetchPendingUpdate();
    } catch (e) {
      debugPrint('Error fetching pending update: $e');
      return null;
    }
  }

  /// Cancel pending update
  Future<bool> cancelPendingUpdate() async {
    try {
      final success = await PremiumService.instance.cancelPendingUpdate();
      if (success) {
        _isPremium = PremiumService.instance.isPremium;
        _currentSubscription = PremiumService.instance.currentSubscription;
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Error cancelling pending update: $e');
      return false;
    }
  }

  /// Link offer to subscription
  Future<bool> linkOfferToSubscription(String offerId) async {
    try {
      final success = await PremiumService.instance.linkOfferToSubscription(offerId);
      if (success) {
        _isPremium = PremiumService.instance.isPremium;
        _currentSubscription = PremiumService.instance.currentSubscription;
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Error linking offer to subscription: $e');
      return false;
    }
  }

  /// Delete offer from subscription
  Future<bool> deleteOfferFromSubscription(String offerId) async {
    try {
      final success = await PremiumService.instance.deleteOfferFromSubscription(offerId);
      if (success) {
        _isPremium = PremiumService.instance.isPremium;
        _currentSubscription = PremiumService.instance.currentSubscription;
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Error deleting offer from subscription: $e');
      return false;
    }
  }

  /// Reload subscription plans
  void reloadSubscriptionPlans() {
    _subscriptionPlans = PremiumService.instance.getSubscriptionPlans();
    notifyListeners();
  }

  /// Reset premium provider (call on logout)
  Future<void> reset() async {
    debugPrint('PremiumProvider: Resetting premium status');
    _isPremium = false;
    _currentSubscription = null;
    _isInitialized = false;
    await PremiumService.instance.reset();
    notifyListeners();
  }
}
