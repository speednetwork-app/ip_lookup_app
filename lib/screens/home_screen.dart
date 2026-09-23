import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ip_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/ip_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的 IP')),
      body: Consumer<IpProvider>(
        builder: (context, provider, _) {
          if (provider.isMyIpLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.myIpError.isNotEmpty) {
            return ErrorView(
              message: provider.myIpError,
              onRetry: provider.loadMyIp,
            );
          }

          final info = provider.myIp;
          if (info == null) {
            return EmptyState(
              icon: Icons.public_off,
              title: '还没有获取到 IP',
              message: '点击下方按钮获取当前网络的公网 IP 地址',
              action: FilledButton.icon(
                onPressed: provider.loadMyIp,
                icon: const Icon(Icons.refresh),
                label: const Text('获取'),
              ),
            );
          }

          // 下拉刷新——用户换了网络（比如切 Wi-Fi）后会想重新获取
          return RefreshIndicator(
            onRefresh: provider.loadMyIp,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                IpCard(ipInfo: info),
                const SizedBox(height: 12),
                Text(
                  '下拉可刷新',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
