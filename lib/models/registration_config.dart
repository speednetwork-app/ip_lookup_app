/// Public registration rules returned by the existing account backend.
class RegistrationConfig {
  const RegistrationConfig({
    required this.emailVerification,
    required this.inviteRequired,
    required this.simpleCaptcha,
    required this.externalCaptcha,
    required this.emailSuffixes,
  });

  final bool emailVerification;
  final bool inviteRequired;
  final bool simpleCaptcha;
  final bool externalCaptcha;
  final List<String> emailSuffixes;

  factory RegistrationConfig.fromJson(Map<String, dynamic> json) {
    bool enabled(dynamic value) => value == true || value == 1 || value == '1';
    final suffixes = json['email_whitelist_suffix'];
    final simple = enabled(json['simple_captcha_enable']);
    return RegistrationConfig(
      emailVerification: enabled(json['is_email_verify']),
      inviteRequired: enabled(json['is_invite_force']),
      simpleCaptcha: simple,
      externalCaptcha: !simple &&
          (enabled(json['is_captcha']) || enabled(json['is_recaptcha'])),
      emailSuffixes: suffixes is List
          ? suffixes.whereType<String>().map((s) => s.toLowerCase()).toList()
          : const [],
    );
  }

  String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return '请输入邮箱';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return '请输入有效邮箱';
    }
    if (emailSuffixes.isNotEmpty &&
        !emailSuffixes.contains(email.split('@').last.toLowerCase())) {
      return '该邮箱后缀暂不受支持，请查看下方支持的邮箱';
    }
    return null;
  }
}

class RegistrationCaptcha {
  const RegistrationCaptcha({
    required this.token,
    required this.question,
    required this.expiresAt,
  });

  final String token;
  final String question;
  final DateTime expiresAt;
  bool get isExpired => !DateTime.now().isBefore(expiresAt);
}

class RegistrationInput {
  const RegistrationInput({
    required this.email,
    required this.password,
    this.emailCode = '',
    this.inviteCode = '',
    this.captchaToken = '',
    this.captchaAnswer = '',
  });

  final String email;
  final String password;
  final String emailCode;
  final String inviteCode;
  final String captchaToken;
  final String captchaAnswer;

  Map<String, dynamic> toJson() => {
        'email': email.trim(),
        'password': password,
        if (emailCode.trim().isNotEmpty) 'email_code': emailCode.trim(),
        if (inviteCode.trim().isNotEmpty) 'invite_code': inviteCode.trim(),
        if (captchaToken.isNotEmpty) 'simple_captcha_token': captchaToken,
        if (captchaAnswer.trim().isNotEmpty)
          'simple_captcha_answer': captchaAnswer.trim(),
      };
}
