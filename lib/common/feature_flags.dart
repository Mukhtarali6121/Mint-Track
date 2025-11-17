import '../services/premium_service.dart';

/// Feature flags to control feature availability
class FeatureFlags {
  /// Goals feature is enabled only for premium users
  /// This checks the premium status dynamically
  static bool get goalsFeatureEnabled {
    return PremiumService.instance.isPremium;
  }
}

