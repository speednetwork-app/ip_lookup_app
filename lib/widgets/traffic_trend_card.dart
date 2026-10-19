import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/traffic_trend.dart';

class TrafficTrendCard extends StatelessWidget {
  const TrafficTrendCard({
    super.key,
    required this.trend,
    required this.selectedRange,
    required this.loading,
    required this.onRangeChanged,
  });

  final TrafficTrend? trend;
  final TrafficRange selectedRange;
  final bool loading;
  final ValueChanged<TrafficRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, size: 21, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '流量趋势',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                SegmentedButton<TrafficRange>(
                  showSelectedIcon: false,
                  segments: TrafficRange.values
                      .map(
                        (range) => ButtonSegment<TrafficRange>(
                          value: range,
                          label: Text(
                              range == TrafficRange.sevenDays ? '7天' : '30天'),
                        ),
                      )
                      .toList(growable: false),
                  selected: {selectedRange},
                  onSelectionChanged:
                      loading ? null : (values) => onRangeChanged(values.first),
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (trend == null)
              SizedBox(
                height: 150,
                child: Center(
                  child: Text(
                    loading ? '正在加载趋势…' : '暂无趋势数据',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child:
                        _Value(label: '期间使用', value: _bytes(trend!.usedBytes)),
                  ),
                  Expanded(
                    child: _Value(
                      label: '日均使用',
                      value: _bytes(trend!.averageDailyBytes),
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Legend(
                    color: scheme.primary,
                    label: '上传 ${_bytes(trend!.uploadBytes)}',
                  ),
                  const SizedBox(width: 16),
                  _Legend(
                    color: scheme.primary.withValues(alpha: 0.38),
                    label: '下载 ${_bytes(trend!.downloadBytes)}',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Semantics(
                label:
                    '${selectedRange.label}流量柱状图，上传${_bytes(trend!.uploadBytes)}，下载${_bytes(trend!.downloadBytes)}，期间使用${_bytes(trend!.usedBytes)}，日均${_bytes(trend!.averageDailyBytes)}',
                image: true,
                child: SizedBox(
                  height: 132,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _BarsPainter(
                      daily: trend!.daily,
                      color: scheme.primary,
                      gridColor: scheme.outlineVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _DateLabels(daily: trend!.daily),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.today_outlined,
                      size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Expanded(child: Text('今日 ${_bytes(trend!.todayBytes)}')),
                  Text(
                    _updatedText(trend!.updatedAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _DateLabels extends StatelessWidget {
  const _DateLabels({required this.daily});

  final List<DailyTraffic> daily;

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) return const SizedBox.shrink();
    final middle = daily[daily.length ~/ 2].date;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [daily.first.date, middle, daily.last.date]
          .map(
            (date) => Text(
              '${date.month}/${date.day}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _BarsPainter extends CustomPainter {
  const _BarsPainter({
    required this.daily,
    required this.color,
    required this.gridColor,
  });

  final List<DailyTraffic> daily;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.65)
      ..strokeWidth = 1;
    for (var row = 0; row <= 2; row++) {
      final y = size.height * row / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (daily.isEmpty) return;

    final maximum = daily.map((item) => item.totalBytes).reduce(math.max);
    final slot = size.width / daily.length;
    final barWidth = math.max(2.0, slot * 0.58);
    final uploadPaint = Paint()..color = color;
    final downloadPaint = Paint()..color = color.withValues(alpha: 0.38);
    for (var index = 0; index < daily.length; index++) {
      final item = daily[index];
      final totalRatio = maximum == 0 ? 0.0 : item.totalBytes / maximum;
      final height =
          totalRatio == 0 ? 2.0 : math.max(4.0, size.height * totalRatio);
      final uploadRatio =
          item.totalBytes == 0 ? 0.0 : item.uploadBytes / item.totalBytes;
      final uploadHeight = height * uploadRatio;
      final downloadHeight = height - uploadHeight;
      final left = index * slot + (slot - barWidth) / 2;
      final downloadRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, size.height - height, barWidth, downloadHeight),
        const Radius.circular(3),
      );
      final uploadRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          left,
          size.height - uploadHeight,
          barWidth,
          math.max(2, uploadHeight),
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(downloadRect, downloadPaint);
      canvas.drawRRect(uploadRect, uploadPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter oldDelegate) =>
      oldDelegate.daily != daily ||
      oldDelegate.color != color ||
      oldDelegate.gridColor != gridColor;
}

String _bytes(int value) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var amount = value.toDouble();
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

String _updatedText(DateTime? value) {
  if (value == null) return '等待统计更新';
  final local = value.toLocal();
  return '更新于 ${local.month}/${local.day} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
