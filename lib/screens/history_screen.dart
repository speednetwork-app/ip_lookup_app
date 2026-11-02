import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/history_entry.dart';
import '../providers/history_provider.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/app_page_title.dart';
import '../widgets/empty_state.dart';
import '../widgets/ip_card.dart';
import '../widgets/app_icon_tile.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, this.onOpenIp});

  final VoidCallback? onOpenIp;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppPageTitle(
          title: '查询历史',
          subtitle: '仅保存在当前设备',
          icon: Icons.history_rounded,
        ),
        actions: [
          Consumer<HistoryProvider>(
            builder: (context, history, _) => history.entries.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: '清空历史',
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: history.entries.isEmpty
                        ? null
                        : () => _confirmClear(context, history),
                  ),
          ),
        ],
      ),
      body: AppBackdrop(
        child: Consumer<HistoryProvider>(
          builder: (context, history, _) {
            if (!history.isLoaded) {
              return const Center(child: CircularProgressIndicator());
            }

            if (history.isEmpty) {
              return EmptyState(
                icon: Icons.history_toggle_off,
                title: '还没有查询记录',
                message: '查询过的 IP 会自动保存在这里，仅存于本设备',
                action: onOpenIp == null
                    ? null
                    : FilledButton.icon(
                        onPressed: onOpenIp,
                        icon: const Icon(Icons.public),
                        label: const Text('立即检测 IP'),
                      ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: history.entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final entry = history.entries[i];
                return Dismissible(
                  key: ValueKey(entry.info.ip),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_outline),
                  ),
                  onDismissed: (_) => history.remove(entry.info.ip),
                  child: _HistoryTile(entry: entry),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    HistoryProvider history,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空查询历史？'),
        content: const Text('所有记录会从本设备删除，此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) await history.clear();
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        tileColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        leading: const AppIconTile(icon: Icons.public, size: 40),
        title: Text(entry.info.ip,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.info.location,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 3),
              Text(_relativeTime(entry.queriedAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.8,
            builder: (_, controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.all(16),
              children: [IpCard(ipInfo: entry.info)],
            ),
          ),
        ),
      ),
    );
  }

  /// 相对时间比绝对时间戳更好读——"3 分钟前"比"2026-09-23 10:28"
  /// 更快让人判断这条记录新不新。
  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-'
        '${time.day.toString().padLeft(2, '0')}';
  }
}
