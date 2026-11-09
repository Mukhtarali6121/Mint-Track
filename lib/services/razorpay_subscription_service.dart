import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../common/premium_constants.dart';

/// Service for managing Razorpay subscriptions via API
/// Handles all subscription operations: create, fetch, cancel, pause, resume, etc.
class RazorpaySubscriptionService {
  static final RazorpaySubscriptionService _instance = RazorpaySubscriptionService._internal();
  factory RazorpaySubscriptionService() => _instance;
  static RazorpaySubscriptionService get instance => _instance;
  
  RazorpaySubscriptionService._internal();

  // Base URL for Razorpay API
  static const String _baseUrl = 'https://api.razorpay.com/v1';

  /// Get authorization header
  String _getAuthHeader() {
    final credentials = base64Encode(
      utf8.encode('${PremiumConstants.razorpayKeyId}:${PremiumConstants.razorpayKeySecret}'),
    );
    return 'Basic $credentials';
  }

  /// Make authenticated API request
  Future<Map<String, dynamic>> _makeRequest({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    try {
      var uri = Uri.parse('$_baseUrl$endpoint');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': _getAuthHeader(),
      };

      // Print request details
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('🔵 RAZORPAY API REQUEST');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('Method: $method');
      debugPrint('Endpoint: $endpoint');
      debugPrint('Full URL: $uri');
      if (body != null) {
        debugPrint('Request Body: ${jsonEncode(body)}');
      }
      if (queryParams != null && queryParams.isNotEmpty) {
        debugPrint('Query Params: $queryParams');
      }
      debugPrint('═══════════════════════════════════════════════════════════');

      http.Response response;
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Request timeout'),
          );
          break;
        case 'POST':
          response = await http.post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Request timeout'),
          );
          break;
        case 'PATCH':
          response = await http.patch(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Request timeout'),
          );
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Request timeout'),
          );
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      // Print response details
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('🟢 RAZORPAY API RESPONSE');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');
      debugPrint('═══════════════════════════════════════════════════════════');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          debugPrint('✅ Success: Empty response body');
          return {'success': true};
        }
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ Success: Response parsed successfully');
        debugPrint('Response Data: $responseData');
        return responseData;
      } else {
        debugPrint('❌ Error: Status code ${response.statusCode}');
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('Error Data: $errorData');
        final error = errorData['error'] as Map<String, dynamic>?;
        final errorMessage = error?['description'] ?? error?['message'] ?? 'API request failed';
        debugPrint('Error Message: $errorMessage');
        throw Exception('${response.statusCode}: $errorMessage');
      }
    } catch (e) {
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('❌ RAZORPAY API EXCEPTION');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('Method: $method');
      debugPrint('Endpoint: $endpoint');
      debugPrint('Error: $e');
      debugPrint('═══════════════════════════════════════════════════════════');
      rethrow;
    }
  }

  /// Create a Subscription
  /// https://razorpay.com/docs/api/subscriptions/#create-a-subscription
  /// 
  /// Required parameters:
  /// - plan_id: The unique identifier of a plan
  /// - total_count: The number of billing cycles
  /// 
  /// Optional parameters:
  /// - quantity: Number of times to charge per invoice (default: 1)
  /// - customer_notify: Whether Razorpay handles communication (default: true)
  /// - start_at: Unix timestamp for when subscription should start
  /// - expire_by: Unix timestamp for when authorization payment expires
  /// - addons: Array of upfront charges
  /// - offer_id: Unique identifier of an offer
  /// - notes: Key-value pairs (max 15 pairs)
  Future<Map<String, dynamic>> createSubscription({
    required String planId,
    required int totalCount, // Total number of billing cycles
    int quantity = 1, // Default to 1
    bool customerNotify = true, // Default to true (Razorpay handles communication)
    DateTime? startAt,
    DateTime? expireBy,
    Map<String, dynamic>? notes,
    String? offerId, // Changed from Map to String
    List<Map<String, dynamic>>? addons, // Changed to List as per API docs
    Map<String, dynamic>? notifyInfo, // For subscription link notifications
  }) async {
    final body = <String, dynamic>{
      'plan_id': planId,
      'total_count': totalCount,
      'quantity': quantity,
      'customer_notify': customerNotify, // Boolean, not string
      if (startAt != null) 'start_at': (startAt.millisecondsSinceEpoch / 1000).round(),
      if (expireBy != null) 'expire_by': (expireBy.millisecondsSinceEpoch / 1000).round(),
      if (notes != null) 'notes': notes,
      if (offerId != null) 'offer_id': offerId,
      if (addons != null && addons.isNotEmpty) 'addons': addons,
      if (notifyInfo != null) 'notify_info': notifyInfo,
    };

    debugPrint('📝 Creating Razorpay Subscription with body:');
    debugPrint('Plan ID: $planId');
    debugPrint('Total Count: $totalCount');
    debugPrint('Quantity: $quantity');
    debugPrint('Customer Notify: $customerNotify');
    if (startAt != null) debugPrint('Start At: ${startAt.toIso8601String()}');
    if (expireBy != null) debugPrint('Expire By: ${expireBy.toIso8601String()}');
    if (notes != null) debugPrint('Notes: $notes');
    if (offerId != null) debugPrint('Offer ID: $offerId');
    if (addons != null) debugPrint('Addons: $addons');
    if (notifyInfo != null) debugPrint('Notify Info: $notifyInfo');

    return await _makeRequest(
      method: 'POST',
      endpoint: '/subscriptions',
      body: body,
    );
  }

  /// Create a Subscription Link
  /// https://razorpay.com/docs/api/subscriptions/#create-a-subscription-link
  /// 
  /// Note: Subscription links are created using the same endpoint as subscriptions
  /// but with notify_info parameter. The response includes a short_url for sharing.
  Future<Map<String, dynamic>> createSubscriptionLink({
    required String planId,
    required int totalCount, // Required for subscription link
    required int quantity,
    bool customerNotify = true, // Boolean, default true
    DateTime? startAt,
    DateTime? expireBy,
    Map<String, dynamic>? notes,
    String? offerId,
    List<Map<String, dynamic>>? addons,
    String? customerId,
    Map<String, dynamic>? notifyInfo,
    Map<String, dynamic>? options,
  }) async {
    final body = <String, dynamic>{
      'plan_id': planId,
      'total_count': totalCount, // Required field
      'quantity': quantity,
      'customer_notify': customerNotify, // Boolean, not string
      if (startAt != null) 'start_at': (startAt.millisecondsSinceEpoch / 1000).round(),
      if (expireBy != null) 'expire_by': (expireBy.millisecondsSinceEpoch / 1000).round(),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (offerId != null) 'offer_id': offerId,
      if (addons != null && addons.isNotEmpty) 'addons': addons,
      if (customerId != null) 'customer_id': customerId,
      if (notifyInfo != null) 'notify_info': notifyInfo,
      if (options != null) 'options': options,
    };

    debugPrint('📝 Creating Subscription Link with body:');
    debugPrint('Plan ID: $planId');
    debugPrint('Total Count: $totalCount');
    debugPrint('Quantity: $quantity');
    debugPrint('Customer Notify: $customerNotify');
    if (startAt != null) debugPrint('Start At: ${startAt.toIso8601String()}');
    if (expireBy != null) debugPrint('Expire By: ${expireBy.toIso8601String()}');
    if (notes != null) debugPrint('Notes: $notes');
    if (offerId != null) debugPrint('Offer ID: $offerId');
    if (addons != null) debugPrint('Addons: $addons');
    if (customerId != null) debugPrint('Customer ID: $customerId');
    if (notifyInfo != null) debugPrint('Notify Info: $notifyInfo');

    // Subscription links use the same endpoint as subscriptions: /subscriptions
    return await _makeRequest(
      method: 'POST',
      endpoint: '/subscriptions', // Fixed: use /subscriptions not /subscription_links
      body: body,
    );
  }

  /// Fetch All Subscriptions
  /// https://razorpay.com/docs/api/subscriptions/#fetch-all-subscriptions
  Future<Map<String, dynamic>> fetchAllSubscriptions({
    int? count,
    int? skip,
    String? planId,
    String? customerId,
    String? status,
  }) async {
    final queryParams = <String, String>{};
    if (count != null) queryParams['count'] = count.toString();
    if (skip != null) queryParams['skip'] = skip.toString();
    if (planId != null) queryParams['plan_id'] = planId;
    if (customerId != null) queryParams['customer_id'] = customerId;
    if (status != null) queryParams['status'] = status;

    return await _makeRequest(
      method: 'GET',
      endpoint: '/subscriptions',
      queryParams: queryParams,
    );
  }

  /// Fetch a Subscription With ID
  /// https://razorpay.com/docs/api/subscriptions/#fetch-a-subscription-by-id
  Future<Map<String, dynamic>> fetchSubscriptionById(String subscriptionId) async {
    return await _makeRequest(
      method: 'GET',
      endpoint: '/subscriptions/$subscriptionId',
    );
  }

  /// Cancel a Subscription
  /// https://razorpay.com/docs/api/subscriptions/#cancel-a-subscription
  Future<Map<String, dynamic>> cancelSubscription(
    String subscriptionId, {
    bool? cancelAtCycleEnd,
  }) async {
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('🛑 CANCEL SUBSCRIPTION API CALL');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('Subscription ID: $subscriptionId');
    debugPrint('Cancel At Cycle End: $cancelAtCycleEnd');
    
    final body = <String, dynamic>{};
    if (cancelAtCycleEnd != null) {
      body['cancel_at_cycle_end'] = cancelAtCycleEnd ? 1 : 0;
    }

    debugPrint('Request Body: ${body.isNotEmpty ? jsonEncode(body) : "{}"}');
    debugPrint('Endpoint: /subscriptions/$subscriptionId/cancel');
    debugPrint('Method: POST');
    debugPrint('═══════════════════════════════════════════════════════════');

    return await _makeRequest(
      method: 'POST',
      endpoint: '/subscriptions/$subscriptionId/cancel',
      body: body.isNotEmpty ? body : null,
    );
  }

  /// Update a Subscription
  /// https://razorpay.com/docs/api/subscriptions/#update-a-subscription
  Future<Map<String, dynamic>> updateSubscription(
    String subscriptionId, {
    String? planId,
    int? quantity,
    DateTime? startAt,
    DateTime? expireBy,
    Map<String, dynamic>? notes,
    Map<String, dynamic>? offerId,
    bool? customerNotify,
  }) async {
    final body = <String, dynamic>{};
    if (planId != null) body['plan_id'] = planId;
    if (quantity != null) body['quantity'] = quantity;
    if (startAt != null) body['start_at'] = (startAt.millisecondsSinceEpoch / 1000).round();
    if (expireBy != null) body['expire_by'] = (expireBy.millisecondsSinceEpoch / 1000).round();
    if (notes != null) body['notes'] = notes;
    if (offerId != null) body['offer_id'] = offerId;
    if (customerNotify != null) body['customer_notify'] = customerNotify ? 1 : 0;

    return await _makeRequest(
      method: 'PATCH',
      endpoint: '/subscriptions/$subscriptionId',
      body: body,
    );
  }

  /// Fetch Details of a Pending Update
  /// https://razorpay.com/docs/api/subscriptions/#fetch-details-of-a-pending-update
  Future<Map<String, dynamic>> fetchPendingUpdate(String subscriptionId) async {
    return await _makeRequest(
      method: 'GET',
      endpoint: '/subscriptions/$subscriptionId/retrieve_scheduled_changes',
    );
  }

  /// Cancel an Update
  /// https://razorpay.com/docs/api/subscriptions/#cancel-an-update
  Future<Map<String, dynamic>> cancelUpdate(String subscriptionId) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '/subscriptions/$subscriptionId/cancel_scheduled_changes',
    );
  }

  /// Pause a Subscription
  /// https://razorpay.com/docs/api/subscriptions/#pause-a-subscription
  Future<Map<String, dynamic>> pauseSubscription(
    String subscriptionId, {
    DateTime? pauseAt,
  }) async {
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('⏸️ PAUSE SUBSCRIPTION API CALL');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('Subscription ID: $subscriptionId');
    debugPrint('Pause At: ${pauseAt?.toIso8601String() ?? "null (immediate)"}');
    
    final body = <String, dynamic>{};
    if (pauseAt != null) {
      body['pause_at'] = (pauseAt.millisecondsSinceEpoch / 1000).round();
      debugPrint('Pause At (Unix timestamp): ${body['pause_at']}');
    }

    debugPrint('Request Body: ${body.isNotEmpty ? jsonEncode(body) : "{}"}');
    debugPrint('Endpoint: /subscriptions/$subscriptionId/pause');
    debugPrint('Method: POST');
    debugPrint('═══════════════════════════════════════════════════════════');

    return await _makeRequest(
      method: 'POST',
      endpoint: '/subscriptions/$subscriptionId/pause',
      body: body.isNotEmpty ? body : null,
    );
  }

  /// Resume a Subscription
  /// https://razorpay.com/docs/api/subscriptions/#resume-a-subscription
  Future<Map<String, dynamic>> resumeSubscription(
    String subscriptionId, {
    DateTime? resumeAt,
  }) async {
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('▶️ RESUME SUBSCRIPTION API CALL');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('Subscription ID: $subscriptionId');
    debugPrint('Resume At: ${resumeAt?.toIso8601String() ?? "null (immediate)"}');
    
    final body = <String, dynamic>{};
    if (resumeAt != null) {
      body['resume_at'] = (resumeAt.millisecondsSinceEpoch / 1000).round();
      debugPrint('Resume At (Unix timestamp): ${body['resume_at']}');
    }

    debugPrint('Request Body: ${body.isNotEmpty ? jsonEncode(body) : "{}"}');
    debugPrint('Endpoint: /subscriptions/$subscriptionId/resume');
    debugPrint('Method: POST');
    debugPrint('═══════════════════════════════════════════════════════════');

    return await _makeRequest(
      method: 'POST',
      endpoint: '/subscriptions/$subscriptionId/resume',
      body: body.isNotEmpty ? body : null,
    );
  }

  /// Fetch All Invoices for a Subscription
  /// Uses the general invoices endpoint with subscription_id filter
  /// https://razorpay.com/docs/api/invoices/#fetch-all-invoices
  Future<Map<String, dynamic>> fetchSubscriptionInvoices(
    String subscriptionId, {
    int? count,
    int? skip,
  }) async {
    final queryParams = <String, String>{
      'subscription_id': subscriptionId,
    };
    if (count != null) queryParams['count'] = count.toString();
    if (skip != null) queryParams['skip'] = skip.toString();

    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('📄 FETCH SUBSCRIPTION INVOICES API CALL');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('Subscription ID: $subscriptionId');
    debugPrint('Query Params: $queryParams');
    debugPrint('Endpoint: /invoices');
    debugPrint('Method: GET');
    debugPrint('═══════════════════════════════════════════════════════════');

    return await _makeRequest(
      method: 'GET',
      endpoint: '/invoices',
      queryParams: queryParams,
    );
  }

  /// Link an Offer to a Subscription
  /// https://razorpay.com/docs/api/subscriptions/#link-an-offer-to-a-subscription
  Future<Map<String, dynamic>> linkOfferToSubscription(
    String subscriptionId,
    String offerId,
  ) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '/subscriptions/$subscriptionId/add_offer',
      body: {'offer_id': offerId},
    );
  }

  /// Delete an Offer Linked to a Subscription
  /// https://razorpay.com/docs/api/subscriptions/#delete-an-offer-linked-to-a-subscription
  Future<Map<String, dynamic>> deleteOfferFromSubscription(
    String subscriptionId,
    String offerId,
  ) async {
    return await _makeRequest(
      method: 'DELETE',
      endpoint: '/subscriptions/$subscriptionId/offers/$offerId',
    );
  }

  /// Fetch All Invoices (General)
  /// https://razorpay.com/docs/api/invoices/#fetch-all-invoices
  Future<Map<String, dynamic>> fetchAllInvoices({
    int? count,
    int? skip,
    String? paymentId,
    String? customerId,
    String? status,
  }) async {
    final queryParams = <String, String>{};
    if (count != null) queryParams['count'] = count.toString();
    if (skip != null) queryParams['skip'] = skip.toString();
    if (paymentId != null) queryParams['payment_id'] = paymentId;
    if (customerId != null) queryParams['customer_id'] = customerId;
    if (status != null) queryParams['status'] = status;

    return await _makeRequest(
      method: 'GET',
      endpoint: '/invoices',
      queryParams: queryParams,
    );
  }

  /// Fetch Invoice by ID
  /// https://razorpay.com/docs/api/invoices/#fetch-an-invoice-by-id
  Future<Map<String, dynamic>> fetchInvoiceById(String invoiceId) async {
    return await _makeRequest(
      method: 'GET',
      endpoint: '/invoices/$invoiceId',
    );
  }
}

