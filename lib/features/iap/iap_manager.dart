import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Manages all In-App Purchase functionality
class IAPManager {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  final GlobalKey<NavigatorState> navigatorKey;

  IAPManager({required this.navigatorKey});

  /// Initialize IAP listener
  Future<void> initialize() async {
    final bool available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      debugPrint("⚠️ IAP is not available on this device/platform.");
      return;
    }

    _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
      (purchaseDetailsList) => _handlePurchaseUpdates(purchaseDetailsList),
      onDone: () {
        debugPrint('🛒 Purchase stream closed');
        _purchaseSubscription?.cancel();
      },
      onError: (error) => debugPrint('❌ Purchase stream error: $error'),
      cancelOnError: false,
    );
    debugPrint("✅ IAP Purchase stream listener attached.");
  }

  /// Dispose of resources
  void dispose() {
    _purchaseSubscription?.cancel();
    debugPrint(
        '🛒 Purchase stream subscription cancelled in IAPManager dispose.');
  }

  /// Process incoming purchase updates
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    debugPrint("🛒 Handling ${purchases.length} purchase updates.");

    for (final purchase in purchases) {
      debugPrint(
        "🛒 Processing purchase: ${purchase.productID}, Status: ${purchase.status}, Error: ${purchase.error?.message}",
      );

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _handleSuccessfulPurchase(purchase);
          break;
        case PurchaseStatus.error:
          await _handlePurchaseError(purchase);
          break;
        case PurchaseStatus.pending:
          debugPrint('⏳ Purchase pending: ${purchase.productID}');
          break;
        case PurchaseStatus.canceled:
          await _handlePurchaseCanceled(purchase);
          break;
      }
    }
  }

  /// Handle successful purchase or restore
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    debugPrint(
        "🛒 [IAPManager] Processing successful purchase: ${purchase.productID}");
    debugPrint("🛒 [IAPManager] Purchase ID: ${purchase.purchaseID}");
    debugPrint(
        "🛒 [IAPManager] Pending complete: ${purchase.pendingCompletePurchase}");

    // Use server-side validation for iOS, direct grant for Android
    final bool grantSuccess;
    if (Platform.isIOS) {
      grantSuccess = await _validateAndGrantPremiumAccess(purchase);
    } else {
      // For Android, use the existing direct grant (Google Play handles validation)
      grantSuccess = await _grantPremiumAccessDirect(purchase);
    }

    if (purchase.pendingCompletePurchase) {
      if (grantSuccess) {
        try {
          // Complete the purchase transaction
          await InAppPurchase.instance.completePurchase(purchase);
          debugPrint(
              "✅ [IAPManager] Purchase transaction completed: ${purchase.purchaseID}");

          // Log analytics event
          await _logPurchaseEvent(purchase);

          // Small delay to ensure Firestore has propagated
          await Future.delayed(const Duration(milliseconds: 500));

          // Show success dialog
          _showPremiumSuccessDialog(purchase.status == PurchaseStatus.restored);
        } catch (e) {
          debugPrint("❌ [IAPManager] Error completing purchase: $e");
          _showPurchaseErrorDialog(
              "Failed to finalize purchase. Restart app or contact support if status hasn't updated.");
        }
      } else {
        debugPrint(
            "⚠️ [IAPManager] Validation/grant failed, NOT completing purchase: ${purchase.purchaseID}");
        // Don't complete the purchase if grant failed - this allows retry
        _showPurchaseErrorDialog(
            "Failed to validate purchase. Please check connection and try again, or use 'Restore Purchases'.");
      }
    } else {
      debugPrint(
          "🛒 [IAPManager] Purchase already completed, no action needed");
      if (purchase.status == PurchaseStatus.restored && grantSuccess) {
        await _logPurchaseEvent(purchase);
        _showRestoreSuccessDialog();
      }
    }
  }

  /// Handle purchase errors
  Future<void> _handlePurchaseError(PurchaseDetails purchase) async {
    debugPrint(
        '❌ Purchase error for ${purchase.productID}: ${purchase.error?.message} (Code: ${purchase.error?.code})');

    await _analytics.logEvent(
      name: 'purchase_failed',
      parameters: {
        'product_id': purchase.productID,
        'error_code': purchase.error?.code ?? 'UNKNOWN',
        'error_message':
            (purchase.error?.message ?? 'Unknown error').substring(0, 99),
      },
    );

    _showPurchaseErrorDialog(purchase.error);
    if (purchase.pendingCompletePurchase) {
      try {
        await InAppPurchase.instance.completePurchase(purchase);
      } catch (e) {
        // Ignore completion error for failed purchases
      }
    }
  }

  /// Handle canceled purchases
  Future<void> _handlePurchaseCanceled(PurchaseDetails purchase) async {
    debugPrint('🚫 Purchase cancelled by user: ${purchase.productID}');

    await _analytics.logEvent(
      name: 'purchase_cancelled',
      parameters: {'product_id': purchase.productID},
    );

    if (purchase.pendingCompletePurchase) {
      try {
        await InAppPurchase.instance.completePurchase(purchase);
      } catch (e) {
        // Ignore completion error for canceled purchases
      }
    }
  }

  /// Validate Apple receipt and grant premium access via Cloud Function
  ///
  /// This implements Apple's recommended validation approach:
  /// 1. Send receipt to server (Cloud Function)
  /// 2. Server validates against production App Store first
  /// 3. If status 21007 returned, server retries with sandbox
  /// 4. Only grants premium access after successful validation
  Future<bool> _validateAndGrantPremiumAccess(PurchaseDetails purchase) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint(
          "⚠️ [IAPManager] Cannot validate: User is null during validation attempt.");
      return false;
    }

    // Extract receipt data from the purchase
    final receiptData = purchase.verificationData.serverVerificationData;
    if (receiptData.isEmpty) {
      debugPrint(
          "⚠️ [IAPManager] No receipt data available for validation.");
      // Fall back to direct grant if no receipt data (shouldn't happen normally)
      return _grantPremiumAccessDirect(purchase);
    }

    debugPrint(
        "🧾 [IAPManager] Validating receipt with server for product: ${purchase.productID}");

    // Retry logic: try up to 3 times with delays
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        debugPrint(
            "🧾 [IAPManager] Attempt $attempt/3: Calling validateAppleReceipt");

        final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
            .httpsCallable('validateAppleReceipt');

        final result = await callable.call({
          'receiptData': receiptData,
          'productId': purchase.productID,
          'purchaseId': purchase.purchaseID,
          'transactionDate': purchase.transactionDate,
        });

        final data = result.data as Map<String, dynamic>;
        final success = data['success'] as bool? ?? false;
        final environment = data['environment'] as String? ?? 'unknown';

        if (success) {
          debugPrint(
              "✅ [IAPManager] Receipt validated successfully! Environment: $environment");
          return true;
        } else {
          debugPrint(
              "⚠️ [IAPManager] Validation returned success=false: ${data['message']}");
          return false;
        }
      } on FirebaseFunctionsException catch (e) {
        debugPrint(
            "❌ [IAPManager] Attempt $attempt/3 - Firebase Functions error: ${e.code} - ${e.message}");

        // If this wasn't the last attempt, wait before retrying
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: attempt)); // 1s, then 2s delay
          debugPrint("🔄 [IAPManager] Retrying validation in ${attempt}s...");
        }
      } catch (e) {
        debugPrint(
            "❌ [IAPManager] Attempt $attempt/3 - Unexpected error during validation: $e");

        // If this wasn't the last attempt, wait before retrying
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: attempt));
          debugPrint("🔄 [IAPManager] Retrying validation in ${attempt}s...");
        }
      }
    }

    debugPrint("❌ [IAPManager] All 3 validation attempts failed");
    return false;
  }

  /// Grant premium access directly in Firestore (for Android or fallback)
  Future<bool> _grantPremiumAccessDirect(PurchaseDetails purchase) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint(
          "⚠️ [IAPManager] Cannot grant premium: User is null during grant attempt.");
      return false;
    }

    // Retry logic: try up to 3 times with delays
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        debugPrint(
            "🛒 [IAPManager] Attempt $attempt/3: Granting premium to user $uid");

        await FirebaseFirestore.instance.collection('users').doc(uid).set(
          {
            'isPremium': true,
            'premiumPlanId': purchase.productID,
            'premiumGrantedAt': FieldValue.serverTimestamp(),
            'lastPurchaseId': purchase.purchaseID,
            'lastPurchaseTimestamp': purchase.transactionDate != null
                ? Timestamp.fromMillisecondsSinceEpoch(
                    int.parse(purchase.transactionDate!))
                : null,
          },
          SetOptions(merge: true),
        );

        debugPrint(
            "✅ [IAPManager] Premium status updated in Firestore for user $uid (attempt $attempt)");
        return true;
      } catch (e) {
        debugPrint(
            "❌ [IAPManager] Attempt $attempt/3 failed to update Firestore for premium grant ${purchase.productID}: $e");

        // If this wasn't the last attempt, wait before retrying
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: attempt)); // 1s, then 2s delay
          debugPrint("🔄 [IAPManager] Retrying in ${attempt}s...");
        }
      }
    }

    debugPrint("❌ [IAPManager] All 3 attempts failed to grant premium access");
    return false;
  }

  /// Log purchase event to analytics
  Future<void> _logPurchaseEvent(PurchaseDetails purchase) async {
    try {
      await _analytics.logEvent(
        name: purchase.status == PurchaseStatus.restored
            ? 'purchase_restored'
            : 'purchase',
        parameters: {
          'transaction_id': purchase.purchaseID ?? 'UNKNOWN_ID',
          'value': 0.0,
          'currency': 'USD',
          'item_id': purchase.productID,
          'item_name': purchase.productID,
          'quantity': 1,
        },
      );
      debugPrint("[IAPManager] Logged purchase event.");
    } catch (e) {
      debugPrint("Error logging purchase event: $e");
    }
  }

  /// Show premium success dialog
  void _showPremiumSuccessDialog(bool isRestore) {
    _showDialogIfMounted(
      (dialogContext) => AlertDialog(
        title: Text(isRestore ? "Premium Restored!" : "Premium Activated!"),
        content: const Text("🎉 You now have unlimited access to Peek!"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(); // Close dialog
              // Try to pop the premium page if we're on it
              final currentContext = navigatorKey.currentContext;
              if (currentContext != null && Navigator.canPop(currentContext)) {
                Navigator.of(currentContext).pop(); // Go back to previous page
              }
            },
            child: const Text("Awesome!"),
          ),
        ],
      ),
    );
  }

  /// Show restore success dialog
  void _showRestoreSuccessDialog() {
    _showDialogIfMounted(
      (dialogContext) => AlertDialog(
        title: const Text("Purchases Restored"),
        content:
            const Text("✅ Your existing premium access has been restored."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  /// Show purchase error dialog
  void _showPurchaseErrorDialog(Object? errorDetails) {
    String title = "Purchase Error";
    String message = "An unknown error occurred. Please try again later.";

    if (errorDetails is IAPError) {
      switch (errorDetails.code) {
        case 'user_cancelled':
          message = "The purchase was cancelled.";
          break;
        case 'payment_declined':
        case 'billing_unavailable':
        case 'payment_invalid':
          message =
              "Payment failed. Please check your payment method or try again later.";
          break;
        case 'item_unavailable':
        case 'item_already_owned':
          message = "This item is currently unavailable or already owned.";
          break;
        case 'store_network_error':
        case 'network_error':
          message =
              "Could not connect to the store. Please check your connection and try again.";
          break;
        case 'developer_error':
          message = "A configuration error occurred. Please contact support.";
          break;
        default:
          message =
              "An error occurred during the purchase (${errorDetails.code}). Please try again.";
          break;
      }
    } else if (errorDetails is String) {
      message = errorDetails;
    }

    _showDialogIfMounted(
      (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  /// Show dialog if context is available
  void _showDialogIfMounted(Widget Function(BuildContext) builder) {
    final BuildContext? context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint("⚠️ Cannot show dialog: Context not available");
      return;
    }

    try {
      showDialog(
        context: context,
        builder: builder,
        barrierDismissible: false,
      );
    } catch (e) {
      debugPrint("⚠️ Error showing dialog: $e");
    }
  }
}
