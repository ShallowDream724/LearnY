import 'package:flutter/material.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/typography.dart';

class AutoReloginSetupInput {
  const AutoReloginSetupInput({
    required this.username,
    required this.password,
  });

  final String username;
  final String password;
}

class AutoReloginSetupDialog extends StatefulWidget {
  const AutoReloginSetupDialog({super.key});

  @override
  State<AutoReloginSetupDialog> createState() => _AutoReloginSetupDialogState();
}

class _AutoReloginSetupDialogState extends State<AutoReloginSetupDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.trim().isEmpty) {
      setState(() {
        _errorMessage = '请输入统一身份账号和密码';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
    });
    Navigator.of(
      context,
    ).pop(AutoReloginSetupInput(username: username, password: password));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      title: Text(
        '启用自动重新登录',
        style: AppTypography.titleLarge.copyWith(
          color: context.colors.text,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '启用后，LearnY 会将账号密码与设备指纹保存到系统安全存储中，仅用于会话过期后的静默恢复，不会上传到我们的服务器。关闭此功能后会立即删除已保存信息。',
              style: AppTypography.bodyMedium.copyWith(
                color: context.colors.subtitle,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '统一身份账号',
                hintText: '请输入学号或统一身份账号',
              ),
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: '密码',
                hintText: '请输入统一身份认证密码',
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('继续'),
        ),
      ],
    );
  }
}
