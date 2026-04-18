import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Product IDs — must match App Store Connect exactly
class IAPProductIds {
  static const String standardMonthly = 'com.basketball.team.tracker.standard_monthly';
  static const String proMonthly      = 'com.basketball.team.tracker.pro_monthly';
  static const String packTeam1       = 'com.basketball.team.tracker.pack_team_1';
  static const String packTeam3       = 'com.basketball.team.tracker.pack_team_3';
  static const String packTeam5       = 'com.basketball.team.tracker.pack_team_5';

  static const Set<String> all = {
    standardMonthly,
    proMonthly,
    packTeam1,
    packTeam3,
    packTeam5,
  };

  static const Set<String> subscriptions = {standardMonthly, proMonthly};
  static const Set<String> packs         = {packTeam1, packTeam3, packTeam5};
}

class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Cached product details
  final Map<String, ProductDetails> _products = {};

  // Purchase state callbacks
  void Function(PurchaseDetails)? onPurchaseSuccess;
  void Function(String error)?     onPurchaseError;
  void Function()?                 onPurchasePending;

  bool _initialized = false;

  /// Call once at app start or when SubscriptionPage opens.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('[IAP] Store not available');
      return;
    }

    // Listen to purchase updates
    final stream = _iap.purchaseStream;
    _subscription = stream.listen(
      _onPurchaseUpdate,
      onError: (e) => debugPrint('[IAP] Stream error: $e'),
    );

    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    final response = await _iap.queryProductDetails(IAPProductIds.all);
    if (response.error != null) {
      debugPrint('[IAP] Product load error: ${response.error}');
    }
    for (final p in response.productDetails) {
      _products[p.id] = p;
      debugPrint('[IAP] Loaded product: ${p.id} — ${p.price}');
    }
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('[IAP] Products not found: ${response.notFoundIDs}');
    }
  }

  ProductDetails? getProduct(String productId) => _products[productId];

  Map<String, ProductDetails> get products => Map.unmodifiable(_products);

  /// Buy a subscription (standard or pro).
  Future<void> buySubscription(String productId) async {
    final product = _products[productId];
    if (product == null) {
      onPurchaseError?.call('找不到商品，請稍後再試');
      return;
    }
    final param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  /// Buy a one-time pack (consumable on Google Play, non-consumable on iOS).
  Future<void> buyPack(String productId) async {
    final product = _products[productId];
    if (product == null) {
      onPurchaseError?.call('找不到商品，請稍後再試');
      return;
    }
    final param = PurchaseParam(productDetails: product);
    // Packs are treated as non-consumable (permanent team slot additions)
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      debugPrint('[IAP] Purchase update: ${purchase.productID} status=${purchase.status}');
      switch (purchase.status) {
        case PurchaseStatus.pending:
          onPurchasePending?.call();
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _verifyAndDeliver(purchase);
          break;
        case PurchaseStatus.error:
          onPurchaseError?.call(purchase.error?.message ?? '購買失敗');
          if (purchase.pendingCompletePurchase) {
            _iap.completePurchase(purchase);
          }
          break;
        case PurchaseStatus.canceled:
          onPurchaseError?.call('已取消購買');
          if (purchase.pendingCompletePurchase) {
            _iap.completePurchase(purchase);
          }
          break;
      }
    }
  }

  Future<void> _verifyAndDeliver(PurchaseDetails purchase) async {
    // On iOS, the receipt is verified by App Store before we receive purchased status.
    // We trust the platform and update Firestore accordingly.
    try {
      await _updateFirestore(purchase.productID);
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
      onPurchaseSuccess?.call(purchase);
    } catch (e) {
      debugPrint('[IAP] Firestore update error: $e');
      onPurchaseError?.call('購買成功但資料更新失敗，請重啟應用');
    }
  }

  Future<void> _updateFirestore(String productId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = FirebaseFirestore.instance.collection('users').doc(uid);

    if (productId == IAPProductIds.standardMonthly) {
      await ref.set({'plan': 'standard'}, SetOptions(merge: true));
    } else if (productId == IAPProductIds.proMonthly) {
      await ref.set({'plan': 'pro'}, SetOptions(merge: true));
    } else if (productId == IAPProductIds.packTeam1) {
      await ref.set({'packTeams': FieldValue.increment(1)}, SetOptions(merge: true));
    } else if (productId == IAPProductIds.packTeam3) {
      await ref.set({'packTeams': FieldValue.increment(3)}, SetOptions(merge: true));
    } else if (productId == IAPProductIds.packTeam5) {
      await ref.set({'packTeams': FieldValue.increment(5)}, SetOptions(merge: true));
    }
  }

  /// Restore previous purchases (required by App Store guidelines).
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }
}
