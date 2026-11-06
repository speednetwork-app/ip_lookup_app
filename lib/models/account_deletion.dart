class AccountDeletionPreview {
  const AccountDeletionPreview(
      {required this.hasActivePackage,
      required this.balanceMinor,
      required this.commissionMinor,
      required this.requiresSettlement,
      required this.hasAppleSubscription,
      this.pendingSettlement = false});
  final bool hasActivePackage, requiresSettlement, hasAppleSubscription;
  final int balanceMinor, commissionMinor;
  final bool pendingSettlement;

  factory AccountDeletionPreview.fromJson(Map<String, dynamic> data) {
    if (data['requires_settlement'] is! bool ||
        data['balance_minor'] is! int ||
        data['commission_minor'] is! int ||
        data['has_active_package'] is! bool ||
        data['apple_subscription'] is! bool) {
      throw const FormatException('Invalid account deletion preview');
    }
    return AccountDeletionPreview(
        hasActivePackage: data['has_active_package'],
        balanceMinor: data['balance_minor'],
        commissionMinor: data['commission_minor'],
        requiresSettlement: data['requires_settlement'],
        hasAppleSubscription: data['apple_subscription'],
        pendingSettlement: data['pending_settlement'] == true);
  }
}
