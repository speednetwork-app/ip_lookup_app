import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/history_provider.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('隐私与数据')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SummaryCard(),
          const SizedBox(height: 16),
          Text('数据如何使用', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const _InfoTile(
            icon: Icons.public,
            title: '公网 IP 与查询内容',
            description: '查询时，当前公网 IP 或你输入的 IP 地址会发送至 '
                'ipwho.is；该服务不可用时会改用 ipapi.co。',
          ),
          const _InfoTile(
            icon: Icons.location_on_outlined,
            title: 'IP 估算位置',
            description: '国家、地区、城市和坐标由 IP 地址估算。'
                '本 App 不申请或访问设备 GPS 定位，结果可能存在较大误差。',
          ),
          const _InfoTile(
            icon: Icons.map_outlined,
            title: '地图',
            description: '显示地图时，会向 OpenStreetMap 请求对应区域的地图图块。',
          ),
          const _InfoTile(
            icon: Icons.history,
            title: '本地查询历史',
            description: '查询历史最多保存 50 条，仅存于此设备，不会同步到云端。'
                '卸载 App 会删除这些记录。',
          ),
          const _InfoTile(
            icon: Icons.account_circle_outlined,
            title: '邮箱注册与登录（可选）',
            description: '仅在你主动注册或登录时，邮箱、密码以及必要的验证信息会通过 HTTPS '
                '发送至 api.pikayun.com，用于创建账号、防止滥用与身份验证。'
                '后端要求邮箱验证时，会向你提供的邮箱发送验证码。密码不会保存在本机。',
          ),
          const _InfoTile(
            icon: Icons.key_outlined,
            title: '账号数据与本地缓存',
            description: '登录凭证和账号邮箱保存在 iOS 钥匙串中，用于保持登录状态；'
                '套餐状态、流量趋势、有效期和使用限制会安全缓存于本机，以便网络异常时显示。'
                '系统公告仅在登录后读取。订阅地址和公告不会写入普通缓存。'
                '退出登录会删除本机登录凭证和账号缓存；用于恢复中断购买的最少操作记录会另行保存在钥匙串中，按账号隔离。',
          ),
          const _InfoTile(
            icon: Icons.shield_outlined,
            title: 'VPN 安全连接（可选）',
            description: '仅在你登录并主动开启后，App 才会向 api.pikayun.com '
                '获取所选线路的连接配置，并使用 Apple Network Extension 建立 VPN。'
                '连接期间，设备网络流量会通过所选线路传输；可随时从首页断开。',
          ),
          const SizedBox(height: 16),
          const _InfoTile(
            icon: Icons.receipt_long_outlined,
            title: 'Apple 订阅与购买验证',
            description: '使用应用内购买时，付款由 Apple 处理。服务器会验证并保存交易标识、商品、币种和标价、有效期'
                '及与皮卡云账号的关联，用于开通、恢复、续费和退款处理，不会获取银行卡信息。'
                '收到的 Apple 签名通知加密保存。退出登录或卸载不会取消 Apple 订阅，'
                '也不会删除服务端交易记录；请在 Apple 订阅设置中管理续订。'
                '年付套餐按购买生效日每月重置额度，不一次发放全年流量。',
          ),
          const _InfoTile(
            icon: Icons.manage_accounts_outlined,
            title: '删除账户',
            description:
                '登录后可在“我的 → 删除账户”发起删除，重新验证密码并确认后，删除登录账户和非必要个人资料、撤销所有登录凭证与原订阅链接，终止该账号的套餐使用权益。'
                '必要订单、交易记录和防重复认领标识按适用的财务与争议处理要求保留，不恢复账号、不用于广告跟踪。'
                'Apple 自动续订不会因删除账号自动取消；请先在 Apple 订阅设置中取消，不自动退款。'
                '有余额、佣金或正在处理的付款时，可先提交删除申请并在原页查看进度，结算完成后自动删除，不静默核销资金。'
                '本机查询历史不关联账号，可在本页单独清除。',
          ),
          const SizedBox(height: 16),
          Text('我们不会做什么', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Card(
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CheckRow(text: '不读取手机号、通讯录或设备账号'),
                  _CheckRow(text: '不访问照片、相机或麦克风'),
                  _CheckRow(text: '不申请 GPS 定位权限'),
                  _CheckRow(text: '不包含广告、分析 SDK 或用户追踪'),
                  _CheckRow(text: '注册不会自动购买套餐；Apple 订阅须由你在系统购买窗口确认'),
                  _CheckRow(text: '不出售账号数据，不向 Apple 发送皮卡云密码或 VPN 订阅地址'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('管理本地数据', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Consumer<HistoryProvider>(
            builder: (context, history, _) => OutlinedButton.icon(
              onPressed: history.entries.isEmpty
                  ? null
                  : () => _confirmClear(context, history),
              icon: const Icon(Icons.delete_outline),
              label: const Text('清空本机查询历史'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '服务：api.pikayun.com、Apple、ipwho.is、ipapi.co、OpenStreetMap\n'
            '隐私问题联系：info@robinads.agency',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    HistoryProvider history,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空本机查询历史？'),
        content: const Text('所有查询记录都会从此设备删除，此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) await history.clear();
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.privacy_tip_outlined, size: 40, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              '隐私说明',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'IP 查询无需登录。仅当你主动注册或登录时，App 才会处理邮箱、'
              '登录凭证和账号数据。VPN 安全连接仅在你主动开启后工作；'
              '不访问设备 GPS，不包含广告或用户追踪。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(description),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
