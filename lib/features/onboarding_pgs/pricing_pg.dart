// pricing_page.dart — FINAL RESPONSIVE VERSION

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Added ScreenUtil
import 'package:cleanmind/auth/auth_service.dart';
import 'package:cleanmind/core/apptheme.dart';
import 'package:cleanmind/core/globals.dart';
import 'package:cleanmind/legal_screen.dart';
import 'package:cleanmind/utilis/snackbar.dart';

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

  String? _pendingReceipt;
  String? _pendingProductId;

  @override
  void initState() {
    super.initState();
    _listener = _iap.purchaseStream.listen(_handlePurchaseUpdates);
    _initIAP();
    _checkExistingSubscription();
    // Try to resume any pending purchase
    final savedReceipt = prefs.getString("pending_receipt");
    final savedProductId = prefs.getString("pending_product_id");

    if (savedReceipt != null && savedProductId != null) {
      _pendingReceipt = savedReceipt;
      _pendingProductId = savedProductId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        claimPendingIfNeeded();
      });
    }
  }

  @override
  void dispose() {
    _listener.cancel();
    super.dispose();
  }

  Future<void> _checkExistingSubscription() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    final sub = await AuthService.fetchSubscriptionForCurrentUser();
    if (sub != null) {
      final expiresMs = sub['expiresDateMs'] ?? 0;
      final isActive = expiresMs > DateTime.now().millisecondsSinceEpoch;

      if (isActive && mounted) {
        context.go('/streaks');
      }
    }
  }

  Future<void> _initIAP() async {
    final available = await _iap.isAvailable();
    if (!mounted || !available) return;

    final response = await _iap.queryProductDetails({
      "cleanmind_premium_monthly_users",
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
            id: "cleanmind_premium_monthly_users",
            title: "Monthly Plan",
            description: "Billed monthly",
            price: "\$6.99",
            rawPrice: 6.99,
            currencyCode: "USD",
          ),
          ProductDetails(
            id: "cleanmind_premium_yearly",
            title: "Yearly Plan",
            description: "Billed annually (save 46%)",
            price: "\$44.99",
            rawPrice: 44.99,
            currencyCode: "USD",
          ),
        ];
        _selected = _products.first;
      });
    }
  }

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

        // Save in memory
        _pendingReceipt = receipt;
        _pendingProductId = p.productID;

        // Save for app relaunch
        prefs.setString("pending_receipt", receipt);
        prefs.setString("pending_product_id", p.productID);

        final isLoggedIn = AuthService.currentUser != null;

        if (!isLoggedIn) {
          final shouldLogin = await _askLoginDialog();
          if (shouldLogin && mounted) {
            context.pop();
          }
        } else {
          await _claimReceipt();
        }

        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
      }
    }
  }

  Future<void> claimPendingIfNeeded() async {
    if (_pendingReceipt != null && _pendingProductId != null) {
      await _claimReceipt();
    }
  }

  Future<void> _claimReceipt() async {
    if (!mounted ||
        _pendingReceipt == null ||
        _pendingProductId == null ||
        AuthService.currentUser == null) {
      return;
    }

    setState(() => _pending = true);

    final ok = await AuthService.claimReceiptForCurrentUser(
      receiptData: _pendingReceipt!,
      productId: _pendingProductId!,
    );

    if (!mounted) return;

    if (ok) {
      _pendingReceipt = null;
      _pendingProductId = null;
      await _success();
    } else {
      _showError("Unable to validate purchase. Please contact support.");
    }

    setState(() => _pending = false);
  }

  Future<bool> _askLoginDialog() async {
    return (await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            title: Text(
              "Sign in required",
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
              ),
            ),
            content: Text(
              "Your purchase was successful! Please sign in to activate your subscription.",
              style: TextStyle(color: AppColors.textMuted, fontSize: 14.sp),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  "Later",
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14.sp),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: Text(
                  "Sign in now",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14.sp,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          'Purchase Failed',
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        content: Text(
          msg,
          style: TextStyle(color: AppColors.textMuted, fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: TextStyle(color: AppColors.primary, fontSize: 14.sp),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _success() async {
    await prefs.setBool('onboarding_done', true);

    // REMOVE pending receipt after successful claim
    prefs.remove("pending_receipt");
    prefs.remove("pending_product_id");

    if (mounted) {
      Utilis.showSnackBar("Subscribed successfully!");

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          context.go("/streaks");
        }
      });
    }
  }

  void _buy() {
    if (_selected == null) return;

    final params = PurchaseParam(productDetails: _selected!);
    _iap.buyNonConsumable(purchaseParam: params);
    setState(() => _pending = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppColors.text, size: 24.r),
          onPressed: () => context.go('/onboarding'),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            // Adapted padding to screenutil
            padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 100.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Unlock Premium",
                  style: TextStyle(
                    fontSize: 32.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  "Get full access to all premium features",
                  style: TextStyle(fontSize: 16.sp, color: AppColors.textMuted),
                ),
                SizedBox(height: 32.h),
                _buildFeaturesGrid(),
                SizedBox(height: 36.h),
                _buildPricingPlans(),
                SizedBox(height: 24.h),
                _buildTrialInfo(),
                SizedBox(height: 32.h),
                _buildPriceBreakdown(),
                SizedBox(height: 20.h),
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LegalScreen(),
                            ),
                          );
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12.sp,
                              ),
                              children: const [
                                TextSpan(text: "See our  "),
                                TextSpan(
                                  text: "Privacy Policy • Terms of Use",
                                  style: TextStyle(color: Colors.lightBlue),
                                ),
                                TextSpan(
                                  text:
                                      "  By continuing, you're agreeing to it. Don't worry, it's all good there.",
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          await context.push('/auth');
                        },
                        child: Text(
                          "Log in to restore your premium",
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Continue Button
          Positioned(
            left: 20.w,
            right: 20.w,
            bottom: 20.h,
            child: SizedBox(
              height: 56.h,
              child: ElevatedButton(
                onPressed: _pending || _selected == null ? null : _buy,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: _pending
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20.r,
                            height: 20.r,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            "Processing...",
                            style: TextStyle(
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        "Continue",
                        style: TextStyle(
                          fontSize: 17.sp,
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
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildFeature(
            Icons.flash_on_rounded,
            "Complete Streak System",
            "Track every second’s progress",
          ),
          SizedBox(height: 16.h),
          _buildFeature(
            Icons.psychology_rounded,
            "Advanced AI Models",
            "Premium chat & voice capabilities",
          ),
          SizedBox(height: 16.h),
          _buildFeature(
            Icons.people_rounded,
            "Community Access",
            "People on the same journey",
          ),
          SizedBox(height: 16.h),
          _buildFeature(
            Icons.lock_open_rounded,
            "No Restrictions",
            "No ads. No paywalls. No distractions.",
          ),
          SizedBox(height: 16.h),
          _buildFeature(
            Icons.favorite_rounded,
            "Support Indie Developer ❣️",
            null,
          ),
        ],
      ),
    );
  }

  Widget _buildFeature(IconData icon, String title, String? subtitle) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10.r),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(icon, color: AppColors.primary, size: 24.r),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 2.h),
              subtitle != null
                  ? Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13.sp,
                      ),
                    )
                  : const SizedBox.shrink(),
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
        Text(
          "Choose Your Plan",
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        SizedBox(height: 16.h),
        ..._products.map((p) => _buildPlanTile(p)),
      ],
    );
  }

  Widget _buildPlanTile(ProductDetails p) {
    final isSelected = _selected?.id == p.id;
    return GestureDetector(
      onTap: () => setState(() => _selected = p),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(18.r),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2.w : 1.w,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24.r, // Using .r for circle to keep aspect ratio
              height: 24.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                  width: 2.w,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12.r,
                        height: 12.r,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.title,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    p.description,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13.sp,
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
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  p.id.contains('yearly') ? '/year' : '/month',
                  style: TextStyle(fontSize: 12.sp, color: AppColors.textMuted),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 18.r),
              SizedBox(width: 8.w),
              Text(
                "7-Day Free Trial",
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            "Cancel anytime. No commitment.",
            style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdown() {
    const double total = 6.99;
    final amounts = [1.88, 1.51, 1.85, 1.75];

    final items = [
      {
        'icon': Icons.memory_rounded,
        'label': 'AI models & processing',
        'color': Colors.purple,
      },
      {
        'icon': Icons.cloud_rounded,
        'label': 'Cloud infrastructure',
        'color': Colors.blue,
      },
      {
        'icon': Icons.settings_rounded,
        'label': 'Operations & maintenance',
        'color': Colors.orange,
      },
      {
        'icon': Icons.people_rounded,
        'label': 'Small team & support',
        'color': Colors.green,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.account_balance_wallet_rounded,
              color: AppColors.primary,
              size: 22.r,
            ),
            SizedBox(width: 10.w),
            Text(
              "Pricing breakdown",
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Text(
          "We want to stay transparent with you",
          style: TextStyle(fontSize: 13.sp, color: AppColors.textMuted),
        ),
        SizedBox(height: 16.h),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.border),
          ),
          padding: EdgeInsets.all(18.r),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                _buildBreakdownRow(
                  items[i]['icon'] as IconData,
                  items[i]['label'] as String,
                  "\$${amounts[i].toStringAsFixed(2)}",
                  items[i]['color'] as Color,
                ),
                if (i != items.length - 1) SizedBox(height: 14.h),
              ],
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Divider(color: AppColors.border, height: 1.h),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Total",
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    "\$${total.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
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
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, color: iconColor, size: 20.r),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14.sp, color: AppColors.text),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}
