import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
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
        title: const Text('我的'),
        actions: [
          IconButton(
            tooltip: '隐私与数据',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()),
            ),
            icon: const Icon(Icons.privacy_tip_outlined),
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          switch (auth.status) {
            case AuthStatus.initializing:
              return const Center(child: CircularProgressIndicator());
            case AuthStatus.signedOut:
            case AuthStatus.signingIn:
              _showSubscribeUrl = false;
              return _LoginView(auth: auth);
            case AuthStatus.signedIn:
              return _buildAccount(context, auth);
          }
        },
      ),
    );
  }

  Widget _buildAccount(BuildContext context, AuthProvider auth) {
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: auth.refreshSubscription,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Icon(Icons.person_outline, color: scheme.primary),
              ),
              title: const Text('已登录'),
              subtitle: Text(auth.email),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.link, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '订阅地址',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      if (auth.isRefreshing)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (auth.subscribeUrl.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SelectableText(
                        _showSubscribeUrl
                            ? auth.subscribeUrl
                            : _maskedUrl(auth.subscribeUrl),
                        maxLines: _showSubscribeUrl ? null : 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => setState(
                              () => _showSubscribeUrl = !_showSubscribeUrl,
                            ),
                            icon: Icon(
                              _showSubscribeUrl
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            label: Text(_showSubscribeUrl ? '隐藏' : '显示'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _copy(context, auth.subscribeUrl),
                            icon: const Icon(Icons.copy_outlined),
                            label: const Text('复制'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '订阅地址包含访问凭证，请勿分享给他人。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ] else if (!auth.isRefreshing)
                    Text(auth.error.isEmpty ? '当前账号暂无可用订阅地址' : auth.error),
                  if (auth.subscribeUrl.isNotEmpty &&
                      auth.error.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(auth.error, style: TextStyle(color: scheme.error)),
                  ],
                  if (!auth.isRefreshing && auth.subscribeUrl.isEmpty) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: auth.refreshSubscription,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重新获取'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: auth.logout,
            icon: const Icon(Icons.logout),
            label: const Text('退出登录'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  static String _maskedUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return '••••••••';
    return '${uri.scheme}://${uri.host}/••••••••••••';
  }

  Future<void> _copy(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('订阅地址已复制')));
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
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 20),
          Icon(Icons.account_circle_outlined, size: 64, color: scheme.primary),
          const SizedBox(height: 16),
          Text(
            '登录已有账号',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '登录后可查看并复制你的订阅地址。IP 查询功能无需登录。',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: scheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '登录时，邮箱和密码仅通过 HTTPS 发送至账号服务器进行验证；'
                      '密码不会保存在本机。登录凭证保存在 iOS 钥匙串中。账号数据、'
                      '登录凭证和订阅地址不会出售或披露给第三方。',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
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
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return '请输入邮箱';
                    if (!email.contains('@')) return '请输入有效邮箱';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  enabled: !loading,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: '密码',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
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
            const SizedBox(height: 16),
            Text(
              widget.auth.error,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: loading ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
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
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
