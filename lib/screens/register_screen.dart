import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/registration_config.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/auth_form_components.dart';
import 'privacy_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({this.initialEmail = '', super.key});
  final String initialEmail;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _emailKey = GlobalKey<FormFieldState<String>>();
  final _captchaKey = GlobalKey<FormFieldState<String>>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _answer = TextEditingController();
  final _emailCode = TextEditingController();
  final _invite = TextEditingController();
  RegistrationConfig? _config;
  RegistrationCaptcha? _captcha;
  bool _loading = true;
  bool _captchaLoading = false;
  bool _sending = false;
  bool _submitting = false;
  bool _accepted = false;
  String _error = '';
  String _notice = '';
  String _codeEmail = '';
  DateTime? _resendAt;
  Timer? _timer;
  int get _secondsLeft => _resendAt == null
      ? 0
      : (_resendAt!.difference(DateTime.now()).inMilliseconds / 1000)
          .ceil()
          .clamp(0, 60);
  bool get _busy => _sending || _submitting;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in [
      _email,
      _password,
      _confirm,
      _answer,
      _emailCode,
      _invite
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final auth = context.read<AuthProvider>();
      final config = await auth.getRegistrationConfig();
      if (!mounted) return;
      setState(() => _config = config);
      if (config.simpleCaptcha) await _reloadCaptcha();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadCaptcha() async {
    setState(() {
      _captchaLoading = true;
      _captcha = null;
      _answer.clear();
    });
    try {
      final captcha =
          await context.read<AuthProvider>().getRegistrationCaptcha();
      if (mounted) setState(() => _captcha = captcha);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _captchaLoading = false);
    }
  }

  Future<void> _sendCode() async {
    if (_busy ||
        _secondsLeft > 0 ||
        !(_emailKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!_accepted) {
      setState(() => _error = '请先阅读并同意隐私政策');
      return;
    }
    if (_config!.simpleCaptcha &&
        !(_captchaKey.currentState?.validate() ?? false)) {
      return;
    }
    final email = _email.text.trim();
    setState(() {
      _sending = true;
      _error = '';
      _notice = '';
    });
    try {
      await context.read<AuthProvider>().sendRegistrationEmailCode(
            email: email,
            captchaToken: _captcha?.token ?? '',
            captchaAnswer: _answer.text,
          );
      if (!mounted) return;
      setState(() {
        _codeEmail = email;
        _resendAt = DateTime.now().add(const Duration(seconds: 60));
        _notice = '验证码已提交发送，请检查收件箱或垃圾邮件，5 分钟内有效。';
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _secondsLeft == 0) timer.cancel();
        if (mounted) setState(() {});
      });
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      // The backend consumes a simple challenge on every verification attempt.
      if (mounted && _config!.simpleCaptcha) await _reloadCaptcha();
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _submit() async {
    if (_busy ||
        _captchaLoading ||
        _config == null ||
        _config!.externalCaptcha) {
      return;
    }
    if (!_form.currentState!.validate()) return;
    if (!_accepted) {
      setState(() => _error = '请先阅读并同意隐私政策');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = '';
      _notice = '';
    });
    final auth = context.read<AuthProvider>();
    final success = await auth.register(RegistrationInput(
      email: _email.text,
      password: _password.text,
      emailCode: _emailCode.text,
      inviteCode: _invite.text,
      captchaToken: _captcha?.token ?? '',
      captchaAnswer: _answer.text,
    ));
    if (!mounted) return;
    if (success) {
      TextInput.finishAutofillContext(shouldSave: true);
      _password.clear();
      _confirm.clear();
      setState(() => _submitting = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('账号已创建并登录')));
    } else {
      TextInput.finishAutofillContext(shouldSave: false);
      setState(() => _error = auth.error);
      if (_config!.simpleCaptcha) await _reloadCaptcha();
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = _config;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('邮箱注册')),
        body: AppBackdrop(
            child: AutofillGroup(
                child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const AuthHeading(
                title: '创建皮卡云账号', subtitle: '使用邮箱管理你的账号。注册不会自动购买或开通套餐。'),
            const SizedBox(height: 24),
            if (_loading)
              const Center(child: CircularProgressIndicator.adaptive())
            else if (config == null) ...[
              AuthStatusMessage(message: _error, isError: true),
              const SizedBox(height: 16),
              OutlinedButton(
                  onPressed: _loadConfig, child: const Text('重新获取注册配置')),
            ] else if (config.externalCaptcha)
              const AuthStatusMessage(
                message: '服务器已启用其他人机验证，当前客户端暂不支持。请返回登录，或联系服务方。',
                isError: true,
              )
            else
              Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        key: _emailKey,
                        controller: _email,
                        enabled: !_busy,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.newUsername,
                          AutofillHints.email
                        ],
                        autocorrect: false,
                        textCapitalization: TextCapitalization.none,
                        decoration: const InputDecoration(
                            labelText: '邮箱',
                            prefixIcon: Icon(Icons.mail_outline_rounded)),
                        validator: config.validateEmail,
                        onChanged: (_) {
                          if (_codeEmail.isNotEmpty &&
                              _email.text.trim() != _codeEmail) {
                            setState(() {
                              _emailCode.clear();
                              _notice = '';
                            });
                          }
                        },
                      ),
                      if (config.emailSuffixes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(bottom: 12),
                          title:
                              Text('支持的邮箱', style: theme.textTheme.bodySmall),
                          children: [
                            Text(config.emailSuffixes.join('、'),
                                style: theme.textTheme.bodySmall)
                          ],
                        ),
                      ] else
                        const SizedBox(height: 16),
                      AuthPasswordField(
                          controller: _password,
                          enabled: !_busy,
                          creating: true,
                          validator: (value) => (value ?? '').runes.length < 8
                              ? '密码至少需要 8 位'
                              : null),
                      const SizedBox(height: 16),
                      AuthPasswordField(
                          controller: _confirm,
                          enabled: !_busy,
                          creating: true,
                          label: '确认密码',
                          validator: (value) =>
                              value != _password.text || (value ?? '').isEmpty
                                  ? '两次输入的密码不一致'
                                  : null),
                      if (config.simpleCaptcha) ...[
                        const SizedBox(height: 20),
                        Text('安全验证', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                              child: Text(
                                  _captchaLoading
                                      ? '正在获取题目…'
                                      : _captcha?.question ?? '题目获取失败',
                                  style: theme.textTheme.titleLarge)),
                          TextButton(
                              onPressed: _busy || _captchaLoading
                                  ? null
                                  : _reloadCaptcha,
                              child: const Text('换一道')),
                        ]),
                        TextFormField(
                          key: _captchaKey,
                          controller: _answer,
                          enabled: !_busy && !_captchaLoading,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: const InputDecoration(
                              labelText: '计算结果',
                              prefixIcon: Icon(Icons.shield_outlined)),
                          validator: (value) {
                            if (_captcha == null) return '请重新获取题目';
                            if (_captcha!.isExpired) return '题目已过期，请点击“换一道”';
                            if ((value ?? '').isEmpty) return '请输入计算结果';
                            return null; // The answer is validated by the server only.
                          },
                        ),
                      ],
                      if (config.emailVerification) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: _emailCode,
                            enabled: !_busy,
                            keyboardType: TextInputType.number,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            decoration:
                                const InputDecoration(labelText: '邮箱验证码'),
                            validator: (value) => (value ?? '').trim().isEmpty
                                ? '请输入邮箱验证码'
                                : null),
                        Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed:
                                  _busy || _captchaLoading || _secondsLeft > 0
                                      ? null
                                      : _sendCode,
                              child: Text(_sending
                                  ? '正在发送…'
                                  : _secondsLeft > 0
                                      ? '$_secondsLeft 秒后重发'
                                      : '发送邮箱验证码'),
                            )),
                        if (config.simpleCaptcha)
                          Text('发送邮件后，请重新完成安全验证再创建账号。',
                              style: theme.textTheme.bodySmall),
                      ],
                      const SizedBox(height: 12),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        initiallyExpanded: config.inviteRequired,
                        title: Text(
                            config.inviteRequired ? '邀请码（必填）' : '有邀请码？（可选）',
                            style: theme.textTheme.bodyMedium),
                        children: [
                          TextFormField(
                              controller: _invite,
                              enabled: !_busy,
                              autocorrect: false,
                              decoration:
                                  const InputDecoration(labelText: '邀请码'),
                              validator: (value) => config.inviteRequired &&
                                      (value ?? '').trim().isEmpty
                                  ? '请输入邀请码'
                                  : null),
                          const SizedBox(height: 12)
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                                value: _accepted,
                                semanticLabel: '同意隐私政策',
                                onChanged: _busy
                                    ? null
                                    : (value) => setState(
                                        () => _accepted = value ?? false)),
                            Expanded(
                                child: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                  const Text('我已阅读并同意'),
                                  TextButton(
                                      onPressed: () => Navigator.of(context)
                                          .push(MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  const PrivacyScreen())),
                                      child: const Text('隐私政策')),
                                ])),
                          ]),
                      if (_error.isNotEmpty) ...[
                        AuthStatusMessage(message: _error, isError: true),
                        const SizedBox(height: 12),
                      ],
                      if (_notice.isNotEmpty) ...[
                        AuthStatusMessage(message: _notice),
                        const SizedBox(height: 12),
                      ],
                      FilledButton(
                        onPressed: _busy || _captchaLoading ? null : _submit,
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: _submitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator.adaptive(
                                        strokeWidth: 2))
                                : const Text('创建账号并登录')),
                      ),
                      const SizedBox(height: 12),
                      Text('邮箱、密码和验证信息仅通过 HTTPS 提交至皮卡云账号服务器。密码不保存在本机。',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                      TextButton(
                          onPressed:
                              _busy ? null : () => Navigator.of(context).pop(),
                          child: const Text('已有账号？返回登录')),
                    ],
                  )),
          ],
        ))),
      ),
    );
  }
}
