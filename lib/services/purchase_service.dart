import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PurchaseService — wraps RevenueCat
//
//  SETUP (do this once):
//  1. Create account at revenuecat.com (free)
//  2. Create a new project → add iOS app + Android app
//  3. In RevenueCat dashboard:
//     • Create Entitlement: "pro"
//     • Create Offering: "default"
//     • Add products:
//       - iOS: "com.yourapp.flowmath.pro_monthly" ($4.99/mo)
//       - iOS: "com.yourapp.flowmath.pro_lifetime" ($49 one-time)
//       - Mirror same on Google Play
//  4. Replace the API key constants below with your real keys
//  5. Run: flutter pub get
// ─────────────────────────────────────────────────────────────────────────────

class PurchaseService extends ChangeNotifier {
  // ── Replace with your real RevenueCat API keys ────────────────────────────
  static const _iosKey = 'sk_BxjpjtBzsAHNtXfKFnbyipMSlXuXh';
  static const _androidKey = 'goog_wjazNSZgcKWwZRKzztOMsHolKsH';
  //   static const _iosKey = 'appl_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX';
  // static const _androidKey = 'goog_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX';

  // ── Entitlement & product IDs (must match RevenueCat dashboard) ───────────
  static const _entitlementId = 'pro';
  static const _monthlyProductId = 'com.yourapp.flowmath.pro_monthly';
  static const _lifetimeProductId = 'com.yourapp.flowmath.pro_lifetime';

  bool _isPro = false;
  bool _isLoading = false;
  String? _errorMsg;

  bool get isPro => _isPro;
  bool get isLoading => _isLoading;
  String? get errorMsg => _errorMsg;

  // ── Initialise once at app start ──────────────────────────────────────────
  Future<void> init() async {
    try {
      await Purchases.setLogLevel(LogLevel.error);
      final config = PurchasesConfiguration(
        Platform.isIOS ? _iosKey : _androidKey,
      );
      await Purchases.configure(config);
      await _refresh();
    } catch (e) {
      debugPrint('RevenueCat init error: $e');
    }
  }

  // ── Check entitlement ─────────────────────────────────────────────────────
  Future<void> _refresh() async {
    try {
      final info = await Purchases.getCustomerInfo();
      _isPro = info.entitlements.active.containsKey(_entitlementId);
      notifyListeners();
    } catch (_) {}
  }

  // ── Fetch available packages ──────────────────────────────────────────────
  Future<List<Package>> getPackages() async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.availablePackages ?? [];
    } catch (_) {
      return [];
    }
  }

  // ── Purchase monthly ──────────────────────────────────────────────────────
  Future<bool> purchaseMonthly() => _purchase(_monthlyProductId);

  // ── Purchase lifetime ─────────────────────────────────────────────────────
  Future<bool> purchaseLifetime() => _purchase(_lifetimeProductId);

  Future<bool> _purchase(String productId) async {
    _isLoading = true;
    _errorMsg = null;
    notifyListeners();
    try {
      final packages = await getPackages();
      final pkg = packages.firstWhere(
        (p) => p.storeProduct.identifier == productId,
        orElse: () => packages.first,
      );
      final info = await Purchases.purchasePackage(pkg);
      _isPro = info.entitlements.active.containsKey(_entitlementId);
      return _isPro;
    } on PurchasesErrorCode catch (e) {
      if (e != PurchasesErrorCode.purchaseCancelledError) {
        _errorMsg = 'Purchase failed. Please try again.';
      }
      return false;
    } catch (_) {
      _errorMsg = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Restore purchases ─────────────────────────────────────────────────────
  Future<bool> restore() async {
    _isLoading = true;
    notifyListeners();
    try {
      final info = await Purchases.restorePurchases();
      _isPro = info.entitlements.active.containsKey(_entitlementId);
      return _isPro;
    } catch (_) {
      _errorMsg = 'Restore failed. Check your account.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Anonymous user ID (for RevenueCat analytics) ──────────────────────────
  Future<String> getUserId() async {
    final info = await Purchases.getCustomerInfo();
    return info.originalAppUserId;
  }
}
