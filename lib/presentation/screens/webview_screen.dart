import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../theme/app_colors.dart';
import '../../services/razorpay_subscription_service.dart';
import '../../services/premium_service.dart';
import '../../common/premium_constants.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const WebViewScreen({super.key, required this.url, required this.title});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  /// Check subscription status from Razorpay API
  Future<void> _checkSubscriptionStatus(String subscriptionId) async {
    try {
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('🔍 CHECKING SUBSCRIPTION STATUS');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('Subscription ID: $subscriptionId');
      
      final subscriptionService = RazorpaySubscriptionService.instance;
      final subscriptionData = await subscriptionService.fetchSubscriptionById(subscriptionId);
      
      debugPrint('📊 Subscription Status: ${subscriptionData['status']}');
      debugPrint('📊 Full Subscription Data: $subscriptionData');
      
      final status = subscriptionData['status'] as String?;
      
      debugPrint('📊 Subscription State: $status');
      debugPrint('📊 State Meanings:');
      debugPrint('   - created: Subscription created, waiting for authentication');
      debugPrint('   - authenticated: Payment completed, trial active (if applicable)');
      debugPrint('   - active: Billing cycle started');
      debugPrint('   - pending: Payment failed, retrying');
      debugPrint('   - halted: All retries exhausted');
      debugPrint('   - cancelled: Subscription cancelled');
      debugPrint('   - paused: Subscription paused');
      debugPrint('   - expired: Authentication not completed in time');
      debugPrint('   - completed: Subscription lifecycle ended');
      
      // Update Firestore for states that indicate payment was completed
      // created = not yet paid, so don't update
      // authenticated/active/pending = payment done, update Firestore
      if (status == 'active' || 
          status == 'authenticated' || 
          status == 'pending') {
        debugPrint('✅ Subscription payment completed! Status: $status');
        debugPrint('✅ Updating Firestore...');
        
        // Extract subscription details
        final planId = subscriptionData['plan_id'] as String?;
        final subscriptionType = _getSubscriptionTypeFromPlanId(planId);
        
        // Check if this is a trial subscription (has start_at in future)
        final startAt = subscriptionData['start_at'] as int?;
        final hasTrial = startAt != null && 
            DateTime.fromMillisecondsSinceEpoch(startAt * 1000).isAfter(DateTime.now());
        
        // Update subscription via PremiumService
        await PremiumService.instance.handlePaymentSuccess(
          paymentId: subscriptionId,
          orderId: subscriptionId,
          subscriptionType: subscriptionType,
          planId: planId ?? 'unknown',
          startTrial: hasTrial, // Check if start_at is in future (trial period)
          razorpaySubscriptionId: subscriptionId,
        );
        
        debugPrint('✅ Subscription updated in Firestore');
        
        // Close WebView after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            debugPrint('🚪 Closing WebView after successful subscription activation');
            Navigator.of(context).pop(true);
          }
        });
      } else if (status == 'created') {
        debugPrint('ℹ️ Subscription is in "created" state - waiting for payment');
        debugPrint('ℹ️ WebView will remain open for user to complete payment');
      } else {
        debugPrint('⚠️ Subscription status: $status');
        debugPrint('⚠️ This status may indicate an issue. Check subscription in Razorpay dashboard.');
      }
      
      debugPrint('═══════════════════════════════════════════════════════════');
    } catch (e) {
      debugPrint('❌ Error checking subscription status: $e');
    }
  }

  /// Get subscription type from plan ID
  String _getSubscriptionTypeFromPlanId(String? planId) {
    if (planId == null) return 'monthly';
    if (planId.contains('monthly') || planId == PremiumConstants.monthlyPlanId) {
      return 'monthly';
    } else if (planId.contains('yearly') || planId == PremiumConstants.yearlyPlanId) {
      return 'yearly';
    } else if (planId.contains('lifetime') || planId == PremiumConstants.lifetimePlanId) {
      return 'lifetime';
    }
    return 'monthly';
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading progress if needed
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });

            debugPrint('🌐 WebView navigating to: $url');

            // Check if this is the subscription page URL (api.razorpay.com/v1/t/subscriptions/sub_xxx)
            // Extract subscription ID and check status
            if (url.contains('api.razorpay.com/v1/t/subscriptions/')) {
              final subscriptionIdMatch = RegExp(r'/subscriptions/(sub_[a-zA-Z0-9]+)').firstMatch(url);
              if (subscriptionIdMatch != null) {
                final subscriptionId = subscriptionIdMatch.group(1);
                debugPrint('📋 Detected subscription page, Subscription ID: $subscriptionId');
                debugPrint('🔄 Checking subscription status...');
                
                // Check subscription status in background
                _checkSubscriptionStatus(subscriptionId!);
              }
            }

            // Check if this is a payment success redirect
            // Razorpay redirects back to subscription link after payment
            if ((url.contains('payment-success') ||
                    url.contains('payment_success') ||
                    url.contains('/success') ||
                    url.contains('status=success') ||
                    url.contains('paid=true') ||
                    url.contains('payment=success')) &&
                !url.contains('checkout.razorpay.com') &&
                !url.contains('rzp.io/rzp/')) {
              // This is likely a success redirect, wait for page to load then close
              debugPrint(
                '✅ Payment success detected in URL, closing WebView...',
              );
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  // Return to previous screen with success indicator
                  Navigator.of(context).pop(true);
                }
              });
            }
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });

            debugPrint('📄 Page finished loading: $url');

            // Check if we're back on the subscription link page after payment
            // This happens when Razorpay redirects back after successful payment
            if (url.contains('rzp.io/rzp/') &&
                !url.contains('checkout.razorpay.com')) {
              debugPrint(
                '🔄 Back on subscription link page, checking for payment success...',
              );

              // Wait a moment for the page to fully render
              Future.delayed(const Duration(seconds: 2), () {
                // Check for payment success indicators in the page
                _controller
                    .runJavaScriptReturningResult('''
                  (function() {
                    try {
                      var bodyText = document.body.innerText.toLowerCase();
                      var hasSuccess = bodyText.includes('payment successful') || 
                                       bodyText.includes('payment success') ||
                                       bodyText.includes('transaction successful') ||
                                       bodyText.includes('order successful') ||
                                       bodyText.includes('subscription activated') ||
                                       bodyText.includes('subscription active') ||
                                       bodyText.includes('paid') ||
                                       bodyText.includes('completed') ||
                                       document.querySelector('[class*="success"]') !== null ||
                                       document.querySelector('[id*="success"]') !== null ||
                                       document.querySelector('[class*="paid"]') !== null ||
                                       document.querySelector('[class*="complete"]') !== null;
                      return hasSuccess;
                    } catch(e) {
                      return false;
                    }
                  })();
                ''')
                    .then((result) {
                      debugPrint('🔍 Success check result: $result');
                      // If success detected, close the WebView
                      if (result != null &&
                          result.toString().toLowerCase().contains('true')) {
                        debugPrint(
                          '✅ Payment success detected in page content, closing WebView...',
                        );
                        Future.delayed(const Duration(seconds: 1), () {
                          if (mounted) {
                            Navigator.of(context).pop(true);
                          }
                        });
                      } else {
                        // If no success text found but we're back on subscription page after payment,
                        // assume payment might be complete and close after a delay
                        // The subscription status will be checked in premium_upgrade_screen
                        debugPrint(
                          'ℹ️ No success text found, but payment may be complete. Closing WebView to check subscription status.',
                        );
                        Future.delayed(const Duration(seconds: 3), () {
                          if (mounted) {
                            Navigator.of(context).pop(true);
                          }
                        });
                      }
                    })
                    .catchError((error) {
                      // Ignore JavaScript errors, but still close after delay
                      debugPrint('WebView JavaScript error: $error');
                      // Close WebView anyway to check subscription status
                      Future.delayed(const Duration(seconds: 3), () {
                        if (mounted) {
                          Navigator.of(context).pop(true);
                        }
                      });
                    });
              });
            } else if (!url.contains('checkout.razorpay.com')) {
              // Check for success on other pages (not checkout, not subscription link)
              _controller
                  .runJavaScriptReturningResult('''
                (function() {
                  try {
                    var bodyText = document.body.innerText.toLowerCase();
                    var hasSuccess = bodyText.includes('payment successful') || 
                                     bodyText.includes('payment success') ||
                                     bodyText.includes('transaction successful') ||
                                     bodyText.includes('order successful') ||
                                     bodyText.includes('subscription activated') ||
                                     document.querySelector('[class*="success"]') !== null ||
                                     document.querySelector('[id*="success"]') !== null;
                    return hasSuccess;
                  } catch(e) {
                    return false;
                  }
                })();
              ''')
                  .then((result) {
                    // If success detected, close the WebView
                    if (result != null &&
                        result.toString().toLowerCase().contains('true')) {
                      debugPrint(
                        '✅ Payment success detected, closing WebView...',
                      );
                      Future.delayed(const Duration(seconds: 1), () {
                        if (mounted) {
                          Navigator.of(context).pop(true);
                        }
                      });
                    }
                  })
                  .catchError((error) {
                    // Ignore JavaScript errors
                    debugPrint('WebView JavaScript error: $error');
                  });
            }
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _hasError = true;
              _errorMessage = error.description ?? 'Failed to load page';
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.of(
            context,
          ).pop(true), // Return true to indicate user closed
        ),
        actions: [
          // Add a "Done" button that appears after payment
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green),
            tooltip: 'Payment Complete',
            onPressed: () {
              // Close WebView and return success
              Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
      body: _hasError
          ? _buildErrorWidget()
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading) _buildLoadingWidget(),
              ],
            ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentGreen),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading ${widget.title}...',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              const Text(
                'Failed to Load Page',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                        _isLoading = true;
                      });
                      _controller.reload();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentGreen,
                      side: const BorderSide(color: AppColors.accentGreen),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
