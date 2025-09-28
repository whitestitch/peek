import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

// Import the state class
// import '../providers/subscription_state.dart';
// import 'subscription_state.dart';
import 'subscription_state.dart';

// Define your actual premium product ID here
// This MUST match the product ID configured in App Store Connect
const String premiumProductId = 'peek.premium.monthly';

// Additional product IDs for different subscription tiers (if needed)
const String premiumYearlyProductId = 'peek.premium.yearly';
const String premiumLifetimeProductId = 'peek.premium.lifetime';

class SubscriptionController extends StateNotifier<SubscriptionState> {
  final Ref ref; // Pass ref if needed to read other providers

  SubscriptionController(this.ref) : super(const SubscriptionState()) {
    _loadProduct(); // Load product details automatically
  }

  /// Fetches product details from the respective app store.
  Future<void> _loadProduct() async {
    // Avoid reloading if product already loaded or currently loading
    if (state.premiumProduct != null || state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    ); // Start loading
    debugPrint(
      "[SubscriptionController] Loading product details for ID: $premiumProductId",
    );

    try {
      final bool available = await InAppPurchase.instance.isAvailable();
      if (!available) throw Exception('In-App Purchases are not available.');

      final ProductDetailsResponse response = await InAppPurchase.instance
          .queryProductDetails(<String>{premiumProductId});

      if (response.error != null) {
        throw Exception('Error querying products: ${response.error!.message}');
      }
      if (response.notFoundIDs.contains(premiumProductId)) {
        throw Exception(
          'Premium product ID ($premiumProductId) not found in store.',
        );
      }
      if (response.productDetails.isEmpty) {
        throw Exception('No product details returned for $premiumProductId.');
      }

      final product = response.productDetails.first;
      state = state.copyWith(premiumProduct: product, isLoading: false);
      debugPrint(
        "[SubscriptionController] Product loaded: ${product.title} - ${product.price}",
      );
    } catch (e) {
      debugPrint("❌ [SubscriptionController] Error loading product: $e");
      state = state.copyWith(
        errorMessage: 'Failed to load subscription details. Please try again.',
        isLoading: false,
      );
    }
  }

  /// Initiates the purchase flow for the loaded premium product.
  Future<void> initiatePurchase() async {
    if (state.premiumProduct == null) {
      debugPrint(
        "❌ [SubscriptionController] Purchase attempted but product not loaded.",
      );
      state = state.copyWith(
        errorMessage: "Subscription details not available.",
      );
      _loadProduct(); // Attempt to reload product details
      return;
    }
    if (state.isLoading) {
      debugPrint(
        "[SubscriptionController] Purchase attempt ignored, already processing.",
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    debugPrint(
      "[SubscriptionController] Initiating purchase for ${state.premiumProduct!.id}...",
    );

    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: state.premiumProduct!,
    );

    try {
      // Start the purchase flow. The result is handled by the listener in _PeekAppState.
      final bool purchaseStarted =
          await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: purchaseParam,
      ); // Use non-consumable for subscriptions/unlocks
      debugPrint(
        "[SubscriptionController] buyNonConsumable returned: $purchaseStarted",
      );

      // Reset loading state *after* initiating. The stream listener handles the actual success/failure.
      state = state.copyWith(isLoading: false);

      if (!purchaseStarted) {
        // This often means another transaction is pending or IAP isn't ready.
        state = state.copyWith(
          errorMessage:
              "Could not start purchase. Check for pending transactions or restart the app.",
        );
      }
    } catch (e) {
      debugPrint(
        "❌ [SubscriptionController] Error initiating purchase flow: $e",
      );
      state = state.copyWith(
        isLoading: false,
        errorMessage: "An error occurred trying to start the purchase.",
      );
    }
  }

  /// Initiates the restore purchases flow.
  Future<void> restorePurchases() async {
    if (state.isLoading) return; // Prevent double taps
    state = state.copyWith(isLoading: true, errorMessage: null);
    debugPrint("[SubscriptionController] Restoring purchases...");
    try {
      await InAppPurchase.instance.restorePurchases();
      // Result/Updates are handled by the purchase stream listener in _PeekAppState
      // Reset loading *after* initiating the restore attempt.
      state = state.copyWith(isLoading: false);
      // Optionally show a temporary message like "Restore initiated..."
    } catch (e) {
      debugPrint("❌ [SubscriptionController] Error restoring purchases: $e");
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Failed to restore purchases.",
      );
    }
  }
}

/// Provider for the SubscriptionController.
final subscriptionControllerProvider =
    StateNotifierProvider<SubscriptionController, SubscriptionState>(
  (ref) => SubscriptionController(ref),
);
