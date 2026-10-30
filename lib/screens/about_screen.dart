import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_brand.dart';
import '../providers/auth_provider.dart';
import '../services/vpn_service.dart';
import '../theme/pikayun_theme.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/app_surface.dart';
import 'privacy_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于与帮助')),
      body: AppBackdrop(
        showSignalField: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BrandHeader(),
                    const SizedBox(height: 20),
                    const _SectionTitle('核心功能'),
                    const SizedBox(height: 8),
                    const _FeatureList(),
                    const SizedBox(height: 20),
                    const _SectionTitle('连接诊断'),
                    const SizedBox(height: 8),
                    const _ConnectionDiagnostics(),
                    const SizedBox(height: 20),
                    const _SectionTitle('常见问题'),
                    const SizedBox(height: 8),
                    const _HelpList(),
                    const SizedBox(height: 20),
                    const _SectionTitle('支持与隐私'),
                    const SizedBox(height: 8),
                    _SupportActions(
                      onOpenPrivacy: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PrivacyScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '${AppBrand.storeName}  ${AppBrand.version} '
                      '(${AppBrand.buildNumber})',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: '${AppBrand.storeName}，${AppBrand.tagline}',
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/branding/pikayun_app_icon_256.png',
              width: 92,
              height: 92,
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            AppBrand.storeName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            AppBrand.tagline,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              'Apple Network Extension',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList();

  @override
  Widget build(BuildContext context) {
    return const AppSurface(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.bolt_rounded,
            title: 'VPN 安全连接',
            message: '登录后选择可用线路，由你主动连接或断开。',
          ),
          _Divider(),
          _InfoRow(
            icon: Icons.public_rounded,
            title: '公网 IP 检测',
            message: '查询公网地址及基于 IP 的近似归属地，不读取 GPS。',
          ),
          _Divider(),
          _InfoRow(
            icon: Icons.data_usage_rounded,
            title: '套餐与流量',
            message: '展示账号真实套餐、剩余流量和使用趋势。',
          ),
          _Divider(),
          _InfoRow(
            icon: Icons.history_rounded,
            title: '本地查询历史',
            message: '查询记录仅保存在当前设备，可随时删除。',
          ),
        ],
      ),
    );
  }
}

class _ConnectionDiagnostics extends StatelessWidget {
  const _ConnectionDiagnostics();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final selectedNode = _selectedNodeName(auth);
        return AppSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DiagnosticRow(
                label: 'VPN 状态',
                value: _statusText(auth),
                valueColor: _statusColor(context, auth.vpnStatus),
              ),
              const SizedBox(height: 11),
              _DiagnosticRow(
                label: '当前线路',
                value: selectedNode ?? (auth.isSignedIn ? '尚未选择' : '登录后可用'),
              ),
              if (auth.vpnError.isNotEmpty) ...[
                const SizedBox(height: 11),
                _DiagnosticRow(
                  label: '最近错误',
                  value: auth.vpnError,
                  valueColor: Theme.of(context).colorScheme.error,
                ),
              ],
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: auth.vpnBusy ? null : auth.refreshVpnStatus,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('刷新连接状态'),
              ),
            ],
          ),
        );
      },
    );
  }

  static String? _selectedNodeName(AuthProvider auth) {
    final id = auth.selectedNetworkNodeId;
    if (id == null || id.isEmpty) return null;
    for (final node in auth.networkNodes) {
      if (node.id == id) return node.name;
    }
    return id;
  }

  static String _statusText(AuthProvider auth) {
    if (!auth.isSignedIn) return '未登录';
    switch (auth.vpnStatus) {
      case VpnConnectionStatus.unsupported:
        return '当前平台不支持';
      case VpnConnectionStatus.invalid:
        return '配置不可用';
      case VpnConnectionStatus.disconnected:
        return '未连接';
      case VpnConnectionStatus.connecting:
        return '正在连接';
      case VpnConnectionStatus.connected:
        return '已连接';
      case VpnConnectionStatus.reasserting:
        return '正在恢复连接';
      case VpnConnectionStatus.disconnecting:
        return '正在断开';
    }
  }

  static Color? _statusColor(
    BuildContext context,
    VpnConnectionStatus status,
  ) {
    if (status == VpnConnectionStatus.connected) {
      return context.pikayunColors.success;
    }
    if (status == VpnConnectionStatus.invalid) {
      return Theme.of(context).colorScheme.error;
    }
    return null;
  }
}

class _HelpList extends StatelessWidget {
  const _HelpList();

  @override
  Widget build(BuildContext context) {
    return const AppSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ExpansionTile(
            leading: Icon(Icons.power_settings_new_rounded),
            title: Text('如何建立安全连接？'),
            childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '先登录已有账号，在“线路”选择在线的 VLESS 线路，返回首页点击中央连接按钮，并允许 iOS 添加 VPN 配置。'),
            ],
          ),
          _Divider(),
          ExpansionTile(
            leading: Icon(Icons.build_circle_outlined),
            title: Text('连接失败怎么办？'),
            childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('先刷新上方连接状态；确认没有其他 VPN 正在连接，再切换一条在线线路重试。错误信息会显示在首页和连接诊断中。'),
            ],
          ),
          _Divider(),
          ExpansionTile(
            leading: Icon(Icons.my_location_outlined),
            title: Text('IP 位置是 GPS 定位吗？'),
            childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('不是。国家、地区、城市和坐标均根据公网 IP 估算，可能存在较大误差；本 App 不申请设备 GPS 定位权限。'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SupportActions extends StatelessWidget {
  const _SupportActions({required this.onOpenPrivacy});

  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('隐私与数据'),
            subtitle: const Text('查看数据用途和管理本地记录'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onOpenPrivacy,
          ),
          const _Divider(),
          ListTile(
            leading: const Icon(Icons.support_agent_rounded),
            title: const Text('联系技术支持'),
            subtitle: const Text(AppBrand.supportEmail),
            trailing: const Icon(Icons.copy_rounded),
            onTap: () => _copySupportEmail(context),
          ),
        ],
      ),
    );
  }

  Future<void> _copySupportEmail(BuildContext context) async {
    await Clipboard.setData(
      const ClipboardData(text: AppBrand.supportEmail),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('支持邮箱已复制')));
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: scheme.primary),
      ),
      title: Text(title),
      subtitle: Text(message),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Theme.of(context).dividerColor.withValues(alpha: .55),
    );
  }
}
