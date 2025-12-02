import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for Razorpay Invoice
class Invoice {
  final String id;
  final String invoiceNumber;
  final String? subscriptionId;
  final String? customerId;
  final String status; // issued, paid, cancelled, expired
  final int amount; // in paise
  final String currency;
  final String description;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? expiryDate;
  final Map<String, dynamic>? lineItems;
  final Map<String, dynamic>? notes;
  final Map<String, dynamic>? customerDetails;
  final Map<String, dynamic>? razorpayData; // Full Razorpay invoice data

  Invoice({
    required this.id,
    required this.invoiceNumber,
    this.subscriptionId,
    this.customerId,
    required this.status,
    required this.amount,
    this.currency = 'INR',
    required this.description,
    required this.createdAt,
    this.paidAt,
    this.expiryDate,
    this.lineItems,
    this.notes,
    this.customerDetails,
    this.razorpayData,
  });

  /// Get amount in rupees
  double get amountInRupees => amount / 100.0;

  /// Get formatted amount string
  String get formattedAmount => '₹${amountInRupees.toStringAsFixed(2)}';

  /// Check if invoice is paid
  bool get isPaid => status == 'paid';

  /// Check if invoice is expired
  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  factory Invoice.fromRazorpayData(Map<String, dynamic> data) {
    return Invoice(
      id: data['id'] as String,
      invoiceNumber: data['invoice_number'] as String? ?? data['id'] as String,
      subscriptionId: data['subscription_id'] as String?,
      customerId: data['customer_id'] as String?,
      status: data['status'] as String? ?? 'issued',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      currency: data['currency'] as String? ?? 'INR',
      description: data['description'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        ((data['created_at'] as int?) ?? (data['date'] as int?) ?? 0) * 1000,
      ),
      paidAt: data['paid_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch((data['paid_at'] as int) * 1000)
          : null,
      expiryDate: data['expiry_by'] != null
          ? DateTime.fromMillisecondsSinceEpoch((data['expiry_by'] as int) * 1000)
          : null,
      lineItems: data['line_items'] != null
          ? (data['line_items'] is List
              ? {'items': data['line_items']}
              : data['line_items'] as Map<String, dynamic>?)
          : null,
      notes: data['notes'] != null
          ? (data['notes'] is List
              ? {'items': data['notes']}
              : data['notes'] as Map<String, dynamic>?)
          : null,
      customerDetails: data['customer_details'] as Map<String, dynamic>?,
      razorpayData: data,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'subscriptionId': subscriptionId,
      'customerId': customerId,
      'status': status,
      'amount': amount,
      'currency': currency,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'lineItems': lineItems,
      'notes': notes,
      'customerDetails': customerDetails,
      'razorpayData': razorpayData,
    };
  }

  factory Invoice.fromFirestoreMap(Map<String, dynamic> data, String id) {
    return Invoice(
      id: id,
      invoiceNumber: data['invoiceNumber'] as String? ?? id,
      subscriptionId: data['subscriptionId'] as String?,
      customerId: data['customerId'] as String?,
      status: data['status'] as String? ?? 'issued',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      currency: data['currency'] as String? ?? 'INR',
      description: data['description'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      paidAt: data['paidAt'] != null ? (data['paidAt'] as Timestamp).toDate() : null,
      expiryDate: data['expiryDate'] != null ? (data['expiryDate'] as Timestamp).toDate() : null,
      lineItems: data['lineItems'] as Map<String, dynamic>?,
      notes: data['notes'] as Map<String, dynamic>?,
      customerDetails: data['customerDetails'] as Map<String, dynamic>?,
      razorpayData: data['razorpayData'] as Map<String, dynamic>?,
    );
  }
}

