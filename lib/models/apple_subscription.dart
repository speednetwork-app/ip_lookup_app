/// Server-verified subscription presentation. No Apple transaction IDs/tokens
/// are retained in the view model or local account cache.
class AppleSubscription {
  const AppleSubscription(
      {required this.productId,
      required this.planId,
      required this.environment,
      required this.status,
      required this.active,
      this.expiresAt,
      this.nextResetAt,
      this.autoRenewEnabled,
      this.nextProductId,
      this.renewalAt,
      this.lastCheckedAt});

  final String productId, environment;
  final int planId, status;
  final bool active;
  final bool? autoRenewEnabled;
  final String? nextProductId;
  final DateTime? expiresAt, nextResetAt, renewalAt, lastCheckedAt;
  bool get sandbox => environment == 'Sandbox';
  bool get pendingChange =>
      autoRenewEnabled == true &&
      nextProductId != null &&
      nextProductId!.isNotEmpty &&
      nextProductId != productId;
  String get stateLabel => switch (status) {
        3 => '付款待处理',
        4 => '付款宽限期',
        5 => '订阅已撤销',
        _ => !active
            ? '订阅已到期'
            : autoRenewEnabled == false
                ? '已关闭自动续订'
                : '当前订阅',
      };

  static AppleSubscription? parse(dynamic value) {
    if (value is! Map ||
        value['product_id'] is! String ||
        !['Production', 'Sandbox'].contains(value['environment'])) {
      return null;
    }
    DateTime? date(dynamic seconds) => seconds is num && seconds > 0
        ? DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000)
        : null;
    return AppleSubscription(
        productId: value['product_id'] as String,
        planId: (value['plan_id'] as num?)?.toInt() ?? 0,
        environment: value['environment'] as String,
        status: (value['status'] as num?)?.toInt() ?? 0,
        active: value['active'] == true,
        expiresAt: date(value['expires_at']),
        nextResetAt: date(value['next_reset_at']),
        renewalAt: date(value['renewal_at']),
        lastCheckedAt: date(value['last_checked_at']),
        autoRenewEnabled: value['auto_renew_enabled'] is bool
            ? value['auto_renew_enabled'] as bool
            : null,
        nextProductId: value['auto_renew_product_id'] as String?);
  }
}
