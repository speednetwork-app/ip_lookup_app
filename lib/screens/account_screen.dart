import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/account_overview.dart';
import '../models/traffic_trend.dart';
import '../providers/auth_provider.dart';
import '../widgets/account_insights_card.dart';
import '../widgets/account_notices_card.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/app_page_title.dart';
import '../widgets/traffic_trend_card.dart';
import 'privacy_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _showSubscribeUrl = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppPageTitle(
          title: '我的',
          subtitle: '套餐、流量与账户',
          icon: Icons.person_outline_rounded,
        ),
        actions: [
          IconButton(
            tooltip: '隐私与数据',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()),
            ),
            icon: const Icon(Icons.privacy_tip_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AppBackdrop(
        child: Consumer<AuthProvider>(
          builder: (context, auth, _) {
          switch (auth.status) {
            case AuthStatus.initializing:
              return const Center(child: CircularProgressIndicator());
            case AuthStatus.signedOut:
            case AuthStatus.signingIn:
              return _LoginView(auth: auth);
            case AuthStatus.signedIn:
              return _buildAccount(context, auth);
          }
          },
        ),
      ),
    );
  }

  Widget _buildAccount(BuildContext context, AuthProvider auth) {
    final overview = auth.overview;
    return RefreshIndicator.adaptive(
      onRefresh: auth.refreshAccountData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          if (auth.error.isNotEmpty)
            _MessageBanner(
              message:
                  overview == null ? auth.error : '${auth.error}，当前显示上次获取的数据',
            ),
          if (auth.error.isNotEmpty) const SizedBox(height: 12),
          if (overview == null)
            _OverviewLoading(
              refreshing: auth.isRefreshing,
              onRetry: auth.refreshAccountData,
            )
          else ...[
            _AccountHeader(
              email: auth.email,
              overview: overview,
              subscribeUrl: overview.subscribeUrl,
              subscribeRevealed: _showSubscribeUrl,
              onToggleSubscribe: () => setState(
                () => _showSubscribeUrl = !_showSubscribeUrl,
              ),
              onCopySubscribe: () => _copy(context, overview.subscribeUrl),
            ),
            if (_AccountAlert.from(overview) case final alert?) ...[
              const SizedBox(height: 12),
              alert,
            ],
            const SizedBox(height: 12),
            _TrafficCard(traffic: overview.traffic),
            if (auth.trafficTrendFor(TrafficRange.sevenDays) != null ||
                auth.trafficTrendFor(TrafficRange.thirtyDays) != null) ...[
              const SizedBox(height: 12),
              AccountInsightsCard(
                overview: overview,
                sevenDayTrend: auth.trafficTrendFor(TrafficRange.sevenDays),
                thirtyDayTrend: auth.trafficTrendFor(TrafficRange.thirtyDays),
              ),
            ],
            const SizedBox(height: 12),
            TrafficTrendCard(
              trend: auth.trafficTrend,
              selectedRange: auth.selectedTrafficRange,
              loading: auth.isTrafficLoading,
              onRangeChanged: auth.selectTrafficRange,
            ),
            if (auth.notices.isNotEmpty) ...[
              const SizedBox(height: 12),
              AccountNoticesCard(notices: auth.notices),
            ],
            const SizedBox(height: 12),
            _DetailsCard(overview: overview),
          ],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () async {
              setState(() => _showSubscribeUrl = false);
              await auth.logout();
            },
            icon: const Icon(Icons.logout, size: 20),
            label: const Text('退出登录'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '下拉页面可刷新账号信息',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('订阅地址已复制')));
  }
}

class _AccountAlert extends StatelessWidget {
  const _AccountAlert({
    required this.icon,
    required this.title,
    required this.message,
    required this.isCritical,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isCritical;

  static _AccountAlert? from(AccountOverview overview) {
    switch (overview.state) {
      case AccountState.suspended:
        return const _AccountAlert(
          icon: Icons.pause_circle_outline,
          title: '账号已停用',
          message: '当前账号暂不可用，请联系服务提供方确认。',
          isCritical: true,
        );
      case AccountState.expired:
        return const _AccountAlert(
          icon: Icons.event_busy_outlined,
          title: '套餐已过期',
          message: '账号套餐已经到期，请留意服务状态。',
          isCritical: true,
        );
      case AccountState.trafficExhausted:
        return const _AccountAlert(
          icon: Icons.data_usage_outlined,
          title: '流量已用尽',
          message: '本周期可用流量为零，请等待下次重置。',
          isCritical: true,
        );
      case AccountState.inactive:
        return const _AccountAlert(
          icon: Icons.info_outline,
          title: '账号未启用',
          message: '当前账号尚未启用，请联系服务提供方确认。',
          isCritical: true,
        );
      case AccountState.active:
      case AccountState.unknown:
        break;
    }

    if (overview.remainingDays != null && overview.remainingDays! <= 7) {
      return _AccountAlert(
        icon: Icons.schedule_outlined,
        title: '套餐即将到期',
        message: '剩余 ${overview.remainingDays} 天，请及时关注有效期。',
        isCritical: false,
      );
    }
    final traffic = overview.traffic;
    if (traffic.totalBytes > 0 &&
        traffic.remainingBytes / traffic.totalBytes <= 0.1) {
      return const _AccountAlert(
        icon: Icons.warning_amber_rounded,
        title: '剩余流量不足 10%',
        message: '建议留意本周期流量使用情况。',
        isCritical: false,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isCritical ? scheme.error : const Color(0xFF8A5B00);
    final background = isCritical
        ? scheme.errorContainer.withValues(alpha: 0.6)
        : const Color(0xFFFFF2CF);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          TextStyle(fontWeight: FontWeight.w700, color: color)),
                  const SizedBox(height: 2),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({
    required this.email,
    required this.overview,
    required this.subscribeUrl,
    required this.subscribeRevealed,
    required this.onToggleSubscribe,
    required this.onCopySubscribe,
  });

  final String email;
  final AccountOverview overview;
  final String subscribeUrl;
  final bool subscribeRevealed;
  final VoidCallback onToggleSubscribe;
  final VoidCallback onCopySubscribe;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SectionCard(
      color: scheme.primaryContainer.withValues(alpha: 0.46),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_outline, color: scheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            overview.planName.isEmpty
                                ? '当前方案'
                                : overview.planName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(state: overview.state),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (subscribeUrl.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 10),
            _InlineSubscription(
              url: subscribeUrl,
              revealed: subscribeRevealed,
              onToggle: onToggleSubscribe,
              onCopy: onCopySubscribe,
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineSubscription extends StatelessWidget {
  const _InlineSubscription({
    required this.url,
    required this.revealed,
    required this.onToggle,
    required this.onCopy,
  });

  final String url;
  final bool revealed;
  final VoidCallback onToggle;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.link_rounded, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '订阅地址',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    revealed ? '当前已显示，请注意保护' : '默认隐藏，请勿分享给他人',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: revealed ? '隐藏订阅地址' : '显示订阅地址',
              onPressed: onToggle,
              icon: Icon(
                revealed
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
            IconButton.filledTonal(
              tooltip: '复制订阅地址',
              onPressed: onCopy,
              icon: const Icon(Icons.copy_outlined),
            ),
          ],
        ),
        if (revealed) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(11),
            ),
            child: SelectableText(
              url,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }
}

class _TrafficCard extends StatelessWidget {
  const _TrafficCard({required this.traffic});

  final TrafficOverview traffic;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasQuota = traffic.totalBytes > 0;
    final progress = (traffic.usagePercent / 100).clamp(0.0, 1.0);
    final remainingPercent = (100 - traffic.usagePercent).clamp(0.0, 100.0);
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.data_usage_rounded, size: 21, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                '流量概览',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  hasQuota
                      ? '剩余 ${remainingPercent.toStringAsFixed(1)}%'
                      : '不限额度',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '剩余可用',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        hasQuota
                            ? _formatBytes(traffic.remainingBytes)
                            : '不限额度',
                        style:
                            Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: scheme.primary,
                                ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      hasQuota
                          ? '总额度 ${_formatBytes(traffic.totalBytes)}'
                          : '当前套餐未设置流量上限',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              _UsageRing(progress: progress, unlimited: !hasQuota),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: '已使用',
                    value: _formatBytes(traffic.usedBytes),
                  ),
                ),
                Container(width: 1, height: 34, color: scheme.outlineVariant),
                Expanded(
                  child: _Metric(
                    label: '使用进度',
                    value: hasQuota
                        ? '${traffic.usagePercent.toStringAsFixed(1)}%'
                        : '不限',
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageRing extends StatelessWidget {
  const _UsageRing({required this.progress, required this.unlimited});

  final double progress;
  final bool unlimited;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: unlimited
          ? '当前套餐不限流量额度'
          : '流量已使用 ${(progress * 100).toStringAsFixed(1)}%',
      child: SizedBox.square(
        dimension: 78,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: 78,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 9,
                strokeCap: StrokeCap.round,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  unlimited ? '∞' : '${(progress * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                ),
                Text(
                  unlimited ? '不限' : '已用',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(
      {required this.label, required this.value, this.alignEnd = false});

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.overview});

  final AccountOverview overview;

  @override
  Widget build(BuildContext context) {
    final expiry = overview.expiredAt == null
        ? '长期有效'
        : '${_formatDate(overview.expiredAt!)} · ${overview.remainingDays ?? 0} 天';
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.event_available_outlined,
            title: '有效期与限制',
          ),
          const SizedBox(height: 10),
          _DetailRow(label: '到期时间', value: expiry),
          _DetailRow(
            label: '下次重置',
            value: overview.nextResetAt == null
                ? '暂无重置计划'
                : _formatDate(overview.nextResetAt!),
          ),
          _DetailRow(
            label: '设备限制',
            value:
                overview.deviceLimit <= 0 ? '不限' : '${overview.deviceLimit} 台',
          ),
          _DetailRow(
            label: '速度限制',
            value: overview.speedLimitMbps <= 0
                ? '不限速'
                : '${overview.speedLimitMbps} Mbps',
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state});

  final AccountState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, foreground, background) = switch (state) {
      AccountState.active => (
          '正常',
          const Color(0xFF16794A),
          const Color(0xFFDDF5E8)
        ),
      AccountState.expired => (
          '已过期',
          const Color(0xFF9A5700),
          const Color(0xFFFFE9C7)
        ),
      AccountState.suspended => ('已停用', scheme.error, scheme.errorContainer),
      AccountState.trafficExhausted => (
          '流量已用完',
          const Color(0xFF9A5700),
          const Color(0xFFFFE9C7)
        ),
      AccountState.inactive => (
          '未激活',
          scheme.onSurfaceVariant,
          scheme.surfaceContainerHighest
        ),
      AccountState.unknown => (
          '状态未知',
          scheme.onSurfaceVariant,
          scheme.surfaceContainerHighest
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(
      {required this.label, required this.value, this.showDivider = true});

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: scheme.outlineVariant),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 21, color: scheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child:
                Text(message, style: TextStyle(color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

class _OverviewLoading extends StatelessWidget {
  const _OverviewLoading({required this.refreshing, required this.onRetry});

  final bool refreshing;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            if (refreshing)
              const CircularProgressIndicator()
            else
              Icon(
                Icons.cloud_off_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            const SizedBox(height: 14),
            Text(refreshing ? '正在获取账号信息…' : '暂时无法获取账号信息'),
            if (!refreshing) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('重新获取'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView({required this.auth});

  final AuthProvider auth;

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final success = await widget.auth.login(
      email: _emailController.text,
      password: _passwordController.text,
    );
    _passwordController.clear();
    if (success) TextInput.finishAutofillContext();
  }

  @override
  Widget build(BuildContext context) {
    final loading = widget.auth.status == AuthStatus.signingIn;
    final scheme = Theme.of(context).colorScheme;
    return AutofillGroup(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.person_outline, size: 38, color: scheme.primary),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '登录已有账号',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '查看账号状态、流量用量和有效期。\nIP 查询功能无需登录。',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 22),
          _SectionCard(
            color: scheme.surfaceContainerHighest,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, size: 21),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '邮箱和密码仅通过 HTTPS 发送至账号服务器进行验证。密码不会保存在本机，登录凭证安全存储在 iOS 钥匙串中。',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _emailController,
                  enabled: !loading,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email
                  ],
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: '邮箱',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return '请输入邮箱';
                    if (!email.contains('@')) return '请输入有效邮箱';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  enabled: !loading,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: '密码',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => (value ?? '').isEmpty ? '请输入密码' : null,
                  onFieldSubmitted: loading ? null : (_) => _submit(),
                ),
              ],
            ),
          ),
          if (widget.auth.error.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              widget.auth.error,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.error),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: loading ? null : _submit,
            style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50)),
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('登录'),
          ),
          const SizedBox(height: 12),
          Text(
            '仅支持已有账号，本 App 不提供注册或购买入口。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
}

String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  var value = bytes < 0 ? 0.0 : bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  int digitsFor(double amount, int currentUnit) =>
      amount >= 100 || currentUnit == 0
          ? 0
          : amount >= 10
              ? 1
              : 2;
  var digits = digitsFor(value, unit);
  if (unit < units.length - 1 &&
      double.parse(value.toStringAsFixed(digits)) >= 1024) {
    value /= 1024;
    unit++;
    digits = digitsFor(value, unit);
  }
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}
