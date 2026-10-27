import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account_overview.dart';
import '../models/ip_info.dart';
import '../providers/auth_provider.dart';
import '../providers/ip_provider.dart';
import '../services/vpn_service.dart';
import '../theme/pikayun_theme.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/app_icon_tile.dart';
import '../widgets/app_section_header.dart';
import '../widgets/app_surface.dart';
import '../widgets/status_badge.dart';

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
        toolbarHeight: 68,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('皮卡云', style: Theme.of(context).textTheme.titleLarge),
            Text(
              '网络信息与账号概览',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        child: Consumer2<AuthProvider, IpProvider>(
          builder: (context, auth, ipProvider, _) => RefreshIndicator.adaptive(
            onRefresh: () async {
              if (auth.isSignedIn) await auth.refreshAccountData();
              if (ipProvider.myIp != null) await ipProvider.loadMyIp();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
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
                      const SizedBox(height: 12),
                      _VpnControl(auth: auth, onOpenNodes: onOpenNodes),
                      const SizedBox(height: 22),
                      const AppSectionHeader(
                        title: '账号概览',
                      ),
                      const SizedBox(height: 10),
                      _AccountSummary(
                        auth: auth,
                        onOpenAccount: onOpenAccount,
                      ),
                      if (auth.notices.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _LatestNotice(
                          title: auth.notices.first.title,
                          content: auth.notices.first.content,
                          onOpenAccount: onOpenAccount,
                        ),
                      ],
                      const SizedBox(height: 22),
                      const AppSectionHeader(
                        title: '常用功能',
                      ),
                      const SizedBox(height: 10),
                      _QuickActions(
                        onOpenNodes: onOpenNodes,
                        onOpenIpTools: onOpenIpTools,
                        onOpenHistory: onOpenHistory,
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

enum _DetectionState { idle, loading, success, failed }

class _NetworkOverview extends StatefulWidget {
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
  State<_NetworkOverview> createState() => _NetworkOverviewState();
}

class _NetworkOverviewState extends State<_NetworkOverview> {
  @override
  void didUpdateWidget(covariant _NetworkOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loading &&
        !widget.loading &&
        widget.error.isEmpty &&
        widget.info != null &&
        !MediaQuery.disableAnimationsOf(context)) {
      HapticFeedback.lightImpact();
    }
  }

  _DetectionState get _state {
    if (widget.loading) return _DetectionState.loading;
    if (widget.error.isNotEmpty) return _DetectionState.failed;
    if (widget.info != null) return _DetectionState.success;
    return _DetectionState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pikayunColors;
    final info = widget.info;
    return Semantics(
      container: true,
      label: _semanticLabel(info),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.heroStart, colors.heroEnd],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colors.heroEnd.withValues(alpha: .2),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned(
                right: -38,
                top: 23,
                child: ExcludeSemantics(
                  child: SizedBox.square(
                    dimension: 210,
                    child: CustomPaint(
                      painter: _GlobePatternPainter(
                        color: colors.onBrandSurface.withValues(alpha: .32),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppIconTile(
                          icon: Icons.public_rounded,
                          size: 40,
                          iconSize: 21,
                          backgroundColor:
                              colors.onBrandSurface.withValues(alpha: .13),
                          foregroundColor: colors.onBrandSurface,
                        ),
                        const SizedBox(width: 10),
                        _DetectionBadge(state: _state),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '当前网络',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: colors.onBrandSurface,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 3),
                    if (info == null)
                      Text(
                        widget.loading ? '正在检测…' : '尚未检测',
                        style:
                            Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: colors.onBrandSurface,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.5,
                                ),
                      )
                    else
                      SelectableText(
                        info.ip,
                        style:
                            Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: colors.onBrandSurface,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.4,
                          height: 1.08,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    const SizedBox(height: 6),
                    if (info == null)
                      SizedBox(
                        width: 210,
                        child: Text(
                          '主动检测后显示公网 IP、估计位置和网络运营商。',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colors.onBrandSurfaceMuted,
                                height: 1.35,
                              ),
                        ),
                      )
                    else ...[
                      _NetworkLine(
                        icon: Icons.location_on_outlined,
                        text: info.location,
                      ),
                      const SizedBox(height: 3),
                      _NetworkLine(
                        icon: Icons.router_outlined,
                        text: info.isp,
                      ),
                    ],
                    if (widget.error.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _HeroError(message: widget.error),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.onBrandSurface.withValues(alpha: .96),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: widget.loading ? null : widget.onDetect,
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget.loading)
                                      SizedBox.square(
                                        dimension: 17,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colors.heroEnd,
                                        ),
                                      )
                                    else
                                      Icon(
                                        Icons.radar_rounded,
                                        size: 19,
                                        color: colors.heroEnd,
                                      ),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.loading
                                          ? '正在检测'
                                          : info == null
                                              ? '检测当前网络'
                                              : '重新检测当前网络',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: colors.heroStart,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (info != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: IconButton.filled(
                                tooltip: '查看完整 IP 信息',
                                onPressed: widget.onOpenDetails,
                                icon: const Icon(Icons.arrow_forward_rounded),
                                style: IconButton.styleFrom(
                                  backgroundColor: colors.heroEnd,
                                  foregroundColor: colors.onBrandSurface,
                                  minimumSize: const Size.square(38),
                                  maximumSize: const Size.square(38),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _semanticLabel(IpInfo? info) {
    if (widget.loading) return '当前网络，正在检测';
    if (widget.error.isNotEmpty) return '当前网络，检测失败，${widget.error}';
    if (info == null) return '当前网络，尚未检测';
    return '当前公网 IP ${info.ip}，IP 估计位置 ${info.location}，网络运营商 ${info.isp}';
  }
}

class _GlobePatternPainter extends CustomPainter {
  const _GlobePatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .5, size.height * .5);
    final radius = size.shortestSide * .44;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final dot = Paint()..color = color.withValues(alpha: .82);

    canvas.drawCircle(center, radius, stroke);
    for (final factor in <double>[.32, .62]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: radius * 2 * factor,
          height: radius * 2,
        ),
        stroke,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: radius * 2,
          height: radius * 2 * factor,
        ),
        stroke,
      );
    }

    for (var latitude = -5; latitude <= 5; latitude++) {
      for (var longitude = -8; longitude <= 8; longitude++) {
        final x = longitude / 8;
        final y = latitude / 5;
        if (x * x + y * y > 1) continue;
        final wave = math.sin((x + 1.2) * 3.7) + math.cos((y - .2) * 5.1);
        if (wave > .42 || (x > .12 && y < .25 && wave > -.1)) {
          canvas.drawCircle(
            Offset(center.dx + x * radius, center.dy + y * radius),
            1.15,
            dot,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GlobePatternPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DetectionBadge extends StatelessWidget {
  const _DetectionBadge({required this.state});

  final _DetectionState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.pikayunColors;
    final (label, icon, foreground) = switch (state) {
      _DetectionState.loading => ('检测中', Icons.sync, colors.onBrandSurface),
      _DetectionState.success => (
          '已检测',
          Icons.check_circle_outline,
          colors.onBrandSurface,
        ),
      _DetectionState.failed => (
          '检测失败',
          Icons.error_outline,
          const Color(0xFFFFD4D4),
        ),
      _DetectionState.idle => (
          '等待检测',
          Icons.radio_button_unchecked,
          colors.onBrandSurfaceMuted,
        ),
    };
    return StatusBadge(
      label: label,
      icon: icon,
      foreground: foreground,
      background: colors.onBrandSurface.withValues(alpha: .11),
    );
  }
}

class _NetworkLine extends StatelessWidget {
  const _NetworkLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.pikayunColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, color: colors.onBrandSurfaceMuted, size: 15),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onBrandSurfaceMuted,
                  height: 1.25,
                ),
          ),
        ),
      ],
    );
  }
}

class _HeroError extends StatelessWidget {
  const _HeroError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, size: 17, color: Color(0xFFFFD4D4)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFFFD4D4),
                  height: 1.35,
                ),
          ),
        ),
      ],
    );
  }
}

class _VpnControl extends StatefulWidget {
  const _VpnControl({required this.auth, required this.onOpenNodes});
  final AuthProvider auth;
  final VoidCallback onOpenNodes;

  @override
  State<_VpnControl> createState() => _VpnControlState();
}

class _VpnControlState extends State<_VpnControl> {
  static const _disclosureAcceptedKey = 'vpn_disclosure_accepted_v1';

  AuthProvider get auth => widget.auth;

  Future<void> _handleToggle(bool active) async {
    if (active) {
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
            _VpnDisclosureItem(
              icon: Icons.route_outlined,
              text: 'VPN 仅在您主动开启后连接，可随时用同一开关断开。',
            ),
            SizedBox(height: 8),
            _VpnDisclosureItem(
              icon: Icons.location_off_outlined,
              text: '应用不读取设备 GPS；页面位置来自公网 IP 的近似归属地。',
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
    final enabled = auth.isSignedIn &&
        auth.vpnStatus != VpnConnectionStatus.unsupported &&
        auth.vpnStatus != VpnConnectionStatus.invalid;
    final active = auth.vpnStatus == VpnConnectionStatus.connected ||
        auth.vpnStatus == VpnConnectionStatus.connecting ||
        auth.vpnStatus == VpnConnectionStatus.reasserting;
    final onlineCount = auth.networkNodes.where((node) => node.isOnline).length;

    return AppSurface(
      semanticLabel: '安全连接，${_vpnStatusText(auth)}',
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              AppIconTile(
                icon: active ? Icons.shield : Icons.shield_outlined,
                size: 44,
                backgroundColor: active
                    ? colors.successContainer
                    : scheme.surfaceContainerHighest,
                foregroundColor:
                    active ? colors.success : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '安全连接',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _vpnStatusText(auth),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (auth.vpnBusy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Switch.adaptive(
                  value: active,
                  onChanged: enabled ? (_) => _handleToggle(active) : null,
                ),
            ],
          ),
          if (auth.isSignedIn) ...[
            const SizedBox(height: 10),
            const Divider(),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: active ? null : widget.onOpenNodes,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    Icon(
                      Icons.route_outlined,
                      size: 19,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        auth.selectedNetworkNodeId == null
                            ? '选择连接线路'
                            : '当前线路 ${auth.selectedNetworkNodeId}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    if (onlineCount > 0)
                      Text(
                        '$onlineCount 条在线',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: active
                          ? scheme.onSurface.withValues(alpha: .24)
                          : scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (auth.vpnError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                auth.vpnError,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                      height: 1.35,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _vpnStatusText(AuthProvider auth) {
    if (!auth.isSignedIn) return '登录后可选择线路并连接';
    switch (auth.vpnStatus) {
      case VpnConnectionStatus.connected:
        return '已连接，设备流量正在受到保护';
      case VpnConnectionStatus.connecting:
      case VpnConnectionStatus.reasserting:
        return '正在建立安全连接';
      case VpnConnectionStatus.disconnecting:
        return '正在断开连接';
      case VpnConnectionStatus.unsupported:
        return '请在 iPhone 或 iPad 上使用';
      case VpnConnectionStatus.invalid:
        return '系统 VPN 配置暂不可用';
      case VpnConnectionStatus.disconnected:
        return '当前未连接';
    }
  }
}

class _VpnDisclosureItem extends StatelessWidget {
  const _VpnDisclosureItem({required this.icon, required this.text});

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

class _AccountSummary extends StatelessWidget {
  const _AccountSummary({required this.auth, required this.onOpenAccount});
  final AuthProvider auth;
  final VoidCallback onOpenAccount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final overview = auth.overview;
    if (!auth.isSignedIn) {
      return AppSurface(
        onTap: onOpenAccount,
        semanticLabel: '皮卡云账号，登录后查看套餐和流量',
        child: const Row(
          children: [
            AppIconTile(icon: Icons.person_outline),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('皮卡云账号', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 3),
                  Text('登录后查看套餐、流量和到期时间'),
                ],
              ),
            ),
            Icon(Icons.chevron_right),
          ],
        ),
      );
    }
    if (overview == null) {
      return AppSurface(
        onTap: onOpenAccount,
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('正在获取账号信息'),
                  if (auth.error.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(auth.error, style: TextStyle(color: scheme.error)),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    final traffic = overview.traffic;
    final progress = (traffic.usagePercent / 100).clamp(0.0, 1.0);
    return AppSurface(
      onTap: onOpenAccount,
      semanticLabel:
          '${overview.planName}，${_accountStatus(overview)}，剩余流量 ${_formatBytes(traffic.remainingBytes)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppIconTile(icon: Icons.cloud_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      overview.planName.isEmpty ? '皮卡云套餐' : overview.planName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _accountStatus(overview),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  '流量使用 ${traffic.usagePercent.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ),
              Text(
                '剩余 ${_formatBytes(traffic.remainingBytes)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_formatBytes(traffic.usedBytes)} / ${_formatBytes(traffic.totalBytes)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ),
        ],
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
    final scheme = Theme.of(context).colorScheme;
    return AppSurface(
      onTap: onOpenAccount,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(Icons.campaign_outlined, color: scheme.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? '系统公告' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
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
    return AppSurface(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: _QuickAction(
              icon: Icons.route_outlined,
              label: '线路',
              onTap: onOpenNodes,
            ),
          ),
          Expanded(
            child: _QuickAction(
              icon: Icons.radar_rounded,
              label: 'IP 检测',
              onTap: onOpenIpTools,
            ),
          ),
          Expanded(
            child: _QuickAction(
              icon: Icons.history_rounded,
              label: '查询历史',
              onTap: onOpenHistory,
            ),
          ),
          Expanded(
            child: _QuickAction(
              icon: Icons.person_outline_rounded,
              label: '账号中心',
              onTap: onOpenAccount,
            ),
          ),
        ],
      ),
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
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 82),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIconTile(
                icon: icon,
                size: 40,
                backgroundColor: scheme.primaryContainer.withValues(alpha: .7),
                foregroundColor: scheme.primary,
              ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
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
              '仅在你主动检测时查询公网 IP，不申请设备 GPS 定位权限。',
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
