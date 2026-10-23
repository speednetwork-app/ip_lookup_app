import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/network_node.dart';
import '../providers/auth_provider.dart';
import '../providers/vpn_provider.dart';

class NodesScreen extends StatefulWidget {
  const NodesScreen({required this.onOpenAccount, super.key});

  final VoidCallback onOpenAccount;

  @override
  State<NodesScreen> createState() => _NodesScreenState();
}

class _NodesScreenState extends State<NodesScreen> {
  bool _privacyAccepted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isSignedIn && auth.networkNodes.isEmpty) {
        auth.refreshNetworkNodes();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('线路'),
            Text(
              '选择线路并建立安全连接',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Consumer2<AuthProvider, VpnProvider>(
        builder: (context, auth, vpn, _) {
          if (!auth.isSignedIn) {
            return _SignedOut(onOpenAccount: widget.onOpenAccount);
          }

          return RefreshIndicator.adaptive(
            onRefresh: auth.refreshNetworkNodes,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ConnectionCard(
                          vpn: vpn,
                          onPressed: () => _toggleConnection(vpn),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '可用线路',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            if (auth.nodesLoading)
                              const SizedBox.square(
                                dimension: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              IconButton(
                                tooltip: '刷新线路',
                                onPressed: auth.refreshNetworkNodes,
                                icon: const Icon(Icons.refresh),
                              ),
                          ],
                        ),
                        const Text('仅显示账号套餐当前可访问的线路'),
                        const SizedBox(height: 10),
                        if (auth.nodesError.isNotEmpty)
                          _MessageCard(
                            icon: Icons.error_outline,
                            text: auth.nodesError,
                            color: Theme.of(context).colorScheme.errorContainer,
                          )
                        else if (!auth.nodesLoading &&
                            auth.networkNodes.isEmpty)
                          const _MessageCard(
                            icon: Icons.route_outlined,
                            text: '暂时没有可用线路，下拉即可重新加载。',
                          )
                        else
                          ...auth.networkNodes.map(
                            (node) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _NodeTile(
                                node: node,
                                selected: vpn.selectedNode?.id == node.id,
                                onTap: () => vpn.selectNode(node),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        const _DataNotice(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggleConnection(VpnProvider vpn) async {
    if (vpn.status == VpnStatus.connected) {
      await vpn.disconnect();
      return;
    }
    if (!_privacyAccepted) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('启用安全连接'),
          content: const Text(
            '连接后，设备网络流量会通过你选择的皮卡云线路传输。'
            '服务会处理建立连接所需的账号、线路和流量数据；不会出售或向第三方披露 VPN 使用数据。'
            'iOS 随后会显示系统 VPN 配置授权。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('同意并继续'),
            ),
          ],
        ),
      );
      if (accepted != true) return;
      _privacyAccepted = true;
    }
    await vpn.connect();
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.vpn, required this.onPressed});

  final VpnProvider vpn;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final connected = vpn.status == VpnStatus.connected;
    final scheme = Theme.of(context).colorScheme;
    final selected = vpn.selectedNode;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: connected
              ? const [Color(0xFF087F6D), Color(0xFF23A987)]
              : const [Color(0xFF123F66), Color(0xFF247DAA)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            connected ? Icons.shield : Icons.shield_outlined,
            size: 58,
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            _statusText(vpn.status),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            selected == null
                ? '请先从下方选择线路'
                : '${selected.name} · ${selected.protocol}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ),
          if (vpn.error.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              vpn.error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFFD5D5)),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: vpn.isBusy || selected == null ? null : onPressed,
            icon: vpn.isBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(connected
                    ? Icons.stop_circle_outlined
                    : Icons.power_settings_new),
            label: Text(connected ? '断开连接' : '连接'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.white,
              foregroundColor:
                  connected ? const Color(0xFF087F6D) : scheme.primary,
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  String _statusText(VpnStatus status) {
    switch (status) {
      case VpnStatus.connecting:
        return '正在连接';
      case VpnStatus.connected:
        return '已安全连接';
      case VpnStatus.disconnecting:
        return '正在断开';
      case VpnStatus.disconnected:
        return '未连接';
    }
  }
}

class _NodeTile extends StatelessWidget {
  const _NodeTile({
    required this.node,
    required this.selected,
    required this.onTap,
  });

  final NetworkNode node;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: selected ? scheme.primaryContainer : null,
      child: ListTile(
        enabled: node.isOnline,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _statusColor(node.availability).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(Icons.route, color: _statusColor(node.availability)),
        ),
        title: Text(
          node.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${node.protocol} · ${_availabilityText(node.availability)} · '
            '${_loadText(node.loadLevel)}${node.loadEstimated ? '（估）' : ''} · '
            '${node.rate.toStringAsFixed(2)}x',
          ),
        ),
        trailing: selected
            ? Icon(Icons.check_circle, color: scheme.primary)
            : const Icon(Icons.chevron_right),
      ),
    );
  }

  Color _statusColor(NodeAvailability availability) {
    switch (availability) {
      case NodeAvailability.online:
        return const Color(0xFF0A9F7F);
      case NodeAvailability.heartbeat:
        return const Color(0xFFAD7917);
      case NodeAvailability.offline:
        return const Color(0xFFC04A5D);
    }
  }

  String _availabilityText(NodeAvailability availability) {
    switch (availability) {
      case NodeAvailability.online:
        return '在线';
      case NodeAvailability.heartbeat:
        return '仅心跳';
      case NodeAvailability.offline:
        return '离线';
    }
  }

  String _loadText(String load) {
    switch (load) {
      case 'relaxed':
        return '负载宽松';
      case 'moderate':
        return '负载较高';
      case 'busy':
        return '负载繁忙';
      default:
        return '负载未知';
    }
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut({required this.onOpenAccount});

  final VoidCallback onOpenAccount;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            children: [
              const Icon(Icons.lock_outline, size: 64),
              const SizedBox(height: 18),
              Text('登录后查看可用线路',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              const Text(
                '线路由你的现有皮卡云账号和套餐决定。IP 检测仍可免登录使用。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onOpenAccount,
                icon: const Icon(Icons.login),
                label: const Text('前往登录'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _DataNotice extends StatelessWidget {
  const _DataNotice();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.privacy_tip_outlined, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '首次连接前会说明网络数据用途，并由 iOS 显示系统 VPN 授权。线路凭证不会写入普通缓存。',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
