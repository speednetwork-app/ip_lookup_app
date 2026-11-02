import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/network_node.dart';
import '../providers/auth_provider.dart';
import '../theme/pikayun_theme.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/app_page_title.dart';

class NodesScreen extends StatefulWidget {
  const NodesScreen({required this.onOpenAccount, super.key});

  final VoidCallback onOpenAccount;

  @override
  State<NodesScreen> createState() => _NodesScreenState();
}

class _NodesScreenState extends State<NodesScreen> {
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
        title: const AppPageTitle(
          title: '线路',
          subtitle: '选择当前可用线路',
          icon: Icons.alt_route_rounded,
        ),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, auth, _) => IconButton(
              tooltip: '刷新线路',
              onPressed: !auth.isSignedIn || auth.nodesLoading
                  ? null
                  : auth.refreshNetworkNodes,
              icon: auth.nodesLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppBackdrop(
        child: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (!auth.isSignedIn) {
              return _SignedOut(onOpenAccount: widget.onOpenAccount);
            }
            final nodes = [...auth.networkNodes]..sort(_compareNodes);
            final onlineNodes = nodes.where((node) => node.isOnline).toList();
            final recommendedId =
                onlineNodes.isEmpty ? null : onlineNodes.first.id;
            final visibleNodes =
                auth.nodesError.isEmpty ? nodes : <NetworkNode>[];
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: RefreshIndicator.adaptive(
                  onRefresh: auth.refreshNetworkNodes,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: visibleNodes.length + 2,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _NodesHeader(
                            onlineCount: onlineNodes.length,
                            totalCount: nodes.length,
                          ),
                        );
                      }
                      if (index <= visibleNodes.length) {
                        final node = visibleNodes[index - 1];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _NodeTile(
                            node: node,
                            recommended: node.id == recommendedId,
                            selected: node.id == auth.selectedNetworkNodeId,
                            onSelected: () => auth.selectNetworkNode(node),
                          ),
                        );
                      }
                      if (auth.nodesError.isNotEmpty) {
                        return _MessageCard(
                          icon: Icons.error_outline,
                          text: auth.nodesError,
                          color: Theme.of(context).colorScheme.errorContainer,
                        );
                      }
                      if (!auth.nodesLoading && nodes.isEmpty) {
                        return const _MessageCard(
                          icon: Icons.route_outlined,
                          text: '暂时没有可用线路，下拉即可重新加载。',
                        );
                      }
                      return const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: _DataNotice(),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static int _compareNodes(NetworkNode left, NetworkNode right) {
    final availability = _availabilityRank(left.availability)
        .compareTo(_availabilityRank(right.availability));
    if (availability != 0) return availability;
    final load =
        _loadRank(left.loadLevel).compareTo(_loadRank(right.loadLevel));
    if (load != 0) return load;
    final rate = left.rate.compareTo(right.rate);
    if (rate != 0) return rate;
    return left.name.compareTo(right.name);
  }

  static int _availabilityRank(NodeAvailability value) {
    switch (value) {
      case NodeAvailability.online:
        return 0;
      case NodeAvailability.heartbeat:
        return 1;
      case NodeAvailability.offline:
        return 2;
    }
  }

  static int _loadRank(String value) {
    switch (value) {
      case 'relaxed':
        return 0;
      case 'moderate':
        return 1;
      case 'unknown':
        return 2;
      case 'busy':
        return 3;
      default:
        return 4;
    }
  }
}

class _NodesHeader extends StatelessWidget {
  const _NodesHeader({required this.onlineCount, required this.totalCount});
  final int onlineCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.pikayunColors;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MetaChip(
            label: '全部 $totalCount',
            foreground: scheme.onPrimaryContainer,
            background: scheme.primaryContainer),
        _MetaChip(
            label: '在线 $onlineCount',
            foreground: colors.success,
            background: colors.successContainer),
      ],
    );
  }
}

class _NodeTile extends StatelessWidget {
  const _NodeTile({
    required this.node,
    required this.recommended,
    required this.selected,
    required this.onSelected,
  });
  final NetworkNode node;
  final bool recommended;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.pikayunColors;
    final available = node.isOnline && node.protocol == 'VLESS';
    final status = switch (node.availability) {
      NodeAvailability.online => '在线',
      NodeAvailability.heartbeat => '仅心跳',
      NodeAvailability.offline => '离线',
    };
    final statusColor = switch (node.availability) {
      NodeAvailability.online => colors.success,
      NodeAvailability.heartbeat => colors.warning,
      NodeAvailability.offline => scheme.error,
    };
    final load = switch (node.loadLevel) {
      'relaxed' => '流畅',
      'moderate' => '较忙',
      'busy' => '繁忙',
      _ => '负载未知',
    };
    final loadColor = switch (node.loadLevel) {
      'relaxed' => colors.success,
      'moderate' => colors.warning,
      'busy' => scheme.error,
      _ => scheme.onSurfaceVariant,
    };
    final rate = node.rate == node.rate.roundToDouble()
        ? node.rate.toInt().toString()
        : node.rate.toStringAsFixed(1);
    return Semantics(
      button: available,
      selected: selected,
      label:
          '${node.name}，$status，${node.protocol}，倍率 $rate，$load，延迟未测，在线人数暂无数据',
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: selected
              ? BorderSide(color: scheme.primary.withValues(alpha: .4))
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: available ? onSelected : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 66),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 32,
                    decoration: BoxDecoration(
                      color: selected
                          ? colors.brandSurface.withValues(alpha: .55)
                          : scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.public,
                        size: 18, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (selected) ...[
                              Icon(Icons.check_circle,
                                  size: 14, color: scheme.primary),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                node.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: node.isOnline
                                          ? scheme.onSurface
                                          : scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: '暂未提供延迟测量数据',
                              child: Text('未测',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: scheme.onSurfaceVariant)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(status,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                        color: statusColor,
                                        fontWeight: FontWeight.w600)),
                            Text('${node.protocol} · ${rate}x',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: scheme.onSurfaceVariant)),
                            Tooltip(
                              message: '节点在线人数尚未提供',
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.people_outline,
                                        size: 13,
                                        color: scheme.onSurfaceVariant),
                                    const SizedBox(width: 3),
                                    Text('暂无数据',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                                color:
                                                    scheme.onSurfaceVariant)),
                                  ]),
                            ),
                            Tooltip(
                              message:
                                  node.loadEstimated ? '负载由服务端估算' : '服务端负载状态',
                              child: Text(load,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                          color: loadColor,
                                          fontWeight: FontWeight.w600)),
                            ),
                            if (selected)
                              Text('已选',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                          color: scheme.primary,
                                          fontWeight: FontWeight.w700))
                            else if (recommended)
                              Text('推荐',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: scheme.primary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(
      {required this.label,
      required this.foreground,
      required this.background});
  final String label;
  final Color foreground;
  final Color background;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: background, borderRadius: BorderRadius.circular(99)),
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: foreground, fontWeight: FontWeight.w600)),
      );
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
                '线路名称、协议、在线状态和负载来自皮卡云服务，仅在登录后读取。',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
