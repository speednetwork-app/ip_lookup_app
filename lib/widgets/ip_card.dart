import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/ip_info.dart';
import '../theme/pikayun_theme.dart';
import 'app_icon_tile.dart';
import 'app_surface.dart';
import 'ip_map.dart';

class IpCard extends StatelessWidget {
  const IpCard({super.key, required this.ipInfo, this.showMap = true});
  final IpInfo ipInfo;
  final bool showMap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSurface(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIconTile(
                  icon: Icons.public,
                  size: 44,
                  foregroundColor: scheme.primary,
                  backgroundColor: scheme.primaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      ipInfo.ip,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(ipInfo.location,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showMap) ...[
          const SizedBox(height: 12),
          IpMap(info: ipInfo, height: 220),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                    child: Text('基于 IP 的近似位置，非设备 GPS，可能与实际位置存在较大误差。',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant))),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        AppSurface(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              _InfoRow(label: '国家', value: ipInfo.country),
              _InfoRow(label: '地区', value: ipInfo.region),
              _InfoRow(label: '城市', value: ipInfo.city),
              _InfoRow(label: '时区', value: ipInfo.timezone),
              _InfoRow(label: '运营商', value: ipInfo.isp),
              if (ipInfo.hasLocation)
                _InfoRow(
                    label: '估算坐标',
                    value:
                        '${ipInfo.latitude.toStringAsFixed(4)}, ${ipInfo.longitude.toStringAsFixed(4)}'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _copyToClipboard(context),
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('复制 IP'),
        ),
      ],
    );
  }

  Future<void> _copyToClipboard(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: ipInfo.ip));
    messenger.showSnackBar(const SnackBar(
        content: Text('IP 已复制'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating));
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: context.pikayunColors.separator, width: .5))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 64,
                child: Text(label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant))),
            const SizedBox(width: 8),
            Expanded(
                child: SelectableText(value.isEmpty ? '暂无数据' : value,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      );
}
