import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/account_deletion.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});
  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _password = TextEditingController();
  AccountDeletionPreview? _preview;
  String _error = '';
  bool _acknowledged = false, _busy = false, _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final preview =
          await context.read<AuthProvider>().accountDeletionPreview();
      if (mounted) setState(() => _preview = preview);
    } on AuthException catch (error) {
      if (mounted && !context.read<AuthProvider>().isSignedIn) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
        Navigator.pop(context);
        return;
      }
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '无法核对删除信息，请稍后重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_busy || !_acknowledged || _password.text.isEmpty) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog.adaptive(
              title: const Text('永久删除账户？'),
              content: const Text(
                  '账号、剩余套餐权益和个人数据将删除，无法恢复。Apple 自动续订不会随账户删除而取消；请先在 Apple 中取消不再需要的订阅。此操作不自动退款。'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('保留账户')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error),
                    child: const Text('确认永久删除')),
              ],
            ));
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    final password = _password.text;
    _password.clear();
    try {
      final auth = context.read<AuthProvider>();
      final result = await auth.deleteAccount(password);
      if (!mounted) return;
      if (result['pending_settlement'] == true && result['deleted'] != true) {
        await _load();
        return;
      }
      final message = auth.error.isNotEmpty
          ? auth.error
          : result['cleanup_complete'] == true
              ? '账户已永久删除。Apple 订阅仍请在系统中确认已取消。'
              : '账户已删除，登录权限已撤销；剩余数据清理正在处理。';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      Navigator.pop(context);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '未能确认删除结果，请稍后重新进入本页核对');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
            title: const Text('删除账户'), automaticallyImplyLeading: !_busy),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text('删除前请确认', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          const Text('这不是退出登录或暂时停用。完成后将删除皮卡云登录账户、邮箱及个人资料，并撤销所有设备登录凭证和原订阅链接。'),
          const SizedBox(height: 12),
          const Text('剩余套餐及流量权益将终止，不能通过重新注册恢复。不自动退款；账户删除与 Apple 订阅取消是两个独立操作。'),
          const SizedBox(height: 12),
          const Text(
              '为履行适用的财务与争议处理要求，必要订单、交易及防重复认领标识会保留，不用于恢复账号或广告跟踪。本机查询历史不关联账号，可在“隐私与数据”中单独清除。'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      if (!await launchUrl(
                              Uri.parse(
                                  'https://apps.apple.com/account/subscriptions/'),
                              mode: LaunchMode.externalApplication) &&
                          context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('请打开“设置 → Apple 账户 → 订阅”取消续订')));
                      }
                    },
              icon: const Icon(Icons.open_in_new),
              label: const Text('先管理／取消 Apple 订阅')),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_preview == null)
            OutlinedButton(
                onPressed: _busy ? null : _load, child: const Text('重新核对删除信息'))
          else if (_preview!.pendingSettlement) ...[
            const Text(
                '删除申请已提交，等待余额、佣金或付款完成结算。资金不会自动清零；结算完成后会自动删除，无需重新申请或另发邮件。'),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: _busy ? null : _load, child: const Text('查看删除进度')),
          ] else ...[
            if (_preview!.hasActivePackage)
              const Text('当前仍有套餐权益。确认删除将立即终止在皮卡云的使用权限。'),
            if (_preview!.requiresSettlement)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child:
                      Text('账户有余额、佣金或正在处理的付款。确认后将先提交删除申请，结算完成后自动删除；资金不会自动清零。')),
            const SizedBox(height: 12),
            TextField(
                controller: _password,
                obscureText: true,
                enabled: !_busy,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                    labelText: '当前账户密码',
                    helperText: '仅发送至皮卡云验证身份，不在本机保存',
                    helperMaxLines: 3),
                onChanged: (_) => setState(() {})),
            CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _acknowledged,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _acknowledged = v ?? false),
                title: const Text('我已了解删除不可恢复，且需另行取消 Apple 自动续订')),
            const SizedBox(height: 16),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                    minimumSize: const Size(double.infinity, 48)),
                onPressed: !_busy &&
                        auth.isSignedIn &&
                        _acknowledged &&
                        _password.text.isNotEmpty
                    ? _delete
                    : null,
                child: Text(_busy
                    ? '正在确认删除…'
                    : _preview!.requiresSettlement
                        ? '提交账户删除申请'
                        : '永久删除账户')),
          ],
          if (_error.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Semantics(
                    liveRegion: true,
                    child:
                        Text(_error, style: TextStyle(color: scheme.error)))),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}
