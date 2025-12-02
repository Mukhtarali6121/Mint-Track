import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for storing subscription information
class Subscription {
  final String id;
  final String userId;
  final String planId; // Razorpay plan ID
  final String subscriptionType; // monthly, yearly, lifetime
  final String status; // created, authenticated, active, pending, halted, cancelled, paused, expired, completed
  final DateTime startDate;
  final DateTime? endDate; // null for lifetime
  final DateTime? trialEndDate; // when free trial ends
  final bool isTrialActive;
  final bool autoRenewal;
  final String? razorpaySubscriptionId; // Razorpay subscription ID
  final String? razorpayCustomerId; // Razorpay customer ID
  final bool isPaused; // Whether subscription is paused
  final DateTime? pausedAt; // When subscription was paused
  final DateTime? resumeAt; // When subscription will resume
  final Map<String, dynamic>? scheduledChanges; // Pending updates
  final int? currentPeriod; // Current billing period number
  final int? totalCount; // Total billing cycles
  final Map<String, dynamic>? razorpayData; // Full Razorpay subscription data
  final DateTime createdAt;
  final DateTime? updatedAt;

  Subscription({
    required this.id,
    required this.userId,
    required this.planId,
    required this.subscriptionType,
    required this.status,
    required this.startDate,
    this.endDate,
    this.trialEndDate,
    required this.isTrialActive,
    required this.autoRenewal,
    this.razorpaySubscriptionId,
    this.razorpayCustomerId,
    this.isPaused = false,
    this.pausedAt,
    this.resumeAt,
    this.scheduledChanges,
    this.currentPeriod,
    this.totalCount,
    this.razorpayData,
    required this.createdAt,
    this.updatedAt,
  });

  /// Check if subscription is currently active (including trial)
  /// Based on Razorpay subscription states:
  /// - created: Not yet authenticated, no access
  /// - authenticated: Payment done, trial active (if applicable), grant access
  /// - active: Billing started, grant access
  /// - pending: Payment failed but retrying, grant access (still active)
  /// - halted: All retries exhausted, no access
  /// - cancelled: Cancelled, no access
  /// - paused: Paused, no access
  /// - expired: Expired, no access
  /// - completed: Completed lifecycle, no access
  bool get isActive {
    // These states never grant access
    if (status == 'expired' || 
        status == 'cancelled' || 
        status == 'halted' || 
        status == 'completed' ||
        status == 'created' ||
        isPaused) {
      return false;
    }
    
    // Check if trial is active (for authenticated/active states with trial)
    if (isTrialActive && trialEndDate != null) {
      return DateTime.now().isBefore(trialEndDate!);
    }
    
    // These states grant access (authenticated = payment done, active = billing started, pending = retrying)
    if (status == 'active' || 
        status == 'authenticated' || 
        status == 'pending') {
      if (subscriptionType == 'lifetime') {
        return true; // Lifetime subscriptions never expire
      }
      if (endDate != null) {
        return DateTime.now().isBefore(endDate!);
      }
      return true;
    }
    
    return false;
  }

  /// Check if user has premium access (active subscription or trial)
  bool get hasPremiumAccess {
    return isActive;
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'userId': userId,
      'planId': planId,
      'subscriptionType': subscriptionType,
      'status': status,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'trialEndDate': trialEndDate != null ? Timestamp.fromDate(trialEndDate!) : null,
      'isTrialActive': isTrialActive,
      'autoRenewal': autoRenewal,
      'razorpaySubscriptionId': razorpaySubscriptionId,
      'razorpayCustomerId': razorpayCustomerId,
      'isPaused': isPaused,
      'pausedAt': pausedAt != null ? Timestamp.fromDate(pausedAt!) : null,
      'resumeAt': resumeAt != null ? Timestamp.fromDate(resumeAt!) : null,
      'scheduledChanges': scheduledChanges,
      'currentPeriod': currentPeriod,
      'totalCount': totalCount,
      'razorpayData': razorpayData,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory Subscription.fromFirestoreMap(Map<String, dynamic> data, String id) {
    return Subscription(
      id: id,
      userId: data['userId'] as String,
      planId: data['planId'] as String,
      subscriptionType: data['subscriptionType'] as String,
      status: data['status'] as String,
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: data['endDate'] != null ? (data['endDate'] as Timestamp).toDate() : null,
      trialEndDate: data['trialEndDate'] != null ? (data['trialEndDate'] as Timestamp).toDate() : null,
      isTrialActive: data['isTrialActive'] as bool? ?? false,
      autoRenewal: data['autoRenewal'] as bool? ?? true,
      razorpaySubscriptionId: data['razorpaySubscriptionId'] as String?,
      razorpayCustomerId: data['razorpayCustomerId'] as String?,
      isPaused: data['isPaused'] as bool? ?? false,
      pausedAt: data['pausedAt'] != null ? (data['pausedAt'] as Timestamp).toDate() : null,
      resumeAt: data['resumeAt'] != null ? (data['resumeAt'] as Timestamp).toDate() : null,
      scheduledChanges: data['scheduledChanges'] as Map<String, dynamic>?,
      currentPeriod: data['currentPeriod'] as int?,
      totalCount: data['totalCount'] as int?,
      razorpayData: data['razorpayData'] as Map<String, dynamic>?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  Subscription copyWith({
    String? id,
    String? userId,
    String? planId,
    String? subscriptionType,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? trialEndDate,
    bool? isTrialActive,
    bool? autoRenewal,
    String? razorpaySubscriptionId,
    String? razorpayCustomerId,
    bool? isPaused,
    DateTime? pausedAt,
    DateTime? resumeAt,
    Map<String, dynamic>? scheduledChanges,
    int? currentPeriod,
    int? totalCount,
    Map<String, dynamic>? razorpayData,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Subscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      planId: planId ?? this.planId,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      trialEndDate: trialEndDate ?? this.trialEndDate,
      isTrialActive: isTrialActive ?? this.isTrialActive,
      autoRenewal: autoRenewal ?? this.autoRenewal,
      razorpaySubscriptionId: razorpaySubscriptionId ?? this.razorpaySubscriptionId,
      razorpayCustomerId: razorpayCustomerId ?? this.razorpayCustomerId,
      isPaused: isPaused ?? this.isPaused,
      pausedAt: pausedAt ?? this.pausedAt,
      resumeAt: resumeAt ?? this.resumeAt,
      scheduledChanges: scheduledChanges ?? this.scheduledChanges,
      currentPeriod: currentPeriod ?? this.currentPeriod,
      totalCount: totalCount ?? this.totalCount,
      razorpayData: razorpayData ?? this.razorpayData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

