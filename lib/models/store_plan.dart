/// Apple catalogue metadata, not live StoreKit quotes. USD list prices are
/// supplied by the server; this model has no checkout or entitlement capability.
class StorePlan {
  const StorePlan({
    required this.id,
    required this.name,
    required this.trafficGb,
    required this.speedLimitMbps,
    required this.deviceLimit,
    required this.offers,
    this.resetTrafficMethod,
  });

  final int id;
  final String name;
  final double trafficGb;
  final int? speedLimitMbps;
  final int? deviceLimit;
  final List<StoreOffer> offers;
  final int? resetTrafficMethod;

  bool get resetsMonthly => resetTrafficMethod == 0 || resetTrafficMethod == 1;

  static StorePlan? fromAppleJson(Map<String, dynamic> json) {
    if (json['sales_channel'] != 'apple' ||
        !_enabled(json['show']) ||
        !_enabled(json['sell'])) {
      return null;
    }
    final id = int.tryParse('${json['id']}');
    final name = json['name'];
    final traffic = double.tryParse('${json['transfer_enable']}');
    if (id == null ||
        id <= 0 ||
        name is! String ||
        name.trim().isEmpty ||
        traffic == null ||
        !traffic.isFinite ||
        traffic < 0) {
      return null;
    }
    final offers = <StoreOffer>[];
    final products = json['apple_products'];
    for (final period in StorePeriod.values) {
      // Legacy fields establish available periods only. Never display or relabel
      // their CNY values as dollars, even when USD configuration is missing.
      final legacy = double.tryParse('${json[period.apiKey]}');
      if (legacy == null || !legacy.isFinite || legacy <= 0) continue;
      String? productId;
      int? usdPriceMinor;
      if (products is List) {
        final matching = products.whereType<Map>().where((p) =>
            p['period'] == period.name &&
            p['currency'] == 'USD' &&
            p['storefront'] == 'USA' &&
            p['price_source'] == 'merchant_config');
        if (matching.length == 1) {
          final product = matching.single;
          final id = product['product_id'];
          final amount = product['price_minor'];
          if (id is String &&
              id.trim().isNotEmpty &&
              amount is int &&
              amount > 0) {
            productId = id;
            usdPriceMinor = amount;
          }
        }
      }
      offers.add(StoreOffer(
          period: period, productId: productId, usdPriceMinor: usdPriceMinor));
    }
    if (offers.isEmpty) return null;
    return StorePlan(
      id: id,
      name: name.trim(),
      trafficGb: traffic,
      speedLimitMbps: int.tryParse('${json['speed_limit']}'),
      deviceLimit: int.tryParse('${json['device_limit']}'),
      offers: List.unmodifiable(offers),
      resetTrafficMethod: int.tryParse('${json['reset_traffic_method']}'),
    );
  }

  static bool _enabled(dynamic value) =>
      value == true || value == 1 || value == '1';
}

enum StorePeriod {
  monthly('month_price', '月付'),
  yearly('year_price', '年付');

  const StorePeriod(this.apiKey, this.label);
  final String apiKey;
  final String label;
}

class StoreOffer {
  const StoreOffer({required this.period, this.productId, this.usdPriceMinor});
  final StorePeriod period;
  final String? productId;
  final int? usdPriceMinor;

  String? get usdDisplayPrice {
    final amount = usdPriceMinor;
    if (amount == null) return null;
    return '\$${amount ~/ 100}.${(amount % 100).toString().padLeft(2, '0')}';
  }
}
