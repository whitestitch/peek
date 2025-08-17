import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    final bool grantSuccess = await _grantPremiumAccess(purchase);

    if (purchase.pendingCompletePurchase) {
      if (grantSuccess) {
        try {
          await InAppPurchase.instance.completePurchase(purchase);
          debugPrint("✅ Purchase completed: ${purchase.purchaseID}");

          await _logPurchaseEvent(purchase);
          _showPremiumSuccessDialog(purchase.status == PurchaseStatus.restored);
        } catch (e) {
          debugPrint("❌ Error completing purchase: $e");
          _showPurchaseErrorDialog(
              "Failed to finalize purchase. Restart app or contact support if status hasn't updated.");
        }
      } else {
        debugPrint(
            "⚠️ Firestore grant failed, NOT completing purchase: ${purchase.purchaseID}");
        _showPurchaseErrorDialog(
            "Failed to save premium status. Please check connection or contact support.");
      }
    } else {
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

  /// Grant premium access in Firestore
  Future<bool> _grantPremiumAccess(PurchaseDetails purchase) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint("⚠️ Cannot grant premium: User is null during grant attempt.");
      return false;
    }

    try {
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
      debugPrint("✅ Premium status updated in Firestore for user $uid");
      return true;
    } catch (e) {
      debugPrint(
          "❌ Failed to update Firestore for premium grant ${purchase.productID}: $e");
      return false;
    }
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
            onPressed: () => Navigator.of(dialogContext).pop(),
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
