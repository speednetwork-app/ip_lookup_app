import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/account_overview.dart';
import '../models/traffic_trend.dart';

class AccountInsightsCard extends StatelessWidget {
  const AccountInsightsCard({
    super.key,
    required this.overview,
    required this.sevenDayTrend,
    required this.thirtyDayTrend,
  });

  final AccountOverview overview;
  final TrafficTrend? sevenDayTrend;
  final TrafficTrend? thirtyDayTrend;

  @override
  Widget build(BuildContext context) {
    final source = thirtyDayTrend ?? sevenDayTrend;
    if (source == null || source.daily.isEmpty) return const SizedBox.shrink();

    final recentDaily = source.daily.length > 7
        ? source.daily.sublist(source.daily.length - 7)
        : source.daily;
    final recentTotal = _sum(recentDaily);
    final previousDaily = source.daily.length >= 14
        ? source.daily
            .sublist(source.daily.length - 14, source.daily.length - 7)
        : const <DailyTraffic>[];
    final previousTotal = _sum(previousDaily);
    final average = recentDaily.isEmpty ? 0 : recentTotal ~/ recentDaily.length;
    final peak = source.daily.reduce(
      (current, item) => item.totalBytes > current.totalBytes ? item : current,
    );
    final activeDays = source.daily.where((item) => item.totalBytes > 0).length;
    final remainingEstimate = average <= 0
        ? null
        : (overview.traffic.remainingBytes / average).floor();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_graph_rounded,
                  size: 21,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '用量洞察',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Insight(
                    icon: Icons.calendar_view_week_outlined,
                    label: '近 7 天',
                    value: _bytes(recentTotal),
                    detail: _comparison(previousTotal, recentTotal),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Insight(
                    icon: Icons.hourglass_bottom_rounded,
                    label: '预计可用',
                    value: remainingEstimate == null
                        ? '暂无估算'
                        : remainingEstimate > 999
                            ? '999+ 天'
                            : '$remainingEstimate 天',
                    detail: '按近 7 天日均估算',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Insight(
                    icon: Icons.show_chart_rounded,
                    label: '最高用量日',
                    value: '${peak.date.month}/${peak.date.day}',
                    detail: _bytes(peak.totalBytes),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Insight(
                    icon: Icons.event_available_outlined,
                    label: '有用量天数',
                    value: '$activeDays 天',
                    detail: '最近 ${source.daily.length} 天',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '用量估算仅供参考，实际可用时间会随每日使用情况变化。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Insight extends StatelessWidget {
  const _Insight({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

int _sum(List<DailyTraffic> values) =>
    values.fold(0, (total, item) => total + item.totalBytes);

String _comparison(int previous, int current) {
  if (previous <= 0) return '暂无上期对比';
  final change = ((current - previous) / previous * 100).round();
  if (change == 0) return '与前 7 天持平';
  return '比前 7 天${change > 0 ? '增加' : '减少'} ${change.abs()}%';
}

String _bytes(int value) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var amount = math.max(0, value).toDouble();
  var unit = 0;
  while (amount >= 1024 && unit < units.length - 1) {
    amount /= 1024;
    unit++;
  }
  final decimals = unit == 0 || amount >= 100
      ? 0
      : amount >= 10
          ? 1
          : 2;
  return '${amount.toStringAsFixed(decimals)} ${units[unit]}';
}
