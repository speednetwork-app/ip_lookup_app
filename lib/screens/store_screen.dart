import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/store_plan.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/app_page_title.dart';
import '../widgets/app_surface.dart';
import '../widgets/apple_subscription_summary.dart';
import '../widgets/empty_state.dart';
import 'privacy_screen.dart';

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key, required this.onOpenAccount});
  final VoidCallback onOpenAccount;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const AppPageTitle(
          title: '商城',
          subtitle: '选择适合你的套餐',
          icon: Icons.storefront_outlined,
        ),
        actions: [
          if (auth.isSignedIn && auth.applePurchases.supported)
            TextButton(
              onPressed: auth.applePurchases.canRestore
                  ? auth.applePurchases.restore
                  : null,
              child: const Text('恢复购买'),
            ),
          IconButton(
            tooltip: '刷新套餐',
            onPressed: auth.isSignedIn && !auth.storeLoading
                ? auth.refreshStorePlans
                : null,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: AppBackdrop(child: _body(context, auth)),
    );
  }

  Widget _body(BuildContext context, AuthProvider auth) {
    if (!auth.isSignedIn) {
      return EmptyState(
        icon: Icons.storefront_outlined,
        title: '登录后查看 iOS 套餐',
        message: '商城使用你的现有账号，仅展示苹果渠道套餐。',
        action:
            FilledButton(onPressed: onOpenAccount, child: const Text('前往登录')),
      );
    }
    if (auth.storeLoading && auth.storePlans.isEmpty) {
      return const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('正在加载套餐…'),
      ]));
    }
    if (auth.storeError.isNotEmpty && auth.storePlans.isEmpty) {
      return ErrorView(
          message: auth.storeError, onRetry: auth.refreshStorePlans);
    }
    if (auth.storePlans.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_bag_outlined,
        title: auth.storeLoaded ? '暂无 iOS 套餐' : '查看 iOS 套餐',
        message: auth.storeLoaded ? '苹果渠道暂无可展示的套餐，请稍后刷新。' : '从服务器加载苹果渠道的真实套餐。',
        action: FilledButton.tonalIcon(
          onPressed: auth.refreshStorePlans,
          icon: const Icon(Icons.refresh),
          label: Text(auth.storeLoaded ? '刷新套餐' : '加载套餐'),
        ),
      );
    }
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: auth.refreshStorePlans,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          if (auth.storeLoading) const LinearProgressIndicator(),
          Text('iOS 专属套餐', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
              '${!auth.applePurchases.supported ? '当前浏览器或平台仅支持套餐预览，可切换月付／年付。Apple 订阅请在 iPhone 或 iPad App 内操作。' : auth.applePurchases.canRestore ? '订阅由 Apple 管理，月付或年付自动续订，可在系统订阅设置中取消。' : '以下为套餐预览，Apple 应用内购买尚未开放。'}'
              '美元标价对应美国区，实际结算币种与金额以 Apple 购买页面为准。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          if (auth.applePurchases.currentSubscription
              case final subscription?) ...[
            AppSurface(
                child: AppleSubscriptionSummary(
                    subscription: subscription,
                    planName: auth.storePlans
                        .where((p) => p.id == subscription.planId)
                        .firstOrNull
                        ?.name)),
            const SizedBox(height: 16),
          ],
          if (auth.applePurchases.busy) const LinearProgressIndicator(),
          if (auth.applePurchases.error.isNotEmpty) ...[
            Text(auth.applePurchases.error,
                style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 12),
          ],
          if (auth.applePurchases.message.isNotEmpty) ...[
            Semantics(
                liveRegion: true, child: Text(auth.applePurchases.message)),
            const SizedBox(height: 12),
          ],
          if (auth.storeError.isNotEmpty) ...[
            Text('刷新失败，当前显示上次加载结果：${auth.storeError}',
                style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 12),
          ],
          for (final plan in auth.storePlans) ...[
            _PlanCard(key: ValueKey(plan.id), plan: plan),
            const SizedBox(height: 16),
          ],
          Wrap(spacing: 12, runSpacing: 4, children: [
            TextButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const PrivacyScreen())),
                child: const Text('隐私与数据')),
            TextButton(
                onPressed: () => openLink(context,
                    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
                child: const Text('使用条款')),
            if (auth.applePurchases.supported)
              TextButton(
                  onPressed: () => openLink(
                      context, 'https://apps.apple.com/account/subscriptions'),
                  child: const Text('管理 Apple 订阅')),
          ]),
        ],
      ),
    );
  }

  static Future<void> openLink(BuildContext context, String url) async {
    try {
      if (await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('暂时无法打开，请稍后重试')));
    }
  }
}

class _PlanCard extends StatefulWidget {
  const _PlanCard({super.key, required this.plan});
  final StorePlan plan;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  StorePeriod? _period;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final purchases = context.watch<AuthProvider>().applePurchases;
    final subscription = purchases.currentSubscription;
    final offer = plan.offers.where((o) => o.period == _period).firstOrNull ??
        plan.offers
            .where((o) => o.productId == subscription?.productId)
            .firstOrNull ??
        plan.offers.first;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final appleProduct = purchases.product(offer.productId);
    // US storefront: use the live Apple quote, not a potentially stale list
    // price. Else retain the requested USD list alongside local settlement.
    final usdPrice = appleProduct?.currencyCode == 'USD'
        ? '\$${appleProduct!.rawPrice.toStringAsFixed(2)}'
        : offer.usdDisplayPrice;
    return AppSurface(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(plan.name, style: theme.textTheme.titleMedium),
        if (subscription?.active == true &&
            subscription?.productId == offer.productId)
          const Text('✓ 当前已订阅'),
        const SizedBox(height: 12),
        Text('${_number(plan.trafficGb)} GB',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              color: scheme.primary,
            )),
        Text(plan.resetsMonthly ? '每月流量额度' : '套餐流量额度',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final option in plan.offers)
            Semantics(
              selected: option.period == offer.period,
              child: OutlinedButton(
                key: ValueKey('store-period-${plan.id}-${option.period.name}'),
                // Period comparison is local UI, independent of StoreKit access.
                // Use an explicit 48px target in mouse/touch preview as on iOS.
                onPressed: () => setState(() => _period = option.period),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(88, 48),
                  visualDensity: VisualDensity.standard,
                  backgroundColor: option.period == offer.period
                      ? scheme.primaryContainer
                      : null,
                  foregroundColor: option.period == offer.period
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (option.period == offer.period) ...[
                    const Icon(Icons.check_rounded, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(option.period.label),
                ]),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        Text(
            usdPrice == null
                ? '美元价格待同步'
                : '$usdPrice / ${offer.period == StorePeriod.monthly ? "月" : "年"}',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        if (appleProduct != null && appleProduct.currencyCode != 'USD') ...[
          const SizedBox(height: 8),
          Text(
              'Apple 结算价：${appleProduct.price} / ${offer.period == StorePeriod.monthly ? "月" : "年"}',
              style: theme.textTheme.bodySmall),
        ],
        if (offer.period == StorePeriod.yearly && plan.resetsMonthly) ...[
          const SizedBox(height: 8),
          Text('按年付费，每月重置 ${_number(plan.trafficGb)} GB，不一次性发放全年流量。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 16),
        Wrap(spacing: 20, runSpacing: 8, children: [
          Text('设备限制：${_limit(plan.deviceLimit, "台")}'),
          Text('速度限制：${_limit(plan.speedLimitMbps, "Mbps")}'),
        ]),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: purchases.supported &&
                  subscription?.active == true &&
                  !purchases.busy
              ? () => StoreScreen.openLink(
                  context, 'https://apps.apple.com/account/subscriptions')
              : purchases.canBuy(offer.productId)
                  ? () => purchases.buy(offer.productId!)
                  : null,
          child: Text(!purchases.supported
              ? '请在 iPhone／iPad App 内订阅'
              : purchases.busy
                  ? '正在处理 Apple 购买…'
                  : subscription?.active == true
                      ? subscription?.productId == offer.productId
                          ? '管理当前订阅'
                          : '前往 Apple 管理套餐变更'
                      : purchases.canBuy(offer.productId)
                          ? '通过 Apple 订阅'
                          : purchases.canRestore && appleProduct == null
                              ? 'Apple 商品暂不可用'
                              : purchases.reason),
        ),
      ],
    ));
  }

  static String _limit(int? value, String unit) =>
      value == null || value <= 0 ? '不限' : '$value $unit';
  static String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
