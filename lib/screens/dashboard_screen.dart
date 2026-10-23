import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account_overview.dart';
import '../models/ip_info.dart';
import '../providers/auth_provider.dart';
import '../providers/ip_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    required this.onOpenNodes,
    required this.onOpenIpTools,
    required this.onOpenHistory,
    required this.onOpenAccount,
    super.key,
  });

  final VoidCallback onOpenNodes;
  final VoidCallback onOpenIpTools;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenAccount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('皮卡云'),
            Text(
              '网络信息与账号概览',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '账号中心',
            onPressed: onOpenAccount,
            icon: const Icon(Icons.account_circle_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Consumer2<AuthProvider, IpProvider>(
        builder: (context, auth, ipProvider, _) => RefreshIndicator.adaptive(
          onRefresh: () async {
            if (auth.isSignedIn) await auth.refreshAccountData();
            if (ipProvider.myIp != null) await ipProvider.loadMyIp();
          },
          child: LayoutBuilder(
            builder: (context, constraints) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _NetworkOverview(
                          info: ipProvider.myIp,
                          loading: ipProvider.isMyIpLoading,
                          error: ipProvider.myIpError,
                          onDetect: ipProvider.loadMyIp,
                          onOpenDetails: onOpenIpTools,
                        ),
                        const SizedBox(height: 24),
                        const _SectionTitle(
                          title: '账号概览',
                          subtitle: '套餐和使用情况',
                        ),
                        const SizedBox(height: 10),
                        _AccountSummary(
                          auth: auth,
                          onOpenAccount: onOpenAccount,
                        ),
                        if (auth.notices.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _LatestNotice(
                            title: auth.notices.first.title,
                            content: auth.notices.first.content,
                            onOpenAccount: onOpenAccount,
                          ),
                        ],
                        const SizedBox(height: 24),
                        const _SectionTitle(
                          title: '常用功能',
                          subtitle: '快速查看网络与账号信息',
                        ),
                        const SizedBox(height: 10),
                        _QuickActions(
                          onOpenNodes: onOpenNodes,
                          onOpenIpTools: onOpenIpTools,
                          onOpenHistory: onOpenHistory,
                          onOpenAccount: onOpenAccount,
                        ),
                        const SizedBox(height: 18),
                        const _PrivacyNotice(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NetworkOverview extends StatelessWidget {
  const _NetworkOverview({
    required this.info,
    required this.loading,
    required this.error,
    required this.onDetect,
    required this.onOpenDetails,
  });

  final IpInfo? info;
  final bool loading;
  final String error;
  final VoidCallback onDetect;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF123F66), Color(0xFF247DAA)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332C88B8),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -44,
            top: -52,
            child: _DecorativeCircle(size: 170),
          ),
          const Positioned(
            right: 70,
            bottom: -68,
            child: _DecorativeCircle(size: 128),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.public,
                        color: Colors.white,
                        size: 27,
                      ),
                    ),
                    const Spacer(),
                    _StatusPill(detected: info != null),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  '了解当前网络',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                if (info == null)
                  Text(
                    '检测公网 IP、大致位置和网络归属信息',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      height: 1.45,
                    ),
                  )
                else
                  _DetectedNetwork(info: info!),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    error,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFFFD5D5)),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: loading ? null : onDetect,
                        icon: loading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.radar),
                        label: Text(info == null ? '检测当前网络' : '重新检测'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF174E79),
                          disabledBackgroundColor:
                              Colors.white.withValues(alpha: 0.72),
                          minimumSize: const Size(0, 48),
                        ),
                      ),
                    ),
                    if (info != null) ...[
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        tooltip: '查看详情',
                        onPressed: onOpenDetails,
                        icon: const Icon(Icons.arrow_forward),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.14),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(48, 48),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectedNetwork extends StatelessWidget {
  const _DetectedNetwork({required this.info});

  final IpInfo info;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          info.ip,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _NetworkLine(icon: Icons.location_on_outlined, text: info.location),
        const SizedBox(height: 5),
        _NetworkLine(icon: Icons.router_outlined, text: info.isp),
      ],
    );
  }
}

class _NetworkLine extends StatelessWidget {
  const _NetworkLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 17),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.detected});

  final bool detected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            detected ? Icons.check_circle : Icons.touch_app_outlined,
            size: 15,
            color: Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            detected ? '已检测' : '等待检测',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.055),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

class _AccountSummary extends StatelessWidget {
  const _AccountSummary({required this.auth, required this.onOpenAccount});

  final AuthProvider auth;
  final VoidCallback onOpenAccount;

  @override
  Widget build(BuildContext context) {
    final overview = auth.overview;
    if (!auth.isSignedIn) {
      return Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onOpenAccount,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: const Icon(Icons.person_outline),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '皮卡云账号',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 4),
                      Text('查看套餐、流量和到期时间'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      );
    }

    if (overview == null) {
      return Card(
        child: ListTile(
          leading: const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          title: const Text('正在获取账号信息'),
          subtitle: auth.error.isEmpty ? null : Text(auth.error),
          onTap: onOpenAccount,
        ),
      );
    }

    final traffic = overview.traffic;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpenAccount,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.cloud_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          overview.planName.isEmpty
                              ? '皮卡云套餐'
                              : overview.planName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(_accountStatus(overview)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 17),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('流量使用 ${traffic.usagePercent.toStringAsFixed(1)}%'),
                  Text('总量 ${_formatBytes(traffic.totalBytes)}'),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: traffic.usagePercent / 100,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('已用 ${_formatBytes(traffic.usedBytes)}'),
                  Text('剩余 ${_formatBytes(traffic.remainingBytes)}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LatestNotice extends StatelessWidget {
  const _LatestNotice({
    required this.title,
    required this.content,
    required this.onOpenAccount,
  });

  final String title;
  final String content;
  final VoidCallback onOpenAccount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onOpenAccount,
        leading: Icon(
          Icons.campaign_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(title.isEmpty ? '系统公告' : title),
        subtitle: content.isEmpty
            ? null
            : Text(content, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onOpenNodes,
    required this.onOpenIpTools,
    required this.onOpenHistory,
    required this.onOpenAccount,
  });

  final VoidCallback onOpenNodes;
  final VoidCallback onOpenIpTools;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenAccount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _QuickAction(
          icon: Icons.route_outlined,
          label: '线路',
          onTap: onOpenNodes,
        ),
        _QuickAction(
          icon: Icons.radar,
          label: 'IP 检测',
          onTap: onOpenIpTools,
        ),
        _QuickAction(
          icon: Icons.history_outlined,
          label: '查询历史',
          onTap: onOpenHistory,
        ),
        _QuickAction(
          icon: Icons.person_outline,
          label: '账号中心',
          onTap: onOpenAccount,
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 150,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 18),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 21),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '仅在你主动检测时查询公网 IP，'
              '不申请设备 GPS 定位权限。',
            ),
          ),
        ],
      ),
    );
  }
}

String _accountStatus(AccountOverview overview) {
  switch (overview.state) {
    case AccountState.active:
      final days = overview.remainingDays;
      return days == null ? '套餐使用中' : '套餐使用中 · 剩余 $days 天';
    case AccountState.expired:
      return '套餐已过期';
    case AccountState.suspended:
      return '账号已停用';
    case AccountState.trafficExhausted:
      return '流量已用尽';
    case AccountState.inactive:
      return '账号未启用';
    case AccountState.unknown:
      return '账号状态待确认';
  }
}

String _formatBytes(int bytes) {
  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  if (bytes <= 0) return '0 KB';
  return '${(bytes / 1024).toStringAsFixed(1)} KB';
}
