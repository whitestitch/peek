// lib/features/premium/controllers/subscription_state.dart
// --- TEMPORARY PLAIN DART CLASS (Remove Freezed) ---

import 'package:flutter/foundation.dart'; // For immutable annotation
import 'package:in_app_purchase/in_app_purchase.dart';

@immutable // Good practice for state classes
class SubscriptionState {
  /// True when fetching product details or initiating purchase/restore
  final bool isLoading;

  /// Holds the details of the premium product fetched from the store
  final ProductDetails? premiumProduct;

  /// Holds error messages related to loading products or initiating actions
  final String? errorMessage;

  // Constructor with default values
  const SubscriptionState({
    this.isLoading = false,
    this.premiumProduct,
    this.errorMessage,
  });

  // Manual copyWith method (what freezed generates for you)
  SubscriptionState copyWith({
    bool? isLoading,
    ProductDetails? premiumProduct,
    String? errorMessage,
    bool clearError = false, // Keep helper for consistency
  }) {
    return SubscriptionState(
      isLoading: isLoading ?? this.isLoading,
      premiumProduct: premiumProduct ?? this.premiumProduct,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  // Optional: Add equality and hashCode for proper state comparison if needed
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubscriptionState &&
          runtimeType == other.runtimeType &&
          isLoading == other.isLoading &&
          premiumProduct == other.premiumProduct &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      isLoading.hashCode ^ premiumProduct.hashCode ^ errorMessage.hashCode;

  @override
  String toString() {
    return 'SubscriptionState(isLoading: $isLoading, premiumProduct: ${premiumProduct?.id}, errorMessage: $errorMessage)';
  }
}
// --- END OF PLAIN DART CLASS ---