import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ip_provider.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/app_page_title.dart';
import '../widgets/empty_state.dart';
import '../widgets/ip_card.dart';
import 'lookup_screen.dart';
import 'privacy_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppPageTitle(
          title: 'IP 检测',
          subtitle: '公网地址与近似位置',
          icon: Icons.radar_rounded,
        ),
        actions: [
          IconButton(
            tooltip: '查询指定 IP',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const LookupScreen()),
            ),
            icon: const Icon(Icons.search),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PrivacyScreen(),
              ),
            ),
            icon: const Icon(Icons.privacy_tip_outlined, size: 18),
            label: const Text('隐私'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppBackdrop(
        child: Consumer<IpProvider>(
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
              title: '查询当前公网 IP',
              message: '点击后会通过 ipwho.is 或 ipapi.co 查询当前网络的'
                  '公网 IP 和大致归属地。\n\n'
                  '不会请求或访问设备 GPS 定位。',
              action: FilledButton.icon(
                onPressed: provider.loadMyIp,
                icon: const Icon(Icons.public),
                label: const Text('查询我的公网 IP'),
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
      ),
    );
  }
}
