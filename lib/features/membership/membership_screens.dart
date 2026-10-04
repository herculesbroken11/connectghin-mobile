import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_user_message.dart';
import '../../core/premium/effective_premium.dart';
import '../../core/widgets/cg_outline_button.dart';
import '../../core/widgets/cg_primary_button.dart';
import '../../core/widgets/cg_responsive_container.dart';
import '../subscriptions/data/subscriptions_api.dart';
import '../subscriptions/iap_product_config.dart';
import '../subscriptions/store_billing_copy.dart';
import 'premium_benefits.dart';

/// Fallback display strings when store ProductDetails are unavailable.
/// The charged price always comes from the store ProductDetails.price.
const String kPremiumMonthlyDisplay = '\$2.99';
const String kPremiumYearlyDisplay = '\$29.99';
const String kRenewMonthlyDisplay = '\$2.99';

/// Factual annual-vs-monthly savings note (12 × $2.99 = $35.88 − $29.99 ≈ 16%).
const String kPremiumYearlySavingsHint = 'Save about 16% vs paying monthly';
const String kPremiumYearlyEffectiveMonthlyHint = 'About \$2.50/month';

const String kAppleVerifyStillSignedInMessage =
    'The App Store subscription could not be verified. You are still signed in. Please try Restore Purchases.';

/// Numeric App Store transaction id for `GET /inApps/v1/subscriptions/{id}`.
/// StoreKit 2 puts that id in [purchaseId]. The JWS is never sent as the id.
String? appleStoreTransactionId({
  String? purchaseId,
  String serverVerificationData = '',
}) {
  final id = purchaseId?.trim() ?? '';
  if (RegExp(r'^\d+$').hasMatch(id)) return id;
  return appleTransactionIdFromStoreKitJws(serverVerificationData);
}

/// Reads `transactionId` from a StoreKit JWS payload. Returns null for receipts
/// that are not a compact JWS with a numeric transaction id.
String? appleTransactionIdFromStoreKitJws(String jws) {
  final parts = jws.split('.');
  if (parts.length < 2 || parts[1].isEmpty) return null;
  try {
    final decoded = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final json = jsonDecode(decoded);
    if (json is! Map) return null;
    final raw = json['transactionId'] ?? json['originalTransactionId'];
    final value = raw?.toString().trim() ?? '';
    if (RegExp(r'^\d+$').hasMatch(value)) return value;
  } catch (_) {
    return null;
  }
  return null;
}

String _appleTxSuffix(String transactionId) {
  if (transactionId.length <= 4) return '****';
  return transactionId.substring(transactionId.length - 4);
}

/// StoreKit display name, renewal length, and localized full price.
/// Returns null until StoreKit provides both a name and a price.
class StoreKitPlanPresentation {
  const StoreKitPlanPresentation({
    required this.title,
    required this.duration,
    required this.price,
  });

  final String title;
  final String duration;
  final String price;
}

StoreKitPlanPresentation? storeKitPlanPresentation(ProductDetails? product) {
  if (product == null) return null;
  final title = product.title.trim();
  final price = product.price.trim();
  if (title.isEmpty || price.isEmpty) return null;
  final duration = storeKitSubscriptionDuration(product);
  if (duration == null) return null;
  return StoreKitPlanPresentation(title: title, duration: duration, price: price);
}

/// Human-readable StoreKit subscription period, such as "1 month" or "1 year".
String? storeKitSubscriptionDuration(ProductDetails product) {
  if (product is AppStoreProduct2Details) {
    final period = product.sk2Product.subscription?.subscriptionPeriod;
    if (period != null && period.value > 0) {
      return humanSubscriptionDuration(period.value, period.unit.name);
    }
  } else if (product is AppStoreProductDetails) {
    final period = product.skProduct.subscriptionPeriod;
    if (period != null && period.numberOfUnits > 0) {
      return humanSubscriptionDuration(period.numberOfUnits, period.unit.name);
    }
  }
  if (product.id == IapProductConfig.monthlyProductId) return '1 month';
  if (product.id == IapProductConfig.yearlyProductId) return '1 year';
  return null;
}

String humanSubscriptionDuration(int value, String unitName) {
  final count = value < 1 ? 1 : value;
  final unit = switch (unitName) {
    'day' => count == 1 ? 'day' : 'days',
    'week' => count == 1 ? 'week' : 'weeks',
    'month' => count == 1 ? 'month' : 'months',
    'year' => count == 1 ? 'year' : 'years',
    _ => unitName,
  };
  return '$count $unit';
}

String _formatUiDate(DateTime d) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

String _monthYear(DateTime d) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${months[d.month - 1]} ${d.year}';
}

DateTime? _parseIso(dynamic v) {
  if (v == null) return null;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

List<(String, String)> get _upgradeBenefits => PremiumBenefits.items;

List<(String, String)> get _manageBenefits => PremiumBenefits.manageItems;

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
  bool _isPremiumEffective = false;
  Map<String, dynamic>? _subscription;
  bool _yearlyIapSelected = true;
  bool _purchaseBusy = false;
  bool _restoreBusy = false;
  bool _cancelBusy = false;
  int _iosVerifyInFlight = 0;
  int _iosRestoreVerified = 0;
  bool _iosRestoreSawTransaction = false;
  bool _iosRestoreVerifyFailed = false;

  StoreBillingCopy get _billingCopy => StoreBillingCopy(
        Platform.isIOS
            ? StoreBillingPlatform.appleAppStore
            : StoreBillingPlatform.googlePlay,
      );

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
      final billing = await SubscriptionsApi(session.apiClient).billingMe(t);
      if (!mounted) return;
      setState(() {
        _membershipType = me['membershipType']?.toString() ??
            billing['membershipType']?.toString();
        _membershipStatus = me['membershipStatus']?.toString() ??
            billing['membershipStatus']?.toString();
        _isPremiumEffective = me['isPremium'] == true ||
            billing['isPremium'] == true ||
            isEffectivePremiumFromJson(me);
        _subscription = billing['subscription'] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isPremiumActive {
    if (_isPremiumEffective) return true;
    final t = _membershipType;
    final s = _membershipStatus;
    return t == 'PREMIUM' && (s == 'ACTIVE' || s == 'TRIALING' || s == 'PAST_DUE');
  }

  String get _monthlyPriceLabel =>
      _monthlyProduct?.price ?? kPremiumMonthlyDisplay;

  String get _yearlyPriceLabel =>
      _yearlyProduct?.price ?? kPremiumYearlyDisplay;

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
      if (response.notFoundIDs.isNotEmpty ||
          response.error != null ||
          monthly == null ||
          yearly == null) {
        developer.log(
          'IAP product query platform=${Platform.operatingSystem} '
          'notFoundIDs=${response.notFoundIDs.join(',')} '
          'storeError=${response.error?.code}:${response.error?.message} '
          'returned=${response.productDetails.map((p) => p.id).join(',')}',
          name: 'IAP',
        );
      }
      setState(() {
        _monthlyProduct = monthly;
        _yearlyProduct = yearly;
        _storeError = (monthly == null && yearly == null)
            ? kSubscriptionsUnavailableMessage
            : null;
        _storeLoading = false;
      });
    } catch (e, st) {
      developer.log('IAP product query failed: $e', name: 'IAP', stackTrace: st);
      if (!mounted) return;
      setState(() {
        _storeLoading = false;
        _storeError = kSubscriptionsUnavailableMessage;
      });
    }
  }

  bool _isAlreadyOwnedError(IAPError? error) {
    final code = (error?.code ?? '').toLowerCase();
    final message = (error?.message ?? '').toLowerCase();
    return code.contains('itemalreadyowned') ||
        message.contains('itemalreadyowned') ||
        message.contains('already subscribed') ||
        message.contains('already owned');
  }

  String _redactToken(String token) {
    if (token.length <= 12) return '***';
    return '${token.substring(0, 6)}…${token.substring(token.length - 4)}';
  }

  /// Syncs an owned Google Play purchase to the backend, then acknowledges it.
  Future<bool> _verifyAndFinishPurchase(PurchaseDetails purchase) async {
    final session = context.read<AuthSession>();
    final token = session.accessToken;
    if (token == null) return false;

    final api = SubscriptionsApi(session.apiClient);
    var verified = false;

    if (Platform.isIOS) {
      final tx = appleStoreTransactionId(
        purchaseId: purchase.purchaseID,
        serverVerificationData: purchase.verificationData.serverVerificationData,
      );
      developer.log(
        'IAP apple ${purchase.status.name} productId=${purchase.productID} '
        'txSuffix=${tx == null ? 'none' : _appleTxSuffix(tx)} signedIn=${session.isLoggedIn}',
        name: 'IAP',
      );
      if (tx == null) {
        developer.log(
          'IAP apple missing numeric transaction id productId=${purchase.productID}',
          name: 'IAP',
        );
      } else {
        for (var attempt = 1; attempt <= 3; attempt++) {
          final current = session.accessToken;
          if (current == null) {
            developer.log(
              'IAP apple verify aborted signedIn=false attempt=$attempt',
              name: 'IAP',
            );
            return false;
          }
          try {
            await api.verifyAppleEntitlement(current, transactionId: tx);
            developer.log(
              'IAP apple verify ok attempt=$attempt productId=${purchase.productID} '
              'signedIn=${session.isLoggedIn}',
              name: 'IAP',
            );
            verified = true;
            break;
          } catch (e) {
            final http = e is ApiHttpException ? e.statusCode : null;
            developer.log(
              'IAP apple verify failed attempt=$attempt http=$http '
              'signedIn=${session.isLoggedIn}',
              name: 'IAP',
            );
            final retryable = e is ApiHttpException &&
                (e.statusCode == 400 || e.statusCode == 401 || e.statusCode >= 500);
            if (!retryable || attempt == 3) rethrow;
            await Future<void>.delayed(Duration(seconds: attempt));
          }
        }
      }
    } else if (Platform.isAndroid) {
      final tokenStr = purchase.verificationData.serverVerificationData;
      final productId = purchase.productID;
      developer.log(
        'Google purchase sync productId=$productId token=${_redactToken(tokenStr)}',
        name: 'IAP',
      );
      if (tokenStr.isNotEmpty && productId.isNotEmpty) {
        await api.verifyGooglePlayPurchase(
          token,
          purchaseToken: tokenStr,
          productId: productId,
          packageName: IapProductConfig.androidPackageName,
        );
        verified = true;
      }
    }

    if (verified && purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
    return verified;
  }

  /// Pulls already-owned Android subscriptions and verifies each with the backend.
  Future<int> _syncAndroidOwnedPurchases() async {
    if (!Platform.isAndroid) return 0;
    final addition =
        _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final past = await addition.queryPastPurchases();
    if (past.error != null) {
      developer.log('queryPastPurchases error: ${past.error!.message}',
          name: 'IAP');
    }
    var synced = 0;
    for (final purchase in past.pastPurchases) {
      if (purchase.status != PurchaseStatus.purchased &&
          purchase.status != PurchaseStatus.restored) {
        continue;
      }
      if (!IapProductConfig.allIds.contains(purchase.productID)) continue;
      try {
        if (await _verifyAndFinishPurchase(purchase)) synced++;
      } catch (e) {
        developer.log('Failed syncing past purchase ${purchase.productID}: $e',
            name: 'IAP');
        rethrow;
      }
    }
    return synced;
  }

  Future<void> _startInAppPurchase() async {
    if (_storeLoading) return;
    final product = selectedStoreProduct<ProductDetails>(
      yearlySelected: _yearlyIapSelected,
      monthly: _monthlyProduct,
      yearly: _yearlyProduct,
    );
    if (product == null) {
      developer.log(
        'Subscribe blocked; selected plan has no store product yearly=$_yearlyIapSelected',
        name: 'IAP',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(kSubscriptionsUnavailableMessage)),
      );
      return;
    }
    setState(() => _purchaseBusy = true);
    final session = context.read<AuthSession>();
    try {
      // If Play already owns the plan ("Confirm plan" / itemAlreadyOwned), sync instead of buying again.
      if (Platform.isAndroid) {
        final synced = await _syncAndroidOwnedPurchases();
        if (synced > 0) {
          if (!mounted) return;
          session.bumpProfileRefresh();
          await _load();
          if (mounted) {
            setState(() => _purchaseBusy = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Existing Google Play subscription synced. Premium should unlock now.')),
            );
          }
          return;
        }
      }
      final purchased = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!purchased && mounted) {
        setState(() => _purchaseBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Unable to start purchase. Try Restore Purchases.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _purchaseBusy = false);
        showApiErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _restorePurchases() async {
    final session = context.read<AuthSession>();
    final token = session.accessToken;
    if (token == null) return;
    setState(() => _restoreBusy = true);
    try {
      if (Platform.isIOS) {
        await _restoreIosPurchases(session);
        return;
      }
      var synced = 0;
      if (Platform.isAndroid) {
        synced = await _syncAndroidOwnedPurchases();
      }
      await _iap.restorePurchases();
      // Brief wait so restore stream events can arrive and verify.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (Platform.isAndroid && synced == 0) {
        // Fallback: backend may already have a prior purchaseToken hash/token.
        await SubscriptionsApi(session.apiClient).restoreGooglePlayPurchases(
          token,
          packageName: IapProductConfig.androidPackageName,
        );
      }
      session.bumpProfileRefresh();
      await _load();
      if (mounted) {
        final unlocked = _isPremiumActive;
        if (!unlocked && synced > 0 && Platform.isAndroid) {
          developer.log(
            'Google Play purchase synced but backend did not mark Premium.',
            name: 'IAP',
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _billingCopy.restoreResult(
                unlocked: unlocked,
                syncedFromStore: synced,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) showApiErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _restoreBusy = false);
    }
  }

  /// StoreKit 2 sync, then current entitlements. Verification failures stay on
  /// this screen and never clear the ConnectGHIN session.
  Future<void> _restoreIosPurchases(AuthSession session) async {
    _iosRestoreVerified = 0;
    _iosRestoreSawTransaction = false;
    _iosRestoreVerifyFailed = false;
    developer.log('IAP restore start signedIn=${session.isLoggedIn}', name: 'IAP');
    final addition = _iap.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
    try {
      developer.log('IAP AppStore.sync start', name: 'IAP');
      await addition.sync();
      developer.log('IAP AppStore.sync ok signedIn=${session.isLoggedIn}', name: 'IAP');
    } catch (e) {
      developer.log(
        'IAP AppStore.sync failed type=${e.runtimeType} signedIn=${session.isLoggedIn}',
        name: 'IAP',
      );
    }
    try {
      await _iap.restorePurchases();
      developer.log(
        'IAP restorePurchases returned signedIn=${session.isLoggedIn}',
        name: 'IAP',
      );
    } catch (e) {
      developer.log(
        'IAP restorePurchases failed type=${e.runtimeType} signedIn=${session.isLoggedIn}',
        name: 'IAP',
      );
    }
    await _waitUntilIosVerifyIdle();
    if (!mounted || !session.isLoggedIn) {
      developer.log(
        'IAP restore finished signedIn=${session.isLoggedIn}',
        name: 'IAP',
      );
      return;
    }
    session.bumpProfileRefresh();
    await _load();
    if (!mounted) return;
    final unlocked = _isPremiumActive;
    developer.log(
      'IAP restore done premium=$unlocked verified=$_iosRestoreVerified '
      'sawTx=$_iosRestoreSawTransaction verifyFailed=$_iosRestoreVerifyFailed '
      'signedIn=${session.isLoggedIn}',
      name: 'IAP',
    );
    final String message;
    if (unlocked) {
      message = _billingCopy.restoreResult(
        unlocked: true,
        syncedFromStore: _iosRestoreVerified,
      );
    } else if (_iosRestoreVerifyFailed) {
      message = kAppleVerifyStillSignedInMessage;
    } else {
      message = _billingCopy.restoreResult(
        unlocked: false,
        syncedFromStore: _iosRestoreSawTransaction ? 1 : 0,
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _waitUntilIosVerifyIdle() async {
    final sw = Stopwatch()..start();
    var sawWork = false;
    while (sw.elapsed < const Duration(seconds: 30)) {
      if (_iosVerifyInFlight > 0) sawWork = true;
      if (sawWork && _iosVerifyInFlight == 0) return;
      if (!sawWork && sw.elapsed >= const Duration(seconds: 2)) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    developer.log(
      'IAP restore verify wait timed out inFlight=$_iosVerifyInFlight',
      name: 'IAP',
    );
  }

  Future<void> _onPurchaseUpdates(
      List<PurchaseDetails> purchaseDetailsList) async {
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
        // Play says already owned → sync existing entitlement instead of dead-ending.
        if (_isAlreadyOwnedError(purchase.error)) {
          try {
            if (Platform.isAndroid) {
              await _syncAndroidOwnedPurchases();
            } else {
              await _iap.restorePurchases();
            }
            session.bumpProfileRefresh();
            await _load();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _isPremiumActive
                        ? 'Existing subscription synced. Premium unlocked.'
                        : _billingCopy.alreadyOwnedFollowUp,
                  ),
                ),
              );
            }
          } catch (e) {
            if (mounted) showApiErrorSnackBar(context, e);
          }
          continue;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(purchase.error?.message ?? 'Purchase failed')),
          );
        }
      } else if (purchase.status == PurchaseStatus.canceled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase canceled.')),
          );
        }
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final trackIos = Platform.isIOS;
        if (trackIos) {
          _iosVerifyInFlight++;
          if (purchase.status == PurchaseStatus.restored) {
            _iosRestoreSawTransaction = true;
          }
        }
        try {
          final verified = await _verifyAndFinishPurchase(purchase);
          if (trackIos &&
              verified &&
              purchase.status == PurchaseStatus.restored) {
            _iosRestoreVerified++;
          }
          if (verified) {
            session.bumpProfileRefresh();
            await _load();
            developer.log(
              'IAP entitlement refreshed productId=${purchase.productID} '
              'premium=$_isPremiumEffective signedIn=${session.isLoggedIn}',
              name: 'IAP',
            );
            if (mounted && !_restoreBusy) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Subscription updated successfully.')),
              );
            }
          } else if (mounted && !_restoreBusy) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Purchase received but could not be verified. Try Restore Purchases.')),
            );
          }
        } catch (e) {
          if (trackIos) _iosRestoreVerifyFailed = true;
          final http = e is ApiHttpException ? e.statusCode : null;
          developer.log(
            'IAP purchase handler failed http=$http signedIn=${session.isLoggedIn}',
            name: 'IAP',
          );
          if (mounted && !_restoreBusy) {
            if (Platform.isIOS) {
              showUserMessageSnackBar(context, kAppleVerifyStillSignedInMessage);
            } else {
              showApiErrorSnackBar(context, e);
            }
          }
        } finally {
          if (trackIos && _iosVerifyInFlight > 0) _iosVerifyInFlight--;
        }
      }
    }
  }

  String _activeMembershipPriceLine(String? billingCycle) {
    final yearly = billingCycle == 'YEARLY';
    if (Platform.isIOS) {
      final plan = storeKitPlanPresentation(yearly ? _yearlyProduct : _monthlyProduct);
      if (plan == null) return 'Billed through the App Store';
      return '${plan.price} · ${plan.duration}';
    }
    return yearly ? '$_yearlyPriceLabel / year' : '$_monthlyPriceLabel / month';
  }

  List<Widget> _freePlanCopy({
    required ProductDetails? product,
    required bool yearly,
    required Color titleColor,
    required Color bodyColor,
    required StoreBillingCopy copy,
  }) {
    if (Platform.isIOS) {
      final plan = storeKitPlanPresentation(product);
      if (plan == null) {
        return [
          Text(
            'App Store price unavailable',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: titleColor),
          ),
        ];
      }
      return [
        Text(
          plan.title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: titleColor),
        ),
        const SizedBox(height: 8),
        Text(
          plan.duration,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: bodyColor),
        ),
        const SizedBox(height: 6),
        Text(
          plan.price,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: titleColor),
        ),
      ];
    }
    if (yearly) {
      return [
        Text(
          'Annual plan',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: titleColor),
        ),
        const SizedBox(height: 8),
        Text(
          '$_yearlyPriceLabel / year',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: titleColor),
        ),
        const SizedBox(height: 6),
        Text(
          copy.annualBillingNote,
          style: TextStyle(fontSize: 13, color: bodyColor),
        ),
      ];
    }
    return [
      Text(
        'Monthly plan',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: titleColor),
      ),
      const SizedBox(height: 8),
      Text(
        '$_monthlyPriceLabel / month',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: titleColor),
      ),
      const SizedBox(height: 6),
      Text(
        'Cancel anytime',
        style: TextStyle(fontSize: 13, color: bodyColor),
      ),
    ];
  }

  Future<void> _openStoreManagementHelp() async {
    if (!mounted) return;
    final copy = _billingCopy;
    final uri = Uri.parse(copy.subscriptionManagementUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(copy.storeManagementLaunchFailure)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(copy.storeManagementLaunchFailure)),
      );
    }
  }

  Future<void> _cancelAtPeriodEnd() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel subscription?'),
        content: Text(_billingCopy.cancelDialogBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Premium')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel',
                  style: TextStyle(color: CgColors.red700))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _cancelBusy = true);
    try {
      await SubscriptionsApi(session.apiClient).cancel(t);
      if (mounted) {
        session.bumpProfileRefresh();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Subscription will end after the current period.')));
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
            decoration: const BoxDecoration(
                color: CgColors.green600, shape: BoxShape.circle),
            child: const Icon(Icons.check, color: CgColors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: CgColors.gray900)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 13, color: CgColors.gray600, height: 1.35)),
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
          Icon(Icons.check,
              size: 18, color: premium ? CgColors.green700 : CgColors.gray400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 13,
                  color: premium ? CgColors.gray900 : CgColors.gray600,
                  height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = _billingCopy;
    final subStatus = _subscription?['status']?.toString();
    final hasManagedSubscription = _subscription != null;
    final periodEnd = _parseIso(_subscription?['currentPeriodEnd']);
    final memberSince = _parseIso(_subscription?['createdAt']);
    final billingCycle = _subscription?['billingCycle']?.toString();
    final activePriceLine = _activeMembershipPriceLine(billingCycle);

    return Scaffold(
      backgroundColor: CgColors.gray50,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => context.pop()),
        title: Text(_isPremiumActive ? 'Membership' : 'Upgrade to Premium'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: CgColors.green700))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                if (!_isPremiumActive) ...[
                  const CgResponsiveContainer(
                    child: Text(
                      'Unlock the full Connectghin experience',
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: CgColors.gray200,
                                      borderRadius: BorderRadius.circular(6)),
                                  child: const Text('Current Plan',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: CgColors.gray700)),
                                ),
                                const SizedBox(height: 10),
                                const Text('Free',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: CgColors.gray900)),
                              ],
                            ),
                          ),
                          const Text('\$0 / month',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: CgColors.gray600)),
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
                              color: !_yearlyIapSelected
                                  ? CgColors.green700
                                  : CgColors.gray200,
                              width: !_yearlyIapSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _freePlanCopy(
                                    product: _monthlyProduct,
                                    yearly: false,
                                    titleColor: CgColors.gray900,
                                    bodyColor: CgColors.gray600,
                                    copy: copy,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    setState(() => _yearlyIapSelected = false),
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
                            gradient: const LinearGradient(
                                colors: [CgColors.green700, CgColors.green900]),
                            border: Border.all(
                                color: _yearlyIapSelected
                                    ? CgColors.green100
                                    : Colors.transparent,
                                width: 2),
                            boxShadow: [
                              if (_yearlyIapSelected)
                                BoxShadow(
                                    color: CgColors.green700
                                        .withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6)),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color:
                                          CgColors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: const Text('Best value',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: CgColors.white)),
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: _freePlanCopy(
                                        product: _yearlyProduct,
                                        yearly: true,
                                        titleColor: CgColors.white,
                                        bodyColor: CgColors.white.withValues(alpha: 0.9),
                                        copy: copy,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                        foregroundColor: CgColors.green900,
                                        backgroundColor: CgColors.white),
                                    onPressed: () => setState(
                                        () => _yearlyIapSelected = true),
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
                    child: Text('Free vs Premium',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: CgColors.gray900)),
                  ),
                  const SizedBox(height: 10),
                  CgResponsiveContainer(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: CgColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: CgColors.gray200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Free',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: CgColors.gray200,
                                    borderRadius: BorderRadius.circular(8)),
                                child: const Text('Current',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: CgColors.gray700)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _compareLine('Nearby golfer Connect (daily limit)'),
                          _compareLine('Message after you match'),
                          _compareLine('Feed preview (limited posts)'),
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
                              const Text('Premium',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: CgColors.green700,
                                    borderRadius: BorderRadius.circular(8)),
                                child: const Text('Upgrade',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: CgColors.white)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _compareLine('Unlimited Connect likes',
                              premium: true),
                          _compareLine('Full Feed browse, post & contact',
                              premium: true),
                          _compareLine('Premium profile badge',
                              premium: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_storeLoading)
                    const CgResponsiveContainer(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child:
                            LinearProgressIndicator(color: CgColors.green700),
                      ),
                    ),
                  if (_storeError != null)
                    CgResponsiveContainer(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CgColors.orange600.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: CgColors.orange500.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                size: 20, color: CgColors.orange700),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _storeError!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: CgColors.orange700,
                                    height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const CgResponsiveContainer(
                    child: Text('Premium Benefits',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: CgColors.gray900)),
                  ),
                  const SizedBox(height: 12),
                  ..._upgradeBenefits.map((b) =>
                      CgResponsiveContainer(child: _benefitCard(b.$1, b.$2))),
                  const SizedBox(height: 12),
                  CgResponsiveContainer(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: CgColors.blue50,
                          borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.shopping_bag_outlined,
                              size: 20, color: CgColors.blue700),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              copy.renewalDisclosure,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: CgColors.blue700,
                                  height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CgResponsiveContainer(
                    child: CgPrimaryButton(
                      label: _purchaseBusy
                          ? 'Opening store…'
                          : copy.subscribeButtonLabel,
                      onPressed: _purchaseBusy ||
                              _storeLoading ||
                              !canStartStorePurchase(
                                yearlySelected: _yearlyIapSelected,
                                monthly: _monthlyProduct,
                                yearly: _yearlyProduct,
                              )
                          ? null
                          : _startInAppPurchase,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CgResponsiveContainer(
                    child: CgOutlineButton(
                      label: _restoreBusy ? 'Restoring…' : 'Restore Purchases',
                      onPressed: _storeLoading || _restoreBusy
                          ? null
                          : _restorePurchases,
                    ),
                  ),
                  const SizedBox(height: 14),
                  CgResponsiveContainer(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: CgColors.green50,
                          borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        children: [
                          Text(
                            Platform.isIOS ? 'No free trial' : 'Launch pricing — no free trial',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: CgColors.green900),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            Platform.isIOS
                                ? (_monthlyProduct != null && _yearlyProduct != null
                                    ? 'Prices above are the full App Store renewal prices for your storefront. ${copy.cancelAnytimeSentence} A short trial may be offered later as the community grows.'
                                    : 'Prices load from the App Store for your storefront. ${copy.cancelAnytimeSentence} A short trial may be offered later as the community grows.')
                                : '$kPremiumMonthlyDisplay/month or $kPremiumYearlyDisplay/year. ${copy.cancelAnytimeSentence} A short trial may be offered later as the community grows.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 12,
                                color: CgColors.green800,
                                height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CgResponsiveContainer(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: CgColors.blue50,
                          borderRadius: BorderRadius.circular(14)),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 20, color: CgColors.blue700),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'After purchase, Connectghin syncs your membership from the receipt your device shares with our servers.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: CgColors.blue700,
                                  height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CgResponsiveContainer(
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () => context.push(AppPaths.appTerms),
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              'By subscribing, you agree to our Terms of Service',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: CgColors.blue700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => context.push(AppPaths.appPrivacyPolicy),
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              'Privacy Policy',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: CgColors.blue700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  CgResponsiveContainer(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                            colors: [CgColors.green800, CgColors.green900]),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                    color: CgColors.green100,
                                    borderRadius: BorderRadius.circular(20)),
                                child: const Text('Active',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: CgColors.green900)),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color:
                                        CgColors.white.withValues(alpha: 0.22),
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.check,
                                    color: CgColors.white, size: 20),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text('Premium',
                              style: TextStyle(
                                  color: CgColors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800)),
                          Text(activePriceLine,
                              style: TextStyle(
                                  color: CgColors.white.withValues(alpha: 0.95),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 20),
                          Container(
                              height: 1,
                              color: CgColors.white.withValues(alpha: 0.25)),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Member since',
                                  style: TextStyle(
                                      color: CgColors.white
                                          .withValues(alpha: 0.85),
                                      fontSize: 13)),
                              Text(
                                  memberSince != null
                                      ? _monthYear(memberSince)
                                      : '—',
                                  style: const TextStyle(
                                      color: CgColors.white,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Next renewal',
                                  style: TextStyle(
                                      color: CgColors.white
                                          .withValues(alpha: 0.85),
                                      fontSize: 13)),
                              Text(
                                  periodEnd != null
                                      ? _formatUiDate(periodEnd)
                                      : '—',
                                  style: const TextStyle(
                                      color: CgColors.white,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          if (subStatus != null) ...[
                            const SizedBox(height: 8),
                            Text('Status: $subStatus',
                                style: TextStyle(
                                    color:
                                        CgColors.white.withValues(alpha: 0.75),
                                    fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const CgResponsiveContainer(
                    child: Text('Manage your premium subscription',
                        style:
                            TextStyle(fontSize: 14, color: CgColors.gray600)),
                  ),
                  const SizedBox(height: 16),
                  const CgResponsiveContainer(
                    child: Text('Subscription management',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: CgColors.gray900)),
                  ),
                  const SizedBox(height: 10),
                  if (hasManagedSubscription) ...[
                    CgResponsiveContainer(
                        child: _billingTile(
                            Icons.storefront,
                            'Manage Subscription',
                            copy.manageSubscriptionSubtitle,
                            _openStoreManagementHelp)),
                    CgResponsiveContainer(
                        child: _billingTile(
                            Icons.receipt_long,
                            'Purchase History',
                            copy.purchaseHistorySubtitle,
                            _openStoreManagementHelp)),
                  ] else
                    CgResponsiveContainer(
                      child: Text(
                          copy.unmanagedSubscriptionHint,
                          style: const TextStyle(
                              color: CgColors.gray600, fontSize: 13)),
                    ),
                  const SizedBox(height: 22),
                  const CgResponsiveContainer(
                    child: Text('Your Premium Benefits',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: CgColors.gray900)),
                  ),
                  const SizedBox(height: 10),
                  ..._manageBenefits.map((b) =>
                      CgResponsiveContainer(child: _benefitCard(b.$1, b.$2))),
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
                            border: Border.all(
                                color: CgColors.red400.withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Cancel Subscription',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: CgColors.red700,
                                            fontSize: 15)),
                                    const SizedBox(height: 4),
                                    Text(
                                        'You will lose access to premium features after the period ends',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: CgColors.red700
                                                .withValues(alpha: 0.85))),
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

  static Widget _billingTile(
      IconData icon, String title, String subtitle, VoidCallback? onTap) {
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
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: CgColors.gray500)),
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
    final daysSince =
        DateTime.now().difference(expiredOn).inDays.clamp(0, 9999);

    return Scaffold(
      backgroundColor: CgColors.gray50,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                16, MediaQuery.paddingOf(context).top + 8, 16, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [CgColors.orange500, CgColors.orange700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
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
                  decoration: BoxDecoration(
                      color: CgColors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.workspace_premium,
                      color: CgColors.white, size: 36),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your Premium Membership Has Expired',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: CgColors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.2),
                ),
                const SizedBox(height: 8),
                Text(
                  'Renew now to continue enjoying premium features',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: CgColors.white.withValues(alpha: 0.92),
                      fontSize: 14),
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
                  decoration: BoxDecoration(
                      color: CgColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: CgColors.gray200)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Previous plan',
                          style:
                              TextStyle(fontSize: 12, color: CgColors.gray500)),
                      const SizedBox(height: 4),
                      Text(planLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 12),
                      const Text('Expired on',
                          style:
                              TextStyle(fontSize: 12, color: CgColors.gray500)),
                      Text(_formatUiDate(expiredOn),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 12),
                      Text('Days since expiration: $daysSince days',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: CgColors.red700,
                              fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('What You\'re Missing',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 12),
                _missingRow('Unlimited Connect likes'),
                _missingRow('Full Feed access, posting, and contact'),
                _missingRow('Premium profile badge'),
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
                          const Text('Annual',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 17)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: CgColors.green700,
                                borderRadius: BorderRadius.circular(8)),
                            child: const Text('BEST VALUE',
                                style: TextStyle(
                                    color: CgColors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                          Platform.isIOS
                              ? '1 year · App Store price on the next screen'
                              : '$kPremiumYearlyDisplay / year',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: CgColors.green900)),
                      if (!Platform.isIOS) ...[
                        const Text(kPremiumYearlySavingsHint,
                            style: TextStyle(
                                fontSize: 13, color: CgColors.gray700)),
                        const Text(kPremiumYearlyEffectiveMonthlyHint,
                            style: TextStyle(
                                fontSize: 12, color: CgColors.gray500)),
                      ],
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
                  decoration: BoxDecoration(
                      color: CgColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: CgColors.gray200)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Monthly',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(
                          Platform.isIOS
                              ? '1 month · App Store price on the next screen'
                              : '$kRenewMonthlyDisplay / month',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const Text('Cancel anytime',
                          style:
                              TextStyle(fontSize: 13, color: CgColors.gray600)),
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
          const Icon(Icons.check_circle_outline,
              color: CgColors.gray400, size: 22),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style:
                      const TextStyle(fontSize: 15, color: CgColors.gray700))),
        ],
      ),
    );
  }
}
