import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _toJapanese(String message) {
    final m = message.toLowerCase();
    if (m.contains('already registered') ||
        m.contains('alrady been registered')) {
      return 'このメールアドレスは既に登録されています';
    }
    if (m.contains('password') && m.contains('at least')) {
      return 'パスワードは6文字以上で設定してください';
    }
    if (m.contains('invalid') && m.contains('email')) {
      return 'メールアドレスの形式が正しくありません';
    }
    if (m.contains('rate limit')) {
      return '短時間に何度も試されました。お時間をおいて再度お試しください';
    }
    return '登録に失敗しました。入力内容をご確認ください';
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'メールアドレスとパスワードを入力してください');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.signUp(email: email, password: password);
      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = _toJapanese(e.message));
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = '通信に失敗しました。時間をおいて再度お試しください');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新規アカウント作成')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'メールアドレス'),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'パスワード'),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _register,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('新規作成'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
