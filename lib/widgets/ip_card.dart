import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ip_info.dart';

class IpCard extends StatelessWidget {
  final IpInfo ipInfo;

  const IpCard({super.key, required this.ipInfo});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              ipInfo.ip,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _InfoRow(label: '国家', value: ipInfo.country),
            _InfoRow(label: '地区', value: ipInfo.region),
            _InfoRow(label: '城市', value: ipInfo.city),
            _InfoRow(label: '时区', value: ipInfo.timezone),
            _InfoRow(label: 'ISP', value: ipInfo.isp),
            _InfoRow(
              label: '坐标',
              value: '${ipInfo.latitude.toStringAsFixed(4)}, ${ipInfo.longitude.toStringAsFixed(4)}',
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _copyToClipboard(context),
              icon: const Icon(Icons.copy),
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
        content: Text('已复制: ${ipInfo.ip}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
