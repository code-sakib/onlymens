import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:onlymens/core/apptheme.dart';

class PricingPage extends StatefulWidget {
  const PricingPage({super.key});

  @override
  State<PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends State<PricingPage> {
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  bool _isAvailable = false;
  bool _purchasePending = false;
  List<ProductDetails> _products = [];
  ProductDetails? _selectedProduct;

  @override
  void initState() {
    super.initState();
    _initializeIAP();
    _listenToPurchaseUpdates();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  // CRITICAL: Listen to purchase updates
  void _listenToPurchaseUpdates() {
    _subscription = _iap.purchaseStream.listen(
      (purchases) {
        _handlePurchaseUpdates(purchases);
      },
      onDone: () {
        _subscription.cancel();
      },
      onError: (error) {
        print('❌ Purchase stream error: $error');
        if (mounted) {
          setState(() => _purchasePending = false);
          _showError('Purchase failed. Please try again.');
        }
      },
    );
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      print('📦 Purchase Status: ${purchase.status}');

      if (purchase.status == PurchaseStatus.pending) {
        setState(() => _purchasePending = true);
      } else {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          // ✅ Purchase successful
          print('✅ Purchase successful: ${purchase.productID}');

          // TODO: Verify purchase with your backend here
          // await _verifyPurchase(purchase);

          if (mounted) {
            setState(() => _purchasePending = false);
            if (mounted) {
              setState(() => _purchasePending = false);
              context.go('/streaks'); // OR any page after subscription
            }
          }
        } else if (purchase.status == PurchaseStatus.error) {
          // ❌ Purchase failed
          print('❌ Purchase error: ${purchase.error}');
          if (mounted) {
            setState(() => _purchasePending = false);
            print('Purchase failed: ${purchase.error?.message}');
          }
        } else if (purchase.status == PurchaseStatus.canceled) {
          // User canceled
          print('⚠️ Purchase canceled');
          if (mounted) {
            setState(() => _purchasePending = false);
          }
        }

        // CRITICAL: Complete the purchase
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  Future<void> _initializeIAP() async {
    try {
      final available = await _iap.isAvailable();
      print('========== IAP INITIALIZATION ==========');
      print('✅ IAP Available: $available');

      if (!available) {
        print('❌ IAP not available on this device');
        setState(() => _isAvailable = false);
        return;
      }

      setState(() => _isAvailable = available);

      // CORRECTED Product IDs (removed 's' from monthly)
      const ids = {
        'cleanmind_premium_monthly_subs',
        'cleanmind_premium_yearly',
      };

      print('🔍 Querying products: $ids');

      final response = await _iap.queryProductDetails(ids);

      print('✅ Products found: ${response.productDetails.length}');
      print('❌ Products NOT found: ${response.notFoundIDs}');

      if (response.notFoundIDs.isNotEmpty) {
        print('⚠️ Missing Product IDs: ${response.notFoundIDs.join(", ")}');
      }

      for (var product in response.productDetails) {
        print('📦 Product Details:');
        print('   ID: ${product.id}');
        print('   Title: ${product.title}');
        print('   Price: ${product.price}');
        print('   Description: ${product.description}');
      }

      setState(() => _products = response.productDetails);

      if (_products.isNotEmpty) {
        _selectedProduct = _products.first; // Default to first product
        print('✅ Selected product: ${_selectedProduct?.id}');
      } else {
        print('❌ No products available');
      }

      print('========================================');
    } catch (e, stackTrace) {
      print('❌ IAP ERROR: $e');
      print('Stack trace: $stackTrace');
    }
  }

  void _onBuy(ProductDetails product) {
    if (_purchasePending) return;

    print('🛒 Initiating purchase for: ${product.id}');

    final purchaseParam = PurchaseParam(productDetails: product);

    // Use buyNonConsumable for subscriptions
    _iap.buyNonConsumable(purchaseParam: purchaseParam);

    setState(() => _purchasePending = true);
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Purchase Failed',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.text),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          // Scrollable content
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Unlock Premium",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Get full access to all premium features",
                  style: TextStyle(fontSize: 16, color: AppColors.textMuted),
                ),
                const SizedBox(height: 32),
                _buildFeaturesGrid(),
                const SizedBox(height: 36),
                _buildPricingPlans(),
                const SizedBox(height: 24),
                _buildTrialInfo(),
                const SizedBox(height: 32),
                _buildPriceBreakdown(),
              ],
            ),
          ),

          // Pinned continue button
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _purchasePending || _selectedProduct == null
                    ? null
                    : () => _onBuy(_selectedProduct!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _purchasePending
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            "Processing...",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        "Start 7-Day Free Trial",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesGrid() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildFeature(
            Icons.flash_on_rounded,
            "Complete Streak System",
            "Track daily, monthly & lifetime progress",
          ),
          const SizedBox(height: 16),
          _buildFeature(
            Icons.psychology_rounded,
            "Advanced AI Models",
            "Premium chat & voice capabilities",
          ),
          const SizedBox(height: 16),
          _buildFeature(
            Icons.people_rounded,
            "Community Access",
            "Connect with like-minded people",
          ),
          const SizedBox(height: 16),
          _buildFeature(
            Icons.lock_open_rounded,
            "No Restrictions",
            "Remove all paywalls & limits",
          ),
          const SizedBox(height: 16),
          _buildFeature(
            Icons.favorite_rounded,
            "Support Development",
            "Help us build better features",
          ),
        ],
      ),
    );
  }

  Widget _buildFeature(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPricingPlans() {
    final displayProducts = _products.isNotEmpty
        ? _products
        : [
            // Fallback products for display only
            ProductDetails(
              id: 'cleanmind_premium_monthly_subs',
              title: 'Monthly Plan',
              description: 'Billed monthly',
              price: '\$6.99',
              rawPrice: 6.99,
              currencyCode: 'USD',
            ),
            ProductDetails(
              id: 'cleanmind_premium_yearly',
              title: 'Yearly Plan',
              description: 'Billed annually (save 35%)',
              price: '\$54.99',
              rawPrice: 54.99,
              currencyCode: 'USD',
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Choose Your Plan",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 16),
        ...displayProducts.map((p) => _buildPlanTile(p)),
      ],
    );
  }

  Widget _buildPlanTile(ProductDetails p) {
    final isSelected = _selectedProduct?.id == p.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedProduct = p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.description,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  p.price,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  p.id.contains('yearly') ? '/year' : '/month',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrialInfo() {
    return Center(
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
              SizedBox(width: 8),
              Text(
                "7-Day Free Trial",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Cancel anytime. No commitment.",
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.account_balance_wallet_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 10),
            const Text(
              "Pricing breakdown",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Transparency of monthly costs",
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              _buildBreakdownRow(
                Icons.memory_rounded,
                "AI Models & Processing",
                "\$1.90",
                Colors.purple,
              ),
              const SizedBox(height: 14),
              _buildBreakdownRow(
                Icons.cloud_rounded,
                "Cloud Infrastructure",
                "\$1.50",
                Colors.blue,
              ),
              const SizedBox(height: 14),
              _buildBreakdownRow(
                Icons.settings_rounded,
                "Operations & Maintenance",
                "\$1.90",
                Colors.orange,
              ),
              const SizedBox(height: 14),
              _buildBreakdownRow(
                Icons.groups_rounded,
                "Small Team & Support",
                "\$1.70",
                Colors.green,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: AppColors.border, height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    "Total",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    "\$7.00",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            "You pay \$6.99/month • We operate on thin margins",
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(
    IconData icon,
    String label,
    String value,
    Color iconColor,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppColors.text),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}
