import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/account_overview.dart';
import '../models/traffic_trend.dart';

abstract class AccountCache {
  Future<AccountOverview?> readOverview();
  Future<TrafficTrend?> readTrend(TrafficRange range);
  Future<void> writeOverview(AccountOverview overview);
  Future<void> writeTrend(TrafficTrend trend);
  Future<void> clear();
}

class SharedPreferencesAccountCache implements AccountCache {
  static const _overviewKey = 'account_overview_safe_cache_v1';
  static const _trendPrefix = 'account_traffic_safe_cache_v1_';

  @override
  Future<AccountOverview?> readOverview() async {
    final preferences = await SharedPreferences.getInstance();
    return _decode(
      preferences.getString(_overviewKey),
      AccountOverview.fromJson,
    );
  }

  @override
  Future<TrafficTrend?> readTrend(TrafficRange range) async {
    final preferences = await SharedPreferences.getInstance();
    return _decode(
      preferences.getString('$_trendPrefix${range.apiValue}'),
      TrafficTrend.fromJson,
    );
  }

  @override
  Future<void> writeOverview(AccountOverview overview) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _overviewKey,
      jsonEncode(overview.toCacheJson()),
    );
  }

  @override
  Future<void> writeTrend(TrafficTrend trend) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '$_trendPrefix${trend.range.apiValue}',
      jsonEncode(trend.toJson()),
    );
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_overviewKey);
    for (final range in TrafficRange.values) {
      await preferences.remove('$_trendPrefix${range.apiValue}');
    }
  }

  T? _decode<T>(String? value, T Function(Map<String, dynamic>) parser) {
    if (value == null || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      return parser(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }
}
