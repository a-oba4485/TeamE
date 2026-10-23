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
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // Supabaseの英語のエラー文を、日本語に変える
  String _toJapanese(String message) {
    final m = message.toLowerCase();
    if (m.contains('already registered') ||
        m.contains('already been registered')) {
      return 'このメールアドレスは既に登録されています';
    }
    if (m.contains('password') && m.contains('at least')) {
      return 'パスワードは6文字以上で設定してください';
    }
    if (m.contains('invalid') && m.contains('email')) {
      return 'メールアドレスの形式が正しくありません';
    }
    if (m.contains('rate limit')) {
      return '短時間に何度も試されました。時間をおいて再度お試しください';
    }
    return '登録に失敗しました。入力内容をご確認ください';
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    // 入力チェック
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = '未入力の項目があります');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'パスワードは6文字以上で設定してください');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'パスワードが一致しません');
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
      // 登録画面を閉じて、AuthGateが切り替えた画面（地図）を表示する
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
    final primary = Theme.of(context).colorScheme.primary;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE1E3E8)),
    );

    // 入力欄の見た目を作る部品（3つの欄で使い回す）
    InputDecoration fieldStyle(String label, IconData icon, {Widget? suffix}) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: fieldBorder,
        enabledBorder: fieldBorder,
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFFDECE8),
                  child: Icon(Icons.person_add_alt_1_outlined, color: primary),
                ),
                const SizedBox(height: 12),
                const Text(
                  '新規アカウント作成',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  '旅の記録をはじめましょう',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: fieldStyle('メールアドレス', Icons.email_outlined),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: fieldStyle(
                    'パスワード',
                    Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      tooltip: _obscurePassword ? 'パスワードを表示' : 'パスワードを隠す',
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  decoration: fieldStyle(
                    'パスワード確認',
                    Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      tooltip: _obscureConfirm ? 'パスワードを表示' : 'パスワードを隠す',
                      onPressed: () {
                        setState(() => _obscureConfirm = !_obscureConfirm);
                      },
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _register,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '新規登録',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('すでにアカウントをお持ちですか？ ログイン'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
