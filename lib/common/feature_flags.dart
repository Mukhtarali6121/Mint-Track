import '../services/premium_service.dart';

/// Feature flags to control feature availability
class FeatureFlags {
  /// Set to true to enable the Goals feature for all users
  /// Set to false to hide the Goals feature completely
  // static const bool goalsFeatureEnabled = true;

  /// Set to true to enable the Recurring Transactions feature for all users
  /// Set to false to hide the Recurring Transactions feature completely
  static const bool recurringTransactionsFeatureEnabled = false;
  /// Goals feature is enabled only for premium users
  /// This checks the premium status dynamically
  static bool get goalsFeatureEnabled {
    return PremiumService.instance.isPremium;
  }
}

