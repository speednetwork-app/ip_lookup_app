import 'package:flutter/material.dart';

class AuthHeading extends StatelessWidget {
  const AuthHeading({required this.title, required this.subtitle, super.key});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(Icons.person_outline_rounded,
            color: theme.colorScheme.primary, size: 30),
      ),
      const SizedBox(height: 24),
      Text(title, style: theme.textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text(subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )),
    ]);
  }
}

class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    required this.controller,
    this.enabled = true,
    this.creating = false,
    this.label = '密码',
    this.validator,
    this.onSubmitted,
    super.key,
  });
  final TextEditingController controller;
  final bool enabled;
  final bool creating;
  final String label;
  final String? Function(String?)? validator;
  final VoidCallback? onSubmitted;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.controller,
        enabled: widget.enabled,
        obscureText: _obscure,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: widget.onSubmitted == null
            ? TextInputAction.next
            : TextInputAction.done,
        autofillHints: [
          widget.creating ? AutofillHints.newPassword : AutofillHints.password
        ],
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: widget.creating && widget.label == '密码'
              ? '至少 8 位，可使用密码管理器生成'
              : null,
          helperMaxLines: 2,
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            tooltip: _obscure ? '显示${widget.label}' : '隐藏${widget.label}',
            onPressed: widget.enabled
                ? () => setState(() => _obscure = !_obscure)
                : null,
            icon: Icon(_obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined),
          ),
        ),
        validator: widget.validator,
        onFieldSubmitted: widget.enabled && widget.onSubmitted != null
            ? (_) => widget.onSubmitted!()
            : null,
      );
}

class AuthStatusMessage extends StatelessWidget {
  const AuthStatusMessage(
      {required this.message, this.isError = false, super.key});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isError
                ? theme.colorScheme.errorContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(isError ? Icons.error_outline : Icons.info_outline,
                size: 20,
                color: isError
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
                child: Text(message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isError
                          ? theme.colorScheme.onErrorContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ))),
          ]),
        ));
  }
}
