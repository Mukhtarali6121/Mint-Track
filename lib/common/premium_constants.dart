/// Constants for premium features and subscription management
class PremiumConstants {
  // Free tier limits
  static const int FREE_MAX_ACCOUNTS = 3;
  static const int FREE_MAX_RECURRING_TRANSACTIONS = 3;
  static const int FREE_MAX_CATEGORIES = 10; // Max categories per type (expense/income)
  
  // Premium tier limits
  static const int PREMIUM_MAX_ACCOUNTS = 2; // Premium users get 2 accounts
  static const int PREMIUM_MAX_CATEGORIES = 50; // Premium users get 50 categories per type

  // Razorpay Configuration
  // Get this from Razorpay dashboard: Settings > API Keys
  // Use test key for development, production key for release
  static const String razorpayKeyId = 'rzp_test_RlE8ICNTioV4WN'; // Replace with your Razorpay Key ID
  static const String razorpayKeySecret = 'WuqnUp5FQXKpvsAl1L1i2poI'; // Keep this on backend only

  // Free trial period in days
  static const int FREE_TRIAL_DAYS = 7;
  
  // Subscription plan IDs - these must match what you configure in Razorpay dashboard
  // Create these plans in Razorpay Dashboard > Subscriptions > Plans
  static const String weeklyPlanId = 'plan_RmfqqFu0TmtgAk'; // Weekly plan ID (7-day billing cycle, no trial)
  static const String monthlyPlanId = 'plan_RmbspWEzpHe0oF'; // Monthly plan ID
  static const String yearlyPlanId = 'plan_Rmeort19iBpd0U'; // Yearly plan ID
  static const String lifetimePlanId = 'plan_lifetime'; // Replace with your actual plan ID
  static const String testPlanId = 'plan_RmfqqFu0TmtgAk'; // 7-day billing cycle test plan (no trial)
  
  // Subscription types
  static const String subscriptionTypeWeekly = 'weekly';
  static const String subscriptionTypeMonthly = 'monthly';
  static const String subscriptionTypeYearly = 'yearly';
  static const String subscriptionTypeLifetime = 'lifetime';
  
  // Subscription amounts (in paise - 1 rupee = 100 paise)
  // Update these based on your actual pricing
  static const int weeklyAmount = 9900; // ₹99.00
  static const int monthlyAmount = 29900; // ₹299.00
  static const int yearlyAmount = 299900; // ₹2999.00
  static const int lifetimeAmount = 499900; // ₹4999.00
}

