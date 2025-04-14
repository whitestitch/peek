import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  bool _loading = true;
  bool _isPremium = false;
  ProductDetails? _product;

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  Future<void> _initPage() async {
    await Future.wait([_checkPremiumStatus(), _loadProduct()]);
    setState(() {
      _loading = false;
    });
  }

  Future<void> _checkPremiumStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
    setState(() {
      _isPremium = doc.data()?['isPremium'] == true;
    });
  }

  Future<void> _loadProduct() async {
    const productIds = {'peek_premium_monthly'};
    final response = await InAppPurchase.instance.queryProductDetails(
      productIds,
    );

    if (response.notFoundIDs.isNotEmpty) {
      print('❌ Product not found: ${response.notFoundIDs}');
    }

    if (response.productDetails.isNotEmpty) {
      _product = response.productDetails.first;
    }
  }

  void _buy() {
    if (_product == null) return;
    final purchaseParam = PurchaseParam(productDetails: _product!);
    InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
  }

  void _restorePurchases() {
    InAppPurchase.instance.restorePurchases();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('🔄 Restore started')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('👑 Peek Premium'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Restore Purchase',
            onPressed: _restorePurchases,
          ),
        ],
      ),
      body: SafeArea(
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unlock Your Premium Powers',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'With Peek Premium, you get:',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      const _BenefitRow(text: 'Unlimited Peeking'),
                      const _BenefitRow(text: 'No Cooldowns'),
                      const _BenefitRow(text: 'Longer Image Views'),
                      const _BenefitRow(text: 'Replay Previous Peeks'),
                      const _BenefitRow(text: 'Location-Based Discovery'),
                      const _BenefitRow(text: 'More features coming soon...'),
                      const Spacer(),
                      if (_isPremium)
                        const Center(
                          child: Text(
                            '✅ You already have Premium!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      else if (_product != null)
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _buy,
                            icon: const Icon(Icons.star),
                            label: Text('Upgrade – ${_product!.price}'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              backgroundColor: Colors.deepPurple,
                              textStyle: const TextStyle(fontSize: 18),
                            ),
                          ),
                        )
                      else
                        const Center(child: Text('❌ Failed to load product')),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final String text;
  const _BenefitRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.deepPurple),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
