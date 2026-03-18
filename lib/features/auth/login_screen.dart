import 'package:flutter/material.dart';

/// Placeholder — will be replaced with WebView SSO login.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.school_rounded,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text('LearnY', style: theme.textTheme.headlineLarge),
                const SizedBox(height: 8),
                Text(
                  '清华大学网络学堂',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: WebView SSO login
                    },
                    child: const Text('统一身份认证登录'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
