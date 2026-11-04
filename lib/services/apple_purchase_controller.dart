import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

import '../models/store_plan.dart';
import '../models/apple_subscription.dart';
import 'auth_service.dart';

abstract class AppleStoreGateway {
  bool get supported;
  Stream<List<PurchaseDetails>> get updates;
  Future<bool> available();
  Future<ProductDetailsResponse> products(Set<String> ids);
  Future<bool> buy(ProductDetails product, String accountToken);
  Future<void> restore();
  Future<void> complete(PurchaseDetails purchase);
  Future<List<PurchaseDetails>> unfinished();
  Future<void> manageSubscriptions();
}

class NativeAppleStoreGateway implements AppleStoreGateway {
  @override
  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  InAppPurchase get _store => InAppPurchase.instance;
  @override
  Stream<List<PurchaseDetails>> get updates => _store.purchaseStream;
  @override
  Future<bool> available() => _store.isAvailable();
  @override
  Future<ProductDetailsResponse> products(Set<String> ids) =>
      _store.queryProductDetails(ids);
  @override
  Future<bool> buy(ProductDetails product, String accountToken) =>
      _store.buyNonConsumable(
          purchaseParam: PurchaseParam(
              productDetails: product, applicationUserName: accountToken));
  @override
  Future<void> restore() => _store.restorePurchases();
  @override
  Future<void> manageSubscriptions() => AppStore().showManageSubscriptions();
  @override
  Future<void> complete(PurchaseDetails purchase) =>
      _store.completePurchase(purchase);
  @override
  Future<List<PurchaseDetails>> unfinished() async {
    // Restore lists current entitlements, not every unfinished transaction.
    return (await SK2Transaction.unfinishedTransactions())
        .map((tx) => SK2PurchaseDetails(
            productID: tx.productId,
            purchaseID: tx.id,
            verificationData: PurchaseVerificationData(
                localVerificationData: '',
                serverVerificationData: tx.receiptData ?? '',
                source: 'app_store'),
            transactionDate: tx.purchaseDate,
            status: PurchaseStatus.purchased,
            appAccountToken: tx.appAccountToken,
            expirationDate: tx.expirationDate,
            sk2Transaction: tx))
        .toList();
  }
}

/// StoreKit delivers transactions; only the authenticated backend grants access.
/// Never logs/persists JWS or appAccountToken. Native unfinished transactions
/// remain the durable retry queue until server acknowledgement and completion.
class ApplePurchaseController extends ChangeNotifier {
  ApplePurchaseController({
    required this.session,
    required this.statusRequest,
    required this.prepareRequest,
    required this.verifyRequest,
    required this.onEntitled,
    AppleStoreGateway? store,
    this.checkoutWait = const Duration(seconds: 90),
    this.verificationWait = const Duration(seconds: 65),
    this.operationWait = const Duration(seconds: 20),
  }) : _store = store ?? NativeAppleStoreGateway() {
    if (_store.supported) {
      _subscription = _store.updates
          .listen(_enqueue, onError: (_) => _setError('Apple 购买状态暂不可用，请稍后重试'));
    }
  }

  final String Function() session;
  final Future<Map<String, dynamic>> Function(String session) statusRequest;
  final Future<Map<String, dynamic>> Function(String session, String productId)
      prepareRequest;
  final Future<Map<String, dynamic>> Function(String session, String signed)
      verifyRequest;
  final Future<void> Function() onEntitled;
  final AppleStoreGateway _store;
  final Duration checkoutWait;
  final Duration verificationWait, operationWait;
  bool _managing = false;
  final Set<String> _mismatchedReceipts = {};
  Timer? _checkoutTimer;
  bool _awaitingCheckout = false;
  final Set<String> _pendingProducts = {};
  bool _recovering = false;
  bool _recoveryFailed = false;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final Map<String, ProductDetails> _products = {};
  final Map<String, PurchaseDetails> _unfinished = {};
  Future<void> _queue = Future.value();
  int _generation = 0;
  bool _disposed = false;
  bool _enabled = false;
  bool _restoreEnabled = false;
  bool _available = false;
  bool _busy = false;
  String _reason = 'Apple 购买暂未开放';
  String _error = '';
  String _message = '';
  AppleSubscription? _currentSubscription;
  AppleSubscription? get currentSubscription => _currentSubscription;
  bool _statusLoading = false;
  int _statusEpoch = 0;

  bool get supported => _store.supported;
  bool get busy => _busy || _recovering;
  bool get awaitingApple => _awaitingCheckout || _pendingProducts.isNotEmpty;
  bool get needsRecovery => _unfinished.isNotEmpty || _recoveryFailed;
  bool get accountMismatch => _mismatchedReceipts.isNotEmpty;
  bool get canManage => supported && _available && !_managing;
  bool get configured => supported && _available && _restoreEnabled;
  bool get canRestore => configured && !busy;
  String get error => _error;
  String get message => _message;
  String get reason => _reason;
  ProductDetails? product(String? id) => _products[id];
  bool canBuy(String? id) =>
      supported &&
      _available &&
      _enabled &&
      _currentSubscription?.active != true &&
      !busy &&
      !_managing &&
      !awaitingApple &&
      !needsRecovery &&
      id != null &&
      _products.containsKey(id);

  bool _current(String key, int generation) =>
      !_disposed &&
      session() == key &&
      key.isNotEmpty &&
      _generation == generation;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    _message = '';
    _busy = false;
    _notify();
  }

  void sessionChanged() {
    _generation++;
    _statusEpoch++;
    _checkoutTimer?.cancel();
    _awaitingCheckout = false;
    _pendingProducts.clear();
    _mismatchedReceipts.clear();
    _recoveryFailed = supported;
    _products.clear();
    _currentSubscription = null;
    _enabled = false;
    _restoreEnabled = false;
    _available = false;
    _busy = false;
    _error = '';
    _message = '';
    _reason = 'Apple 购买暂未开放';
    _notify();
  }

  Future<void> load(List<StorePlan> plans) async {
    if (!supported || session().isEmpty || _disposed) return;
    final key = session(), generation = _generation;
    final epoch = _statusEpoch;
    try {
      final status = await statusRequest(key).timeout(operationWait);
      if (!_current(key, generation) || epoch != _statusEpoch) return;
      _enabled = status['purchase_enabled'] == true;
      _restoreEnabled = status['restore_enabled'] == true;
      _currentSubscription = AppleSubscription.parse(status['subscription']);
      _reason = status['reason'] is String
          ? status['reason'] as String
          : 'Apple 购买暂未开放';
      _available = await _store.available();
      if (!_current(key, generation) || epoch != _statusEpoch) return;
      final ids = plans
          .expand((p) => p.offers)
          .map((o) => o.productId)
          .whereType<String>()
          .toSet();
      if (_available && ids.isNotEmpty) {
        final response = await _store.products(ids);
        if (!_current(key, generation) || epoch != _statusEpoch) return;
        _products.clear();
        if (response.error != null) {
          _error = 'Apple 商品价格暂未加载，请稍后刷新';
        } else {
          for (final p in response.productDetails) {
            if (ids.contains(p.id)) _products[p.id] = p;
          }
        }
      }
      _notify();
      if (_restoreEnabled && _available) await _recoverUnfinished();
    } catch (_) {
      if (_current(key, generation) && epoch == _statusEpoch) {
        _enabled = false;
        _restoreEnabled = false;
        _setError('Apple 购买服务暂不可用，请稍后刷新');
      }
    }
  }

  /// Called after returning from Apple's subscription settings. Never opens
  /// the payment gate or grants access based on a local UI selection.
  Future<void> refreshStatus() async {
    if (!supported || _statusLoading || session().isEmpty || _disposed) return;
    final key = session(), generation = _generation;
    final epoch = _statusEpoch;
    _statusLoading = true;
    try {
      final status = await statusRequest(key).timeout(operationWait);
      if (!_current(key, generation) || epoch != _statusEpoch) return;
      _currentSubscription = AppleSubscription.parse(status['subscription']);
      _enabled = status['purchase_enabled'] == true;
      _restoreEnabled = status['restore_enabled'] == true;
      _reason = status['reason'] as String? ?? 'Apple 购买暂未开放';
      if (!needsRecovery) _error = '';
    } catch (_) {
      if (_current(key, generation) && epoch == _statusEpoch) {
        _enabled = false;
        _error = '订阅状态刷新失败，当前显示上次结果，请稍后刷新';
      }
    } finally {
      _statusLoading = false;
      _notify();
    }
  }

  Future<void> buy(String productId) async {
    if (!canBuy(productId)) return;
    final key = session(), generation = _generation;
    _busy = true;
    _error = '';
    _message = '';
    _checkoutTimer?.cancel();
    final watchdog = Timer(checkoutWait, () {
      if (!_current(key, generation) || !_busy) return;
      _busy = false;
      _awaitingCheckout = true;
      _message = 'Apple 尚未返回付款结果，请检查购买状态。若不付款，请在 Apple 购买窗口取消；不会自动重复下单。';
      _notify();
    });
    _checkoutTimer = watchdog;
    _notify();
    try {
      final intent = await prepareRequest(key, productId);
      if (!_current(key, generation)) return;
      final accountToken = intent['app_account_token'];
      if (intent['product_id'] != productId ||
          accountToken is! String ||
          !RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
              .hasMatch(accountToken)) {
        throw StateError('Invalid purchase intent');
      }
      if (!await _store.buy(_products[productId]!, accountToken)) {
        if (_current(key, generation)) _setError('未能打开 Apple 购买，请稍后重试');
      }
    } on PlatformException catch (error) {
      if (!_current(key, generation)) return;
      _awaitingCheckout = false;
      _busy = false;
      if (error.code == 'storekit_duplicate_product_object') {
        _message = '检测到 Apple 未完成交易，正在核对原购买，不会重复下单…';
        await _recoverUnfinished();
        if (!_current(key, generation)) return;
        await refreshStatus();
        if (!_current(key, generation)) return;
        if (!needsRecovery && _currentSubscription?.active != true) {
          _message = '原交易已核对。若没有有效订阅，可再次选择套餐购买。';
        }
        _notify();
      } else {
        _setError('Apple 未完成付款，请检查网络或付款方式；如已扣费，请检查购买状态，不要重复下单');
      }
    } catch (_) {
      if (_current(key, generation)) {
        _awaitingCheckout = false;
        _setError('购买未完成，请稍后重试或恢复购买');
      }
    } finally {
      // A successful launch can precede its stream event. Keep the watchdog
      // until a terminal/pending event, rather than spinning indefinitely.
      if (!_current(key, generation) || !_busy) watchdog.cancel();
    }
  }

  Future<void> _recoverUnfinished() async {
    if (_recovering || !_restoreEnabled || !_available) return;
    final key = session(), generation = _generation;
    _recovering = true;
    _notify();
    try {
      final native =
          await _store.unfinished().timeout(const Duration(seconds: 15));
      if (!_current(key, generation)) return;
      _recoveryFailed = false;
      final records = {
        ..._unfinished,
        for (final p in native)
          if (p.purchaseID != null) p.purchaseID!: p
      };
      final retryable = records.values
          .where((p) => !_mismatchedReceipts.contains(p.purchaseID))
          .toList();
      if (retryable.isNotEmpty) await _enqueue(retryable);
      if (!_current(key, generation)) return;
      if (accountMismatch) {
        _setError('此 Apple 购买记录与当前皮卡云账号不匹配。请切回原购买账号恢复；取消自动续订不会转移订单。');
      }
    } catch (_) {
      if (_current(key, generation)) {
        _recoveryFailed = true;
        _setError('Apple 未完成交易检查失败，请检查购买状态后再下单');
      }
    } finally {
      _recovering = false;
      _notify();
    }
  }

  Future<void> checkPurchases() async {
    if (!canRestore) return;
    await _recoverUnfinished();
    await refreshStatus();
    if (!busy &&
        !needsRecovery &&
        !awaitingApple &&
        _currentSubscription?.active != true &&
        _error.isEmpty) {
      _message = '购买状态已核对，当前没有有效 Apple 订阅；如已付款，请恢复购买。';
    }
    _notify();
  }

  Future<void> restore() async {
    if (!canRestore) return;
    final key = session(), generation = _generation;
    _busy = true;
    _error = '';
    _message = '正在向 Apple 查询购买记录…';
    _notify();
    try {
      await _recoverUnfinished();
      if (!_current(key, generation)) return;
      if (accountMismatch) return;
      await _store.restore().timeout(operationWait);
      await _queue;
      if (_current(key, generation)) {
        _busy = false;
        if (_error.isEmpty && _message == '正在向 Apple 查询购买记录…') {
          _message = 'Apple 恢复查询已结束；有可恢复的记录时将验证并更新套餐。';
        }
        _notify();
      }
    } catch (_) {
      if (_current(key, generation)) _setError('恢复购买失败，请稍后重试');
    } finally {
      if (_current(key, generation)) {
        _busy = false;
        _notify();
      }
    }
  }

  /// Native sheet completion provides a return point even when iOS does not
  /// deliver an app lifecycle transition. Never infers cancellation locally.
  Future<void> manageSubscriptions() async {
    if (!canManage) return;
    final key = session(), generation = _generation;
    _managing = true;
    _notify();
    try {
      await _store.manageSubscriptions();
      if (!_current(key, generation)) return;
      await refreshStatus();
      if (!_current(key, generation)) return;
      try {
        await onEntitled().timeout(operationWait);
      } catch (_) {}
    } catch (_) {
      if (_current(key, generation)) {
        _setError('暂时无法打开 Apple 订阅管理，请从系统设置的订阅页面管理');
      }
    } finally {
      _managing = false;
      _notify();
    }
  }

  Future<void> _enqueue(List<PurchaseDetails> updates) {
    _queue = _queue.then((_) async {
      for (final purchase in updates) {
        if (_disposed) return;
        await _handle(purchase);
        // An outage must not turn a batch of old transactions into minutes of
        // sequential spinning. StoreKit retains the rest for a later retry.
        if (_error.isNotEmpty &&
            !accountMismatch &&
            (purchase.status == PurchaseStatus.purchased ||
                purchase.status == PurchaseStatus.restored)) {
          break;
        }
      }
    }).catchError((Object _) {
      if (!_disposed) _setError('购买验证尚未完成，请稍后恢复购买');
    });
    return _queue;
  }

  Future<void> _handle(PurchaseDetails purchase) async {
    if (purchase.status == PurchaseStatus.pending) {
      _checkoutTimer?.cancel();
      _awaitingCheckout = false;
      _pendingProducts.add(purchase.productID);
      _busy = false;
      _message = '等待 Apple 批准或确认付款，暂不重复下单；可检查购买状态或恢复购买。';
      _notify();
      return;
    }
    if (purchase.status == PurchaseStatus.canceled) {
      _checkoutTimer?.cancel();
      _awaitingCheckout = false;
      _pendingProducts.remove(purchase.productID);
      // SK2 cancellation has no transaction. SK1 terminal failed entries may
      // need completion, but are never sent to entitlement verification.
      if (purchase is AppStorePurchaseDetails &&
          purchase.pendingCompletePurchase) {
        try {
          await _store.complete(purchase);
        } catch (_) {
          _recoveryFailed = true;
        }
      }
      _busy = false;
      _error = '';
      _message = '已取消购买，套餐未变更';
      _notify();
      return;
    }
    if (purchase.status == PurchaseStatus.error) {
      _checkoutTimer?.cancel();
      _awaitingCheckout = false;
      _pendingProducts.remove(purchase.productID);
      if (purchase is AppStorePurchaseDetails &&
          purchase.pendingCompletePurchase) {
        try {
          await _store.complete(purchase);
        } catch (_) {
          _recoveryFailed = true;
        }
      }
      _setError('Apple 购买未完成，请重试或恢复购买');
      return;
    }
    if (purchase.status != PurchaseStatus.purchased &&
        purchase.status != PurchaseStatus.restored) {
      return;
    }
    final id = purchase.purchaseID;
    if (id == null || id.isEmpty) {
      _setError('购买信息不完整，请恢复购买');
      return;
    }
    _unfinished[id] = purchase;
    _checkoutTimer?.cancel();
    _awaitingCheckout = false;
    _pendingProducts.remove(purchase.productID);
    final key = session(), generation = _generation;
    if (key.isEmpty) {
      return; // Retry only when an authenticated account is present.
    }
    if (_mismatchedReceipts.contains(id)) {
      _setError('此 Apple 购买记录与当前皮卡云账号不匹配，请切回原购买账号恢复。');
      return;
    }
    final signed = purchase.verificationData.serverVerificationData;
    if (signed.split('.').length != 3) {
      _setError('购买凭证暂不可用，请在 iPhone 上恢复购买');
      return;
    }
    _busy = true;
    _error = '';
    _message = '正在验证 Apple 购买…';
    _notify();
    try {
      final result = await verifyRequest(key, signed).timeout(verificationWait);
      if (!_current(key, generation)) return;
      if (result['acknowledged'] != true) throw StateError('Not acknowledged');
      _statusEpoch++;
      // Apply the acknowledged server snapshot immediately, before slower
      // account refreshes. A failed refresh must not invite a second purchase.
      _currentSubscription = AppleSubscription.parse(result['subscription']);
      _enabled = false;
      if (purchase.pendingCompletePurchase) {
        await _store.complete(purchase).timeout(operationWait);
      }
      if (!_current(key, generation)) return;
      _unfinished.remove(id);
      try {
        await onEntitled().timeout(operationWait);
      } catch (_) {/* Acknowledged purchase is durable. */}
      await refreshStatus();
      if (!_current(key, generation)) return;
      _busy = false;
      _message =
          result['active'] == true ? '购买已验证，套餐已更新' : '购买记录已验证，当前没有有效的订阅权益';
      _notify();
    } on AuthException catch (error) {
      if (_current(key, generation)) {
        if (error.code == 'APPLE_ACCOUNT_MISMATCH') _mismatchedReceipts.add(id);
        _setError(error.message);
      }
    } on TimeoutException {
      if (_current(key, generation)) {
        _setError('购买验证超时，交易已保留，未重复下单。你可以离开商城，稍后检查购买状态。');
      }
    } catch (_) {
      if (_current(key, generation)) _setError('购买尚未验证完成，请使用原皮卡云账号稍后恢复购买');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _subscription?.cancel();
    _checkoutTimer?.cancel();
    _products.clear();
    _unfinished.clear();
    super.dispose();
  }
}
