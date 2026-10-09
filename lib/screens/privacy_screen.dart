import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/history_provider.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('隐私与数据')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SummaryCard(),
          const SizedBox(height: 16),
          Text('数据如何使用', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const _InfoTile(
            icon: Icons.public,
            title: '公网 IP 与查询内容',
            description: '查询时，当前公网 IP 或你输入的 IP 地址会发送至 '
                'ipwho.is；该服务不可用时会改用 ipapi.co。',
          ),
          const _InfoTile(
            icon: Icons.location_on_outlined,
            title: 'IP 估算位置',
            description: '国家、地区、城市和坐标由 IP 地址估算。'
                '本 App 不申请或访问设备 GPS 定位，结果可能存在较大误差。',
          ),
          const _InfoTile(
            icon: Icons.map_outlined,
            title: '地图',
            description: '显示地图时，会向 OpenStreetMap 请求对应区域的地图图块。',
          ),
          const _InfoTile(
            icon: Icons.history,
            title: '本地查询历史',
            description: '查询历史最多保存 50 条，仅存于此设备，不会同步到云端。'
                '卸载 App 会删除这些记录。',
          ),
          const SizedBox(height: 16),
          Text('我们不会做什么', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Card(
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CheckRow(text: '不读取姓名、邮箱、手机号或通讯录'),
                  _CheckRow(text: '不访问照片、相机或麦克风'),
                  _CheckRow(text: '不申请 GPS 定位权限'),
                  _CheckRow(text: '不包含广告、分析 SDK 或用户追踪'),
                  _CheckRow(text: '不包含账号、付费或应用内购买'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('管理本地数据', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Consumer<HistoryProvider>(
            builder: (context, history, _) => OutlinedButton.icon(
              onPressed: history.entries.isEmpty
                  ? null
                  : () => _confirmClear(context, history),
              icon: const Icon(Icons.delete_outline),
              label: const Text('清空本机查询历史'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '第三方服务：ipwho.is、ipapi.co、OpenStreetMap\n'
            '隐私问题联系：info@robinads.agency',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
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
        title: const Text('清空本机查询历史？'),
        content: const Text('所有查询记录都会从此设备删除，此操作无法撤销。'),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.privacy_tip_outlined, size: 40, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              '隐私说明',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              '本 App 仅处理完成 IP 查询所需的数据，不访问设备 GPS，'
              '不包含广告或用户追踪。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(description),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
