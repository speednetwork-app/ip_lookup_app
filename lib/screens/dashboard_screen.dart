import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../widgets/service_data_disclosure.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_brand.dart';
import '../providers/auth_provider.dart';
import '../providers/ip_provider.dart';
import '../services/vpn_service.dart';
import '../theme/pikayun_theme.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/app_brand_mark.dart';
import '../widgets/app_icon_tile.dart';
import '../widgets/app_surface.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    required this.onOpenNodes,
    required this.onOpenAccount,
    required this.onOpenIp,
    super.key,
  });

  final VoidCallback onOpenNodes;
  final VoidCallback onOpenAccount;
  final VoidCallback onOpenIp;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 16,
        title: Row(
          children: [
            const AppBrandMark(),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppBrand.name,
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
                          onOpenIp: onOpenIp,
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
    required this.onOpenIp,
  });

  final AuthProvider auth;
  final VoidCallback onOpenNodes;
  final VoidCallback onOpenAccount;
  final VoidCallback onOpenIp;

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

    final account = auth.email;
    if (!await ServiceDataDisclosure.ensureAccepted(context)) return;
    if (!mounted || !auth.isSignedIn || auth.email != account) return;
    final preferences = await SharedPreferences.getInstance();
    if (!mounted || !auth.isSignedIn || auth.email != account) return;
    if (preferences.getBool(_disclosureAcceptedKey) != true) {
      if (!mounted) return;
      final confirmed = await _showVpnDisclosure();
      if (confirmed != true ||
          !mounted ||
          !auth.isSignedIn ||
          auth.email != account) {
        return;
      }
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
    final selectedNodeName = _selectedNodeName();
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 280),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.heroStart,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SecurityStatusPill(
                  connected: _connected && !auth.vpnCertificateUnverified,
                  label: _securityLabel()),
              SizedBox(height: textScale > 1.3 ? 20 : 16),
              Center(
                child: Semantics(
                  button: true,
                  enabled: (_enabled || !auth.isSignedIn) && !auth.vpnBusy,
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
                            : const Duration(milliseconds: 220),
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _connected
                              ? colors.successContainer
                              : colors.brandSurface,
                        ),
                        child: Center(
                          child: auth.vpnBusy
                              ? SizedBox.square(
                                  dimension: 38,
                                  child: CircularProgressIndicator(
                                    color: colors.onBrandSurface,
                                    strokeWidth: 3,
                                  ),
                                )
                              : Icon(
                                  Icons.power_settings_new_rounded,
                                  color: _connected
                                      ? colors.success
                                      : colors.onBrandSurface,
                                  size: 52,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  _primaryTitle(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  _secondaryStatus(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: .76),
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CurrentIpSummary(onOpenIp: widget.onOpenIp),
        const SizedBox(height: 12),
        AppSurface(
          onTap: _active ? null : widget.onOpenNodes,
          semanticLabel: selectedNodeName == null
              ? '当前线路，尚未选择，点击选择线路'
              : '当前线路 $selectedNodeName',
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            children: [
              AppIconTile(
                icon: Icons.route_outlined,
                size: 46,
                iconSize: 24,
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('当前线路', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      selectedNodeName ?? '尚未选择 · 点击选择线路',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                _active ? Icons.lock_outline : Icons.chevron_right_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
        if (auth.vpnError.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppSurface(
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
    if (_connected && auth.vpnCertificateUnverified) return 'HY2 兼容连接 · 未验证证书';
    if (_connected) return 'VPN 已连接';
    if (auth.vpnBusy) return '正在更新连接状态';
    switch (auth.vpnStatus) {
      case VpnConnectionStatus.connecting:
      case VpnConnectionStatus.reasserting:
        return 'VPN 连接中';
      case VpnConnectionStatus.disconnecting:
        return 'VPN 正在断开';
      case VpnConnectionStatus.unsupported:
        return '当前平台不支持 VPN';
      case VpnConnectionStatus.invalid:
        return 'VPN 配置不可用';
      case VpnConnectionStatus.disconnected:
        return 'VPN 未连接';
      case VpnConnectionStatus.connected:
        return 'VPN 已连接';
    }
  }

  String _primaryTitle() {
    if (!auth.isSignedIn) return '登录后开启安全连接';
    switch (auth.vpnStatus) {
      case VpnConnectionStatus.connected:
        return auth.vpnCertificateUnverified ? 'VPN 兼容连接已开启' : '安全连接已开启';
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
        return '开启 VPN 连接';
    }
  }

  String _secondaryStatus() {
    if (_active && auth.vpnCertificateUnverified) return '已跳过服务器证书校验';
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: connected
            ? colors.successContainer
            : Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            connected ? Icons.check_circle_outline : Icons.power_settings_new,
            size: 14,
            color:
                connected ? colors.success : Colors.white.withValues(alpha: .8),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: connected
                      ? colors.success
                      : Colors.white.withValues(alpha: .8),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _CurrentIpSummary extends StatelessWidget {
  const _CurrentIpSummary({required this.onOpenIp});

  final VoidCallback onOpenIp;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.pikayunColors;
    return Consumer<IpProvider>(
      builder: (context, ip, _) => AppSurface(
        onTap: onOpenIp,
        semanticLabel: '当前公网 IP，打开 IP 检测',
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIconTile(
              icon: Icons.public,
              size: 42,
              backgroundColor: colors.successContainer,
              foregroundColor: colors.success,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('当前公网 IP', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    ip.myIp?.ip ?? '尚未检测',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ip.isMyIpLoading
                        ? '正在检测当前网络'
                        : ip.myIpError.isNotEmpty
                            ? '检测失败，点击重试'
                            : ip.myIp == null
                                ? '主动检测后显示 IP 与近似位置'
                                : '${ip.myIp!.location}\n${ip.myIp!.isp}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ip.myIpError.isEmpty
                              ? scheme.onSurfaceVariant
                              : scheme.error,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: ip.myIp == null ? '检测当前公网 IP' : '重新检测公网 IP',
              onPressed: ip.isMyIpLoading ? null : ip.loadMyIp,
              style: IconButton.styleFrom(
                backgroundColor: colors.brandSurface,
                foregroundColor: colors.onBrandSurface,
              ),
              icon: ip.isMyIpLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded, size: 21),
            ),
          ],
        ),
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
