import 'package:flutter/material.dart';
import '../models/apple_subscription.dart';

class AppleSubscriptionSummary extends StatelessWidget {
  const AppleSubscriptionSummary(
      {super.key, required this.subscription, this.planName});
  final AppleSubscription subscription;
  final String? planName;

  @override
  Widget build(BuildContext context) {
    final s = subscription;
    final locale = MaterialLocalizations.of(context);
    String date(DateTime d) =>
        '${locale.formatMediumDate(d.toLocal())} ${locale.formatTimeOfDay(TimeOfDay.fromDateTime(d.toLocal()), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
    return Semantics(
        liveRegion: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${s.sandbox ? "沙盒测试 · " : ""}${s.stateLabel}',
              style: Theme.of(context).textTheme.titleMedium),
          if (planName != null) Text(planName!),
          if (s.sandbox) const Text('测试订阅不产生真实扣费，有效期与续订速度不同于正式订阅。'),
          if (s.expiresAt != null)
            Text(
                '${s.active && s.autoRenewEnabled == true ? "本期有效至" : "有效期至"}：${date(s.expiresAt!)}'),
          if (s.active)
            Text(s.autoRenewEnabled == true
                ? '自动续订已开启；续订结果以 Apple 确认为准。'
                : s.autoRenewEnabled == false
                    ? '自动续订已关闭，本期有效期内仍可使用。'
                    : '自动续订状态待同步，请在 Apple 订阅设置中确认。'),
          if (s.pendingChange) const Text('已安排下期切换套餐，当前权益保持至切换生效。'),
          if (s.status == 3 || s.status == 4)
            const Text('请前往 Apple 订阅设置检查付款方式。'),
          if (s.status == 5) const Text('Apple 已撤销此订阅，当前不再提供该订阅权益。'),
          if (s.lastCheckedAt != null)
            Text('Apple 状态核对：${date(s.lastCheckedAt!)}',
                style: Theme.of(context).textTheme.bodySmall),
        ]));
  }
}
