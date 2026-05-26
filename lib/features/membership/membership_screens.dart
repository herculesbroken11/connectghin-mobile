import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/network/api_user_message.dart';
import '../../core/widgets/cg_outline_button.dart';
import '../../core/widgets/cg_primary_button.dart';
import '../../core/widgets/cg_responsive_container.dart';
import '../subscriptions/data/subscriptions_api.dart';
import '../subscriptions/iap_product_config.dart';

/// Display strings aligned with membership mockups (actual charge is provided by in-app purchase products).
const String kPremiumMonthlyDisplay = '\$19.99';
const String kPremiumYearlyDisplay = '\$79.99';
const String kRenewMonthlyDisplay = '\$9.99';

String _formatUiDate(DateTime d) {
  const months = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

String _monthYear(DateTime d) {
  const months = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.year}';
}

DateTime? _parseIso(dynamic v) {
  if (v == null) return null;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

List<(String, String)> get _upgradeBenefits => const [
      ('Unlimited Swipes', 'No daily limit — swipe as much as you want'),
      ('Message Anyone', 'Send messages without matching first'),
      ('Priority in Discovery', 'Get seen by more golfers in your area'),
      ('Advanced Filters', 'Filter by skill level, distance, and more'),
      ('Priority Support', 'Get help faster with premium support'),
      ('Profile Boost', 'Appear first in discovery for 30 minutes daily'),
    ];

List<(String, String)> get _manageBenefits => const [
      ('Unlimited Swipes', 'No daily limit — swipe as much as you want'),
      ('Message Anyone', 'Send messages without matching first'),
      ('Priority in Discovery', 'Get seen by more golfers in your area'),
      ('Advanced Filters', 'Filter by skill level, distance, and more'),
    ];

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  bool _loading = true;
  bool _storeLoading = true;
  String? _storeError;
  ProductDetails? _monthlyProduct;
  ProductDetails? _yearlyProduct;
  String? _membershipType;
  String? _membershipStatus;
  Map<String, dynamic>? _subscription;
  bool _yearlyIapSelected = true;
  bool _purchaseBusy = false;
  bool _cancelBusy = false;

  @override
  void initState() {
    super.initState();
    _purchaseSub = _iap.purchaseStream.listen(_onPurchaseUpdates);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    WidgetsBinding.instance.addPostFrameCallback((_) => _initStoreProducts());
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    setState(() => _loading = true);
    try {
      final me = await session.authApi.me(t);
      final sub = await SubscriptionsApi(session.apiClient).me(t);
      if (!mounted) return;
      setState(() {
        _membershipType = me['membershipType']?.toString();
        _membershipStatus = me['membershipStatus']?.toString();
        _subscription = sub;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isPremiumActive {
    final t = _membershipType;
    final s = _membershipStatus;
    return t == 'PREMIUM' && (s == 'ACTIVE' || s == 'TRIALING');
  }

  String get _monthlyPriceLabel => _monthlyProduct?.price ?? kPremiumMonthlyDisplay;

  String get _yearlyPriceLabel => _yearlyProduct?.price ?? kPremiumYearlyDisplay;

  Future<void> _initStoreProducts() async {
    try {
      final available = await _iap.isAvailable();
      if (!available) {
        setState(() {
          _storeLoading = false;
          _storeError = 'In-app purchases are not available on this device.';
        });
        return;
      }
      final ids = IapProductConfig.allIds;
      final response = await _iap.queryProductDetails(ids);
      if (!mounted) return;
      ProductDetails? byId(String id) {
        for (final p in response.productDetails) {
          if (p.id == id) return p;
        }
        return null;
      }
      final monthly = byId(IapProductConfig.monthlyProductId);
      final yearly = byId(IapProductConfig.yearlyProductId);
      String? err = response.error?.message;
      if (response.notFoundIDs.isNotEmpty) {
        final missing = response.notFoundIDs.join(', ');
        final emulatorHint = Platform.isAndroid
            ? ' LDPlayer/emulators need Google Play and published subscription products.'
            : '';
        err =
            'Products not found in store: $missing. In Play Console (app com.connectghin.app), create subscriptions with these exact product IDs, activate them, and use a licensed test account.$emulatorHint';
      } else if (monthly == null && yearly == null) {
        err ??=
            'No subscription products returned. Add ${IapProductConfig.monthlyProductId} and ${IapProductConfig.yearlyProductId} in Google Play Console.';
      }
      setState(() {
        _monthlyProduct = monthly;
        _yearlyProduct = yearly;
        _storeError = err;
        _storeLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _storeLoading = false;
        _storeError = 'Failed to load store products.';
      });
    }
  }

  Future<void> _startInAppPurchase() async {
    if (_storeLoading) return;
    final product = _yearlyIapSelected ? (_yearlyProduct ?? _monthlyProduct) : (_monthlyProduct ?? _yearlyProduct);
    if (product == null) {
      final msg = _storeError ??
          'No subscription product found. Expected IDs: '
          '${IapProductConfig.monthlyProductId}, ${IapProductConfig.yearlyProductId}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    setState(() => _purchaseBusy = true);
    final purchased = await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (!purchased && mounted) {
      setState(() => _purchaseBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start purchase. Try again.')),
      );
    }
  }

  Future<void> _restorePurchases() async {
    await _iap.restorePurchases();
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    final session = context.read<AuthSession>();
    final token = session.accessToken;
    if (token == null) return;

    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase pending confirmation…')),
          );
        }
        continue;
      }
      if (mounted && _purchaseBusy) {
        setState(() => _purchaseBusy = false);
      }
      if (purchase.status == PurchaseStatus.error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(purchase.error?.message ?? 'Purchase failed')),
          );
        }
      } else if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        try {
          final api = SubscriptionsApi(session.apiClient);
          if (Platform.isIOS) {
            final tx = purchase.purchaseID ?? purchase.verificationData.serverVerificationData;
            if (tx.isNotEmpty) {
              await api.verifyAppleEntitlement(token, transactionId: tx);
            }
          } else if (Platform.isAndroid) {
            final tokenStr = purchase.verificationData.serverVerificationData;
            if (tokenStr.isNotEmpty) {
              await api.verifyGoogleEntitlement(token, purchaseToken: tokenStr);
            }
          }
          session.bumpProfileRefresh();
          await _load();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Subscription updated successfully.')),
            );
          }
        } catch (e) {
          if (mounted) showApiErrorSnackBar(context, e);
        }
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _openStoreManagementHelp() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Manage subscriptions in Apple App Store or Google Play for your account.'),
      ),
    );
  }

  Future<void> _cancelAtPeriodEnd() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel subscription?'),
        content: const Text('You will keep premium until the end of the billing period. You can also manage billing in Apple App Store or Google Play.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Premium')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel', style: TextStyle(color: CgColors.red700))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _cancelBusy = true);
    try {
      await SubscriptionsApi(session.apiClient).cancel(t);
      if (mounted) {
        session.bumpProfileRefresh();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subscription will end after the current period.')));
        await _load();
      }
    } catch (e) {
      if (mounted) showApiErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _cancelBusy = false);
    }
  }

  static Widget _benefitCard(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CgColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CgColors.gray200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: CgColors.green600, shape: BoxShape.circle),
            child: const Icon(Icons.check, color: CgColors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: CgColors.gray900)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 13, color: CgColors.gray600, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _compareLine(String text, {bool premium = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check, size: 18, color: premium ? CgColors.green700 : CgColors.gray400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: premium ? CgColors.gray900 : CgColors.gray600, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subStatus = _subscription?['status']?.toString();
    final hasManagedSubscription = _subscription != null;
    final periodEnd = _parseIso(_subscription?['currentPeriodEnd']);
    final memberSince = _parseIso(_subscription?['createdAt']);
    final billingCycle = _subscription?['billingCycle']?.toString();
    final activePriceLine =
        billingCycle == 'YEARLY' ? '$_yearlyPriceLabel / year' : '$_monthlyPriceLabel / month';

    return Scaffold(
      backgroundColor: CgColors.gray50,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => context.pop()),
        title: Text(_isPremiumActive ? 'Membership' : 'Upgrade to Premium'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: CgColors.green700))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                if (!_isPremiumActive) ...[
                  const CgResponsiveContainer(
                    child: Text(
                      'Unlock the full ConnectGHIN experience',
                      style: TextStyle(fontSize: 15, color: CgColors.gray600),
                    ),
                  ),
                  const SizedBox(height: 20),
                  CgResponsiveContainer(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CgColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: CgColors.gray200),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: CgColors.gray200, borderRadius: BorderRadius.circular(6)),
                                  child: const Text('Current Plan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CgColors.gray700)),
                                ),
                                const SizedBox(height: 10),
                                const Text('Free', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: CgColors.gray900)),
                              ],
                            ),
                          ),
                          const Text('\$0 / month', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: CgColors.gray600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CgResponsiveContainer(
                    child: Material(
                      color: CgColors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => setState(() => _yearlyIapSelected = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: !_yearlyIapSelected ? CgColors.green700 : CgColors.gray200,
                              width: !_yearlyIapSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Monthly plan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CgColors.gray900)),
                                    const SizedBox(height: 8),
                                    Text(
                                      '$_monthlyPriceLabel / month',
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CgColors.gray900),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text('Cancel anytime', style: TextStyle(fontSize: 13, color: CgColors.gray600)),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(() => _yearlyIapSelected = false),
                                child: const Text('Choose'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CgResponsiveContainer(
                    child: Material(
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => setState(() => _yearlyIapSelected = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(colors: [CgColors.green700, CgColors.green900]),
                            border: Border.all(color: _yearlyIapSelected ? CgColors.green100 : Colors.transparent, width: 2),
                            boxShadow: [
                              if (_yearlyIapSelected)
                                BoxShadow(color: CgColors.green700.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 6)),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: CgColors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                                  child: const Text('Best value', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CgColors.white)),
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Annual plan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CgColors.white)),
                                        const SizedBox(height: 8),
                                        Text(
                                          '$_yearlyPriceLabel / year',
                                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CgColors.white),
                                        ),
                                        const SizedBox(height: 6),
                                        Text('Billed once per year in the app store', style: TextStyle(fontSize: 13, color: CgColors.white.withValues(alpha: 0.9))),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(foregroundColor: CgColors.green900, backgroundColor: CgColors.white),
                                    onPressed: () => setState(() => _yearlyIapSelected = true),
                                    child: const Text('Choose'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const CgResponsiveContainer(
                    child: Text('Free vs Premium', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: CgColors.gray900)),
                  ),
                  const SizedBox(height: 10),
                  CgResponsiveContainer(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: CgColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: CgColors.gray200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Free', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: CgColors.gray200, borderRadius: BorderRadius.circular(8)),
                                child: const Text('Current', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CgColors.gray700)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _compareLine('Basic profile & discovery'),
                          _compareLine('Limited messaging'),
                          _compareLine('Basic filters'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CgResponsiveContainer(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: CgColors.green700, width: 2),
                        color: CgColors.green50,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Premium', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: CgColors.green700, borderRadius: BorderRadius.circular(8)),
                                child: const Text('Upgrade', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CgColors.white)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _compareLine('Full discovery & advanced filters', premium: true),
                          _compareLine('See who likes you & message anyone', premium: true),
                          _compareLine('GHIN tools & premium badge', premium: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const CgResponsiveContainer(
                    child: Text('Premium Benefits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: CgColors.gray900)),
                  ),
                  const SizedBox(height: 12),
                  ..._upgradeBenefits.map((b) => CgResponsiveContainer(child: _benefitCard(b.$1, b.$2))),
                  const SizedBox(height: 12),
                  CgResponsiveContainer(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: CgColors.blue50, borderRadius: BorderRadius.circular(10)),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shopping_bag_outlined, size: 20, color: CgColors.blue700),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Subscriptions are purchased and renewed through Apple App Store or Google Play. Manage or cancel anytime in your store account settings.',
                              style: TextStyle(fontSize: 12, color: CgColors.blue700, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CgResponsiveContainer(
                    child: CgPrimaryButton(
                      label: _purchaseBusy ? 'Opening store…' : 'Subscribe with App Store / Google Play',
                      onPressed: _purchaseBusy || _storeLoading ? null : _startInAppPurchase,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CgResponsiveContainer(
                    child: CgOutlineButton(
                      label: 'Restore Purchases',
                      onPressed: _storeLoading ? null : _restorePurchases,
                    ),
                  ),
                  const SizedBox(height: 14),
                  CgResponsiveContainer(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: CgColors.green50, borderRadius: BorderRadius.circular(14)),
                      child: const Column(
                        children: [
                          Text('7-day free trial for eligible new subscribers', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CgColors.green900)),
                          SizedBox(height: 6),
                          Text('Offer depends on App Store / Play policies for this product.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: CgColors.green800, height: 1.35)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CgResponsiveContainer(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: CgColors.blue50, borderRadius: BorderRadius.circular(14)),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 20, color: CgColors.blue700),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'After purchase, ConnectGHIN syncs your membership from the receipt your device shares with our servers.',
                              style: TextStyle(fontSize: 12, color: CgColors.blue700, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const CgResponsiveContainer(
                    child: Text(
                      'By subscribing, you agree to our Terms of Service',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: CgColors.gray500),
                    ),
                  ),
                ] else ...[
                  CgResponsiveContainer(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(colors: [CgColors.green800, CgColors.green900]),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: CgColors.green100, borderRadius: BorderRadius.circular(20)),
                                child: const Text('Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CgColors.green900)),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: CgColors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                                child: const Icon(Icons.check, color: CgColors.white, size: 20),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text('Premium', style: TextStyle(color: CgColors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                          Text(activePriceLine, style: TextStyle(color: CgColors.white.withValues(alpha: 0.95), fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 20),
                          Container(height: 1, color: CgColors.white.withValues(alpha: 0.25)),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Member since', style: TextStyle(color: CgColors.white.withValues(alpha: 0.85), fontSize: 13)),
                              Text(memberSince != null ? _monthYear(memberSince) : '—', style: const TextStyle(color: CgColors.white, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Next renewal', style: TextStyle(color: CgColors.white.withValues(alpha: 0.85), fontSize: 13)),
                              Text(periodEnd != null ? _formatUiDate(periodEnd) : '—', style: const TextStyle(color: CgColors.white, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          if (subStatus != null) ...[
                            const SizedBox(height: 8),
                            Text('Status: $subStatus', style: TextStyle(color: CgColors.white.withValues(alpha: 0.75), fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const CgResponsiveContainer(
                    child: Text('Manage your premium subscription', style: TextStyle(fontSize: 14, color: CgColors.gray600)),
                  ),
                  const SizedBox(height: 16),
                  const CgResponsiveContainer(
                    child: Text('Subscription management', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: CgColors.gray900)),
                  ),
                  const SizedBox(height: 10),
                  if (hasManagedSubscription) ...[
                    CgResponsiveContainer(child: _billingTile(Icons.storefront, 'Manage Subscription', 'Open Apple / Google subscription management', _openStoreManagementHelp)),
                    CgResponsiveContainer(child: _billingTile(Icons.receipt_long, 'Purchase History', 'View purchases in your app store account', _openStoreManagementHelp)),
                  ] else
                    const CgResponsiveContainer(
                      child: Text('Complete an in-app subscription to manage billing in your app store account.', style: TextStyle(color: CgColors.gray600, fontSize: 13)),
                    ),
                  const SizedBox(height: 22),
                  const CgResponsiveContainer(
                    child: Text('Your Premium Benefits', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: CgColors.gray900)),
                  ),
                  const SizedBox(height: 10),
                  ..._manageBenefits.map((b) => CgResponsiveContainer(child: _benefitCard(b.$1, b.$2))),
                  const SizedBox(height: 20),
                  CgResponsiveContainer(
                    child: Material(
                      color: CgColors.red50,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: _cancelBusy ? null : _cancelAtPeriodEnd,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: CgColors.red400.withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Cancel Subscription', style: TextStyle(fontWeight: FontWeight.w700, color: CgColors.red700, fontSize: 15)),
                                    const SizedBox(height: 4),
                                    Text('You will lose access to premium features after the period ends', style: TextStyle(fontSize: 12, color: CgColors.red700.withValues(alpha: 0.85))),
                                  ],
                                ),
                              ),
                              const Icon(Icons.close, color: CgColors.red700),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  static Widget _billingTile(IconData icon, String title, String subtitle, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: CgColors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CgColors.gray200),
            ),
            child: Row(
              children: [
                Icon(icon, color: CgColors.gray600),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: CgColors.gray500)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: CgColors.gray400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SubscriptionExpiredScreen extends StatelessWidget {
  const SubscriptionExpiredScreen({
    super.key,
    this.expiredAt,
    this.planLabel = 'Premium',
  });

  final DateTime? expiredAt;
  final String planLabel;

  @override
  Widget build(BuildContext context) {
    final expiredOn = expiredAt ?? DateTime.now();
    final daysSince = DateTime.now().difference(expiredOn).inDays.clamp(0, 9999);

    return Scaffold(
      backgroundColor: CgColors.gray50,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 8, 16, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [CgColors.orange500, CgColors.orange700], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: CgColors.white),
                      onPressed: () => context.go(AppPaths.app),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: CgColors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.workspace_premium, color: CgColors.white, size: 36),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your Premium Membership Has Expired',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: CgColors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2),
                ),
                const SizedBox(height: 8),
                Text(
                  'Renew now to continue enjoying premium features',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: CgColors.white.withValues(alpha: 0.92), fontSize: 14),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: CgColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: CgColors.gray200)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Previous plan', style: TextStyle(fontSize: 12, color: CgColors.gray500)),
                      const SizedBox(height: 4),
                      Text(planLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 12),
                      const Text('Expired on', style: TextStyle(fontSize: 12, color: CgColors.gray500)),
                      Text(_formatUiDate(expiredOn), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 12),
                      Text('Days since expiration: $daysSince days', style: const TextStyle(fontWeight: FontWeight.w600, color: CgColors.red700, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('What You\'re Missing', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 12),
                _missingRow('Unlimited swipes on GHINder'),
                _missingRow('Message anyone without matching first'),
                _missingRow('Advanced filters'),
                _missingRow('Priority customer support'),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: CgColors.green700, width: 2),
                    color: CgColors.green50,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Annual', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: CgColors.green700, borderRadius: BorderRadius.circular(8)),
                            child: const Text('BEST VALUE', style: TextStyle(color: CgColors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text('$kPremiumYearlyDisplay / year', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CgColors.green900)),
                      const Text('Save 33% • Just \$6.67/month', style: TextStyle(fontSize: 13, color: CgColors.gray700)),
                      const SizedBox(height: 12),
                      CgPrimaryButton(
                        label: 'Renew Annual',
                        onPressed: () => context.push(AppPaths.appMembership),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: CgColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: CgColors.gray200)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Monthly', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 6),
                      const Text('$kRenewMonthlyDisplay / month', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const Text('Cancel anytime', style: TextStyle(fontSize: 13, color: CgColors.gray600)),
                      const SizedBox(height: 12),
                      CgOutlineButton(
                        label: 'Renew Monthly',
                        onPressed: () => context.push(AppPaths.appMembership),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => context.go(AppPaths.app),
                    child: const Text('Continue with free membership'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _missingRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: CgColors.gray400, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, color: CgColors.gray700))),
        ],
      ),
    );
  }
}
