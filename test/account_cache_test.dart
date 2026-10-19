import 'package:flutter_test/flutter_test.dart';
import 'package:ip_lookup_app/models/account_overview.dart';
import 'package:ip_lookup_app/services/account_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('safe overview cache never persists the subscription URL', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = SharedPreferencesAccountCache();
    const overview = AccountOverview(
      state: AccountState.trafficExhausted,
      planName: 'Example Plan',
      traffic: TrafficOverview(
        usedBytes: 100,
        remainingBytes: 0,
        totalBytes: 100,
        usagePercent: 100,
      ),
      expiredAt: null,
      remainingDays: 3,
      nextResetAt: null,
      deviceLimit: 2,
      speedLimitMbps: 10,
      subscribeUrl: 'https://example.com/secret',
    );

    await cache.writeOverview(overview);
    final restored = await cache.readOverview();

    expect(restored?.state, AccountState.trafficExhausted);
    expect(restored?.subscribeUrl, isEmpty);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getKeys(), hasLength(1));
    expect(
      preferences.getString(preferences.getKeys().single),
      isNot(contains('example.com/secret')),
    );
  });
}
