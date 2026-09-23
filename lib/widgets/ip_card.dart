import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/ip_info.dart';
import 'ip_map.dart';

class IpCard extends StatelessWidget {
  const IpCard({super.key, required this.ipInfo, this.showMap = true});

  final IpInfo ipInfo;
  final bool showMap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              ipInfo.ip,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              ipInfo.location,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (showMap) ...[
              const SizedBox(height: 16),
              IpMap(info: ipInfo),
            ],
            const SizedBox(height: 16),
            _InfoRow(label: '国家', value: ipInfo.country),
            _InfoRow(label: '地区', value: ipInfo.region),
            _InfoRow(label: '城市', value: ipInfo.city),
            _InfoRow(label: '时区', value: ipInfo.timezone),
            _InfoRow(label: '运营商', value: ipInfo.isp),
            if (ipInfo.hasLocation)
              _InfoRow(
                label: '坐标',
                value: '${ipInfo.latitude.toStringAsFixed(4)}, '
                    '${ipInfo.longitude.toStringAsFixed(4)}',
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _copyToClipboard(context),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('复制 IP'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyToClipboard(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: ipInfo.ip));
    messenger.showSnackBar(
      SnackBar(
        content: Text('已复制 ${ipInfo.ip}'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
