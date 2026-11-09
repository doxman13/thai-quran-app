import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class InAppPurchaseService extends ChangeNotifier {
  static final InAppPurchaseService _instance = InAppPurchaseService._internal();
  factory InAppPurchaseService() => _instance;
  InAppPurchaseService._internal();

  static const String tipSmall = 'tip_small';
  static const String tipMedium = 'tip_medium';
  static const String tipLarge = 'tip_large';

  static const Set<String> productIds = {
    tipSmall,
    tipMedium,
    tipLarge,
  };

  InAppPurchase? _inAppPurchaseInstance;
  InAppPurchase get _inAppPurchase =>
      _inAppPurchaseInstance ??= InAppPurchase.instance;

  @visibleForTesting
  set inAppPurchaseInstance(InAppPurchase instance) {
    _inAppPurchaseInstance = instance;
  }
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isAvailable = false;
  bool _isLoading = false;
  List<ProductDetails> _products = [];
  String? _purchaseSuccessMessage;
  String? _errorMessage;

  bool get isAvailable => _isAvailable;
  bool get isLoading => _isLoading;
  List<ProductDetails> get products => _products;
  String? get purchaseSuccessMessage => _purchaseSuccessMessage;
  String? get errorMessage => _errorMessage;

  void initialize() {
    if (kIsWeb) return;

    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _listenToPurchaseUpdated,
      onDone: () {
        _subscription?.cancel();
      },
      onError: (error) {
        debugPrint('[IAP] Purchase stream error: $error');
        _errorMessage = error.toString();
        notifyListeners();
      },
    );

    loadProducts();
  }

  Future<void> loadProducts() async {
    if (kIsWeb) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) {
        _isAvailable = false;
        _isLoading = false;
        notifyListeners();
        return;
      }

      _isAvailable = true;
      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(productIds);

      if (response.error != null) {
        debugPrint('[IAP] Error querying products: ${response.error}');
        _errorMessage = response.error!.message;
      }

      // Sort products deterministically: small, medium, large
      final ordered = response.productDetails.toList()
        ..sort((a, b) {
          final order = {tipSmall: 1, tipMedium: 2, tipLarge: 3};
          return (order[a.id] ?? 99).compareTo(order[b.id] ?? 99);
        });

      _products = ordered;
    } catch (e) {
      debugPrint('[IAP] Failed to load products: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> buyProduct(ProductDetails product) async {
    _purchaseSuccessMessage = null;
    _errorMessage = null;

    try {
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
      return await _inAppPurchase.buyConsumable(
        purchaseParam: purchaseParam,
        autoConsume: true,
      );
    } catch (e) {
      debugPrint('[IAP] buyConsumable error: $e');
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> _listenToPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Pending purchase
        _isLoading = true;
        notifyListeners();
      } else {
        _isLoading = false;
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('[IAP] Purchase error: ${purchaseDetails.error}');
          _errorMessage = purchaseDetails.error?.message ?? 'Purchase failed';
          notifyListeners();
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          _purchaseSuccessMessage = 'Jazakumullah Khairan';
          notifyListeners();
        }

        // Always complete consumable purchases on iOS/Android
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
