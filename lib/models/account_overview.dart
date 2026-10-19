enum AccountState {
  active,
  expired,
  suspended,
  trafficExhausted,
  inactive,
  unknown,
}

class TrafficOverview {
  const TrafficOverview({
    required this.usedBytes,
    required this.remainingBytes,
    required this.totalBytes,
    required this.usagePercent,
  });

  final int usedBytes;
  final int remainingBytes;
  final int totalBytes;
  final double usagePercent;

  factory TrafficOverview.fromJson(Map<String, dynamic> json) {
    final total = _nonNegativeInt(json['total_bytes']);
    final used = _nonNegativeInt(json['used_bytes']);
    return TrafficOverview(
      usedBytes: used,
      remainingBytes: _nonNegativeInt(json['remaining_bytes']),
      totalBytes: total,
      usagePercent: _toDouble(json['usage_percent']).clamp(0, 100),
    );
  }

  Map<String, dynamic> toJson() => {
        'used_bytes': usedBytes,
        'remaining_bytes': remainingBytes,
        'total_bytes': totalBytes,
        'usage_percent': usagePercent,
      };
}

class AccountOverview {
  const AccountOverview({
    required this.state,
    required this.planName,
    required this.traffic,
    required this.expiredAt,
    required this.remainingDays,
    required this.nextResetAt,
    required this.deviceLimit,
    required this.speedLimitMbps,
    required this.subscribeUrl,
  });

  final AccountState state;
  final String planName;
  final TrafficOverview traffic;
  final DateTime? expiredAt;
  final int? remainingDays;
  final DateTime? nextResetAt;
  final int deviceLimit;
  final int speedLimitMbps;
  final String subscribeUrl;

  factory AccountOverview.fromJson(Map<String, dynamic> json) {
    final trafficValue = json['traffic'];
    final traffic = trafficValue is Map
        ? Map<String, dynamic>.from(trafficValue)
        : const <String, dynamic>{};
    return AccountOverview(
      state: _accountState(json['account_status']),
      planName: _toText(json['plan_name']),
      traffic: TrafficOverview.fromJson(traffic),
      expiredAt: _toDateTime(json['expired_at']),
      remainingDays: json['remaining_days'] == null
          ? null
          : _boundedInt(json['remaining_days']),
      nextResetAt: _toDateTime(json['next_reset_at']),
      deviceLimit: _boundedInt(json['device_limit']),
      speedLimitMbps: _boundedInt(json['speed_limit_mbps']),
      subscribeUrl: _toText(json['subscribe_url']),
    );
  }

  /// A deliberately limited representation for local display cache.
  /// The subscription URL and all authentication material are excluded.
  Map<String, dynamic> toCacheJson() => {
        'account_status': _accountStateText(state),
        'plan_name': planName,
        'traffic': traffic.toJson(),
        'expired_at': _toEpochSeconds(expiredAt),
        'remaining_days': remainingDays,
        'next_reset_at': _toEpochSeconds(nextResetAt),
        'device_limit': deviceLimit,
        'speed_limit_mbps': speedLimitMbps,
      };
}

AccountState _accountState(dynamic value) {
  switch (_toText(value)) {
    case 'active':
      return AccountState.active;
    case 'expired':
      return AccountState.expired;
    case 'suspended':
      return AccountState.suspended;
    case 'traffic_exhausted':
      return AccountState.trafficExhausted;
    case 'inactive':
      return AccountState.inactive;
    default:
      return AccountState.unknown;
  }
}

String _accountStateText(AccountState value) {
  switch (value) {
    case AccountState.active:
      return 'active';
    case AccountState.expired:
      return 'expired';
    case AccountState.suspended:
      return 'suspended';
    case AccountState.trafficExhausted:
      return 'traffic_exhausted';
    case AccountState.inactive:
      return 'inactive';
    case AccountState.unknown:
      return 'unknown';
  }
}

DateTime? _toDateTime(dynamic value) {
  if (value == null) return null;
  final seconds = _toInt(value);
  if (seconds <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true)
      .toLocal();
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int _nonNegativeInt(dynamic value) {
  final number = _toInt(value);
  return number < 0 ? 0 : number;
}

int _boundedInt(dynamic value) {
  final number = _nonNegativeInt(value);
  return number > 1000000 ? 1000000 : number;
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _toText(dynamic value) => value is String ? value.trim() : '';

int? _toEpochSeconds(DateTime? value) =>
    value == null ? null : value.toUtc().millisecondsSinceEpoch ~/ 1000;
