// pricing_page.dart — FIXED VERSION

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:onlymens/auth/auth_service.dart';
import 'package:onlymens/core/apptheme.dart';
import 'package:onlymens/core/globals.dart';

class PricingPage extends StatefulWidget {
  const PricingPage({super.key});

  @override
  State<PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends State<PricingPage> {
  final InAppPurchase _iap = InAppPurchase.instance;
  late final StreamSubscription<List<PurchaseDetails>> _listener;

  bool _pending = false;
  List<ProductDetails> _products = [];
  ProductDetails? _selected;

  // Pending receipt if user is not logged in
  String? _pendingReceipt;
  String? _pendingProductId;

  @override
  void initState() {
    super.initState();
    _listener = _iap.purchaseStream.listen(_handlePurchaseUpdates);
    _initIAP();
    _checkExistingSubscription(); // Check on page load
  }

  @override
  void dispose() {
    _listener.cancel();
    super.dispose();
  }

  // --------------------------
  // CHECK EXISTING SUBSCRIPTION
  // --------------------------
  Future<void> _checkExistingSubscription() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    final sub = await AuthService.fetchSubscriptionForCurrentUser();
    if (sub != null) {
      final expiresMs = sub['expiresDateMs'] ?? 0;
      final isActive = expiresMs > DateTime.now().millisecondsSinceEpoch;

      if (isActive && mounted) {
        print('✅ Already has active subscription, redirecting to /streaks');
        context.go('/streaks');
      }
    }
  }

  // --------------------------
  // INIT STORE
  // --------------------------
  Future<void> _initIAP() async {
    final available = await _iap.isAvailable();
    if (!mounted || !available) return;

    final response = await _iap.queryProductDetails({
      "cleanmind_premium_monthly_subs",
      "cleanmind_premium_yearly",
    });

    if (!mounted) return;

    if (response.productDetails.isNotEmpty) {
      setState(() {
        _products = response.productDetails;
        _selected = _products.firstWhere(
          (p) => p.id.contains("monthly"),
          orElse: () => _products.first,
        );
      });
    } else {
      setState(() {
        _products = [
          ProductDetails(
            id: "cleanmind_premium_monthly_subs",
            title: "Monthly Plan",
            description: "Billed monthly",
            price: "\$6.99",
            rawPrice: 6.99,
            currencyCode: "USD",
          ),
          ProductDetails(
            id: "cleanmind_premium_yearly",
            title: "Yearly Plan",
            description: "Billed annually (save 35%)",
            price: "\$54.99",
            rawPrice: 54.99,
            currencyCode: "USD",
          ),
        ];
        _selected = _products.first;
      });
    }
  }

  // --------------------------
  // PURCHASE FLOW
  // --------------------------
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (!mounted) continue;

      if (p.status == PurchaseStatus.pending) {
        setState(() => _pending = true);
      }

      if (p.status == PurchaseStatus.error) {
        setState(() => _pending = false);
        _showError("Purchase failed: ${p.error?.message ?? 'Unknown error'}");
        continue;
      }

      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        final receipt = p.verificationData.serverVerificationData;

        _pendingReceipt = receipt;
        _pendingProductId = p.productID;

        final isLoggedIn = AuthService.currentUser != null;

        if (!isLoggedIn) {
          // User needs to log in first
          print(
            '⚠️ Purchase successful but user not logged in, prompting login',
          );
          final shouldLogin = await _askLoginDialog();
          if (shouldLogin && mounted) {
            // Navigate to auth screen
            context.go('/');
            // Note: After login, claimPendingIfNeeded will be called
          }
        } else {
          // User is logged in, claim receipt immediately
          await _claimReceipt();
        }

        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
      }
    }
  }

  // -------------------------
  // CLAIM AFTER LOGIN
  // -------------------------
  Future<void> claimPendingIfNeeded() async {
    print('🔍 Checking for pending receipt to claim...');
    if (_pendingReceipt != null && _pendingProductId != null) {
      print('📝 Found pending receipt, claiming now');
      await _claimReceipt();
    }
  }

  Future<void> _claimReceipt() async {
    if (!mounted ||
        _pendingReceipt == null ||
        _pendingProductId == null ||
        AuthService.currentUser == null) {
      print('❌ Cannot claim receipt: missing data or not logged in');
      return;
    }

    setState(() => _pending = true);

    print('🔐 Claiming receipt for user: ${AuthService.currentUser!.uid}');

    final ok = await AuthService.claimReceiptForCurrentUser(
      receiptData: _pendingReceipt!,
      productId: _pendingProductId!,
    );

    if (!mounted) return;

    if (ok) {
      print('✅ Receipt claimed successfully');
      _pendingReceipt = null;
      _pendingProductId = null;
      _success();
    } else {
      print('❌ Failed to validate purchase');
      _showError("Unable to validate purchase. Please contact support.");
    }

    setState(() => _pending = false);
  }

  // -------------------------
  // UI HELPERS
  // -------------------------
  Future<bool> _askLoginDialog() async {
    return (await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              "Sign in required",
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              "Your purchase was successful! Please sign in to activate your subscription.",
              style: TextStyle(color: AppColors.textMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  "Later",
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text(
                  "Sign in now",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        )) ??
        false;
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Purchase Failed',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
        ),
        content: Text(msg, style: const TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _success() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ Subscription activated successfully!"),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );

    // Navigate to main app
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        print('🚀 Navigating to /streaks after successful subscription');
        context.go("/streaks");
      }
    });
  }

  void _buy() {
    if (_selected == null) return;

    print('💳 Starting purchase for: ${_selected!.id}');

    final params = PurchaseParam(productDetails: _selected!);
    _iap.buyNonConsumable(purchaseParam: params);
    setState(() => _pending = true);
  }

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.text),
          onPressed: () {
            // If user has completed onboarding, allow them to go back
            final onboardingDone = prefs.getBool('onboarding_done') ?? false;
            if (onboardingDone) {
              context.go('/');
            } else {
              context.go('/onboarding');
            }
          },
        ),
      ),
      body: Stack(
        children: [
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
                const Text(
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
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () async {
                      await context.push('/');
                      // After returning from auth, try to claim pending receipt
                      await claimPendingIfNeeded();
                      // Check if subscription is now active
                      await _checkExistingSubscription();
                    },
                    child: const Text(
                      "Already have an account? Log in",
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        color: AppColors.primary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
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
                onPressed: _pending || _selected == null ? null : _buy,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _pending
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
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPricingPlans() {
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
        ..._products.map((p) => _buildPlanTile(p)),
      ],
    );
  }

  Widget _buildPlanTile(ProductDetails p) {
    final isSelected = _selected?.id == p.id;
    return GestureDetector(
      onTap: () => setState(() => _selected = p),
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
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
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
          const Text(
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
            const Icon(
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
        const Text(
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
        const Center(
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
