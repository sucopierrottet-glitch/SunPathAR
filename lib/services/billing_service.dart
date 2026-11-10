import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'storage_service.dart';

class BillingService extends ChangeNotifier {
  static final BillingService instance = BillingService._();
  BillingService._();

  // Product IDs configurables en Google Play Console
  static const String monthlySubscriptionId = 'sunpath_pro_monthly';
  static const String yearlySubscriptionId = 'sunpath_pro_yearly';
  static const String lifetimeProductId = 'sunpath_pro_lifetime';

  static const Set<String> productIds = {
    monthlySubscriptionId,
    yearlySubscriptionId,
    lifetimeProductId,
  };

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Map<String, ProductDetails> _products = {};

  bool _isStoreAvailable = false;
  bool _isLoadingProducts = true;
  bool _isPurchasePending = false;
  String? _lastError;
  bool _purchaseSucceeded = false;

  bool get isStoreAvailable => _isStoreAvailable;
  bool get isLoadingProducts => _isLoadingProducts;
  bool get isPurchasePending => _isPurchasePending;
  String? get lastError => _lastError;
  bool get purchaseSucceeded => _purchaseSucceeded;

  ProductDetails? get monthlyProduct => _products[monthlySubscriptionId];
  ProductDetails? get yearlyProduct => _products[yearlySubscriptionId];
  ProductDetails? get lifetimeProduct => _products[lifetimeProductId];

  Future<void> init() async {
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (Object error) {
        _isPurchasePending = false;
        _lastError = error.toString();
        notifyListeners();
      },
    );
    await loadProducts();
    await restorePurchases();
  }

  Future<void> loadProducts() async {
    _isLoadingProducts = true;
    _lastError = null;
    notifyListeners();

    try {
      _isStoreAvailable = await _iap.isAvailable();
      if (!_isStoreAvailable) {
        _isLoadingProducts = false;
        notifyListeners();
        return;
      }

      final response = await _iap.queryProductDetails(productIds);
      if (response.error != null) {
        _lastError = response.error!.message;
      }
      _products = {
        for (final product in response.productDetails) product.id: product,
      };
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isLoadingProducts = false;
      notifyListeners();
    }
  }

  Future<String?> buyPlan({required String productId, bool isSubscription = true}) async {
    _lastError = null;
    _purchaseSucceeded = false;
    notifyListeners();

    final available = await _iap.isAvailable();
    if (!available) {
      _lastError = 'Google Play Store no está disponible en este momento.';
      notifyListeners();
      return 'STORE_NOT_AVAILABLE';
    }

    final product = _products[productId];
    if (product == null) {
      // Si la consola aún no aprueba el ID en pruebas, usamos fallback
      _lastError = 'Producto no cargado desde la tienda.';
      notifyListeners();
      return 'PRODUCT_NOT_FOUND';
    }

    _isPurchasePending = true;
    notifyListeners();

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      bool launched = false;
      if (isSubscription) {
        launched = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        launched = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      }

      if (!launched) {
        _isPurchasePending = false;
        _lastError = 'No se pudo iniciar el proceso de compra.';
        notifyListeners();
        return 'LAUNCH_FAILED';
      }
      return null;
    } catch (e) {
      _isPurchasePending = false;
      _lastError = e.toString();
      notifyListeners();
      return 'ERROR: $e';
    }
  }

  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _isPurchasePending = true;
        notifyListeners();
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          _isPurchasePending = false;
          _lastError = purchaseDetails.error?.message ?? 'Error en la transacción.';
          notifyListeners();
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          _isPurchasePending = false;
          _purchaseSucceeded = true;
          // Activamos estado PRO permanente en storage local
          await StorageService.instance.setProStatus(true);
          notifyListeners();
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
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
