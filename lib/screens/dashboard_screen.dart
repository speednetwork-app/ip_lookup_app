import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../services/vpn_service.dart';
import '../theme/pikayun_theme.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/app_icon_tile.dart';
import '../widgets/app_surface.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    required this.onOpenNodes,
    required this.onOpenAccount,
    super.key,
  });

  final VoidCallback onOpenNodes;
  final VoidCallback onOpenAccount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 16,
        title: Row(
          children: [
            AppIconTile(
              icon: Icons.bolt_rounded,
              size: 38,
              iconSize: 23,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '皮卡云',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '安全 · 稳定 · 网络工具',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '打开账号中心',
            onPressed: onOpenAccount,
            icon: const Icon(Icons.account_circle_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppBackdrop(
        showSignalField: false,
        child: Consumer<AuthProvider>(
          builder: (context, auth, _) => RefreshIndicator.adaptive(
            onRefresh: () async {
              if (!auth.isSignedIn) return;
              await Future.wait([
                auth.refreshAccountData(),
                auth.refreshNetworkNodes(),
              ]);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ConnectionConsole(
                          auth: auth,
                          onOpenNodes: onOpenNodes,
                          onOpenAccount: onOpenAccount,
                        ),
                        const SizedBox(height: 16),
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

class _ConnectionConsole extends StatefulWidget {
  const _ConnectionConsole({
    required this.auth,
    required this.onOpenNodes,
    required this.onOpenAccount,
  });

  final AuthProvider auth;
  final VoidCallback onOpenNodes;
  final VoidCallback onOpenAccount;

  @override
  State<_ConnectionConsole> createState() => _ConnectionConsoleState();
}

class _ConnectionConsoleState extends State<_ConnectionConsole> {
  static const _disclosureAcceptedKey = 'vpn_disclosure_accepted_v1';

  AuthProvider get auth => widget.auth;

  bool get _active =>
      auth.vpnStatus == VpnConnectionStatus.connected ||
      auth.vpnStatus == VpnConnectionStatus.connecting ||
      auth.vpnStatus == VpnConnectionStatus.reasserting;

  bool get _connected => auth.vpnStatus == VpnConnectionStatus.connected;

  bool get _enabled =>
      auth.isSignedIn &&
      auth.vpnStatus != VpnConnectionStatus.unsupported &&
      auth.vpnStatus != VpnConnectionStatus.invalid;

  Future<void> _handlePrimaryAction() async {
    if (!auth.isSignedIn) {
      widget.onOpenAccount();
      return;
    }
    if (!_enabled || auth.vpnBusy) return;
    if (_active) {
      await auth.toggleVpn();
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    final accepted = preferences.getBool(_disclosureAcceptedKey) ?? false;
    if (!accepted) {
      if (!mounted) return;
      final confirmed = await _showVpnDisclosure();
      if (confirmed != true) return;
      await preferences.setBool(_disclosureAcceptedKey, true);
    }

    HapticFeedback.selectionClick();
    await auth.toggleVpn();
  }

  Future<bool?> _showVpnDisclosure() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        icon: const Icon(Icons.shield_outlined),
        title: const Text('开启 VPN 安全连接'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '连接后，设备网络流量会通过您选择的皮卡云线路传输。iOS 将要求您允许添加 VPN 配置。',
            ),
            SizedBox(height: 12),
            _DisclosureItem(
              icon: Icons.route_outlined,
              text: 'VPN 仅在您主动开启后连接，可随时使用同一按钮断开。',
            ),
            SizedBox(height: 8),
            _DisclosureItem(
              icon: Icons.location_off_outlined,
              text: '应用不读取设备 GPS；位置数据来自公网 IP 的近似归属地。',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('同意并连接'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.pikayunColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final onlineCount = auth.networkNodes.where((node) => node.isOnline).length;
    final selectedNodeName = _selectedNodeName();

    return Column(
      children: [
        SizedBox(
          height: 390,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                top: 26,
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: _WorldNetworkPainter(
                      lineColor: scheme.primary.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
                            ? .28
                            : .16,
                      ),
                      nodeColor: colors.heroAccent.withValues(alpha: .55),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                child: _SecurityStatusPill(
                  connected: _connected,
                  label: _securityLabel(),
                ),
              ),
              Positioned(
                top: 110,
                child: Semantics(
                  button: true,
                  enabled: _enabled || !auth.isSignedIn,
                  label: _primaryTitle(),
                  hint: _active ? '双击断开 VPN' : '双击开启 VPN',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: auth.vpnBusy ? null : _handlePrimaryAction,
                      child: AnimatedContainer(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 260),
                        width: 142,
                        height: 142,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: const Alignment(-.28, -.34),
                            colors: _connected
                                ? [
                                    colors.successContainer,
                                    colors.success,
                                  ]
                                : [
                                    const Color(0xFF6DB8FF),
                                    scheme.primary,
                                  ],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .84),
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (_connected ? colors.success : scheme.primary)
                                      .withValues(alpha: .28),
                              blurRadius: 34,
                              spreadRadius: 8,
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: .7),
                              blurRadius: 0,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Center(
                          child: auth.vpnBusy && !reduceMotion
                              ? const SizedBox.square(
                                  dimension: 48,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 4,
                                  ),
                                )
                              : const Icon(
                                  Icons.power_settings_new_rounded,
                                  color: Colors.white,
                                  size: 66,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 282,
                left: 16,
                right: 16,
                child: Column(
                  children: [
                    Text(
                      _primaryTitle(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _secondaryStatus(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        AppSurface(
          onTap: _active ? null : widget.onOpenNodes,
          semanticLabel: selectedNodeName == null
              ? '智能线路，选择连接线路'
              : '当前线路 $selectedNodeName',
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          child: Row(
            children: [
              AppIconTile(
                icon: Icons.bolt_rounded,
                size: 46,
                iconSize: 25,
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedNodeName ?? '智能线路',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      selectedNodeName == null
                          ? '请选择可用线路后再连接'
                          : onlineCount > 0
                              ? '当前选择 · $onlineCount 条线路在线'
                              : '当前选择的连接线路',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _active
                    ? scheme.onSurface.withValues(alpha: .25)
                    : scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
        if (auth.vpnError.isNotEmpty) ...[
          const SizedBox(height: 10),
          AppSurface(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded, color: scheme.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    auth.vpnError,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.error,
                          height: 1.35,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String? _selectedNodeName() {
    final selectedId = auth.selectedNetworkNodeId;
    if (selectedId == null || selectedId.isEmpty) return null;
    for (final node in auth.networkNodes) {
      if (node.id == selectedId) return node.name;
    }
    return selectedId;
  }

  String _securityLabel() {
    if (_connected) return '网络安全防护中';
    if (auth.vpnBusy) return '正在更新连接状态';
    return '网络防护未开启';
  }

  String _primaryTitle() {
    if (!auth.isSignedIn) return '登录后开启安全连接';
    switch (auth.vpnStatus) {
      case VpnConnectionStatus.connected:
        return '安全连接已开启';
      case VpnConnectionStatus.connecting:
      case VpnConnectionStatus.reasserting:
        return '正在建立安全连接';
      case VpnConnectionStatus.disconnecting:
        return '正在断开连接';
      case VpnConnectionStatus.unsupported:
        return '当前设备不支持 VPN';
      case VpnConnectionStatus.invalid:
        return 'VPN 配置暂不可用';
      case VpnConnectionStatus.disconnected:
        return '点击开启安全连接';
    }
  }

  String _secondaryStatus() {
    if (!auth.isSignedIn) return '前往“我的”登录账号';
    switch (auth.vpnStatus) {
      case VpnConnectionStatus.connected:
        return '设备流量正在通过当前线路传输';
      case VpnConnectionStatus.connecting:
      case VpnConnectionStatus.reasserting:
        return '正在请求系统建立 VPN 连接';
      case VpnConnectionStatus.disconnecting:
        return '请稍候';
      case VpnConnectionStatus.unsupported:
        return '请在 iPhone 或 iPad 上使用';
      case VpnConnectionStatus.invalid:
        return '请检查系统 VPN 配置后重试';
      case VpnConnectionStatus.disconnected:
        return _selectedNodeName() == null ? '请先选择可用线路' : '当前未连接';
    }
  }
}

class _WorldNetworkPainter extends CustomPainter {
  const _WorldNetworkPainter({
    required this.lineColor,
    required this.nodeColor,
  });

  final Color lineColor;
  final Color nodeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .5, size.height * .48);
    final radius = math.min(size.width * .48, size.height * .47);
    final line = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final glow = Paint()
      ..color = nodeColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, line);
    for (final factor in <double>[.28, .56, .8]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: radius * 2 * factor,
          height: radius * 2,
        ),
        line,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: radius * 2,
          height: radius * 2 * factor,
        ),
        line,
      );
    }

    final nodes = <Offset>[
      const Offset(-.67, -.25),
      const Offset(-.4, .12),
      const Offset(-.06, -.54),
      const Offset(.2, -.12),
      const Offset(.55, -.34),
      const Offset(.68, .18),
      const Offset(.26, .52),
      const Offset(-.38, .58),
    ];
    for (var index = 0; index < nodes.length; index++) {
      final current = nodes[index];
      final next = nodes[(index + 3) % nodes.length];
      final start = Offset(
        center.dx + current.dx * radius,
        center.dy + current.dy * radius,
      );
      final end = Offset(
        center.dx + next.dx * radius,
        center.dy + next.dy * radius,
      );
      canvas.drawLine(start, end, line);
      canvas.drawCircle(start, 2.2, glow);
    }
  }

  @override
  bool shouldRepaint(covariant _WorldNetworkPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor || oldDelegate.nodeColor != nodeColor;
}

class _SecurityStatusPill extends StatelessWidget {
  const _SecurityStatusPill({
    required this.connected,
    required this.label,
  });

  final bool connected;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.pikayunColors;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: connected ? colors.successContainer : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            connected ? Icons.verified_user_rounded : Icons.shield_outlined,
            size: 17,
            color: connected ? colors.success : scheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: connected ? colors.success : scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _DisclosureItem extends StatelessWidget {
  const _DisclosureItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
        ),
      ],
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.privacy_tip_outlined,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'VPN 仅在你主动开启后连接；应用不申请设备 GPS 定位权限。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
