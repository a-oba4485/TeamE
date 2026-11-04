import "package:flutter/material.dart";
import 'package:supabase_flutter/supabase_flutter.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentController =TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String _toJapanese(String message) {
    final m = message.toLowerCase();
    if (m.contains('different from the old password') || m.contains('same password')){
    return '新しいパスワードは現在と違うものにしてくださ';
    }
    if (m.contains('password') && m.contains('at least')) {
      return 'パスワードは6文字以上で設定してください';
    }
    if (m.contains('weak')) {
      return 'パスワードが簡単すぎます。別のパスワードにしてください';
    }
    if (m.contains('rate limit')) {
      return '短時間に何度も試されました。時間をおいて再度お試しください';
    }
    return '変更に失敗しました。入力内容をご確認ください';
  }


    Future<void> _changePassword() async {
    if (_isLoading) return;
    final current = _currentController.text;
    final newPassword = _newController.text;
    final confirm = _confirmController.text;

    if (current.isEmpty || newPassword.isEmpty || confirm.isEmpty) {
      setState(() => _errorMessage = '未入力の項目があります');
      return;
    }
    if (newPassword.length < 6) {
      setState(() => _errorMessage = '新しいパスワードは6文字以上で設定してください');
      return;
    }
    if (newPassword != confirm) {
      setState(() => _errorMessage = '新しいパスワードが一致しません');
      return;
    }
    if (newPassword == current) {
      setState(() => _errorMessage = '新しいパスワードは、現在のパスワードと違うものにしてください');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final email = supabase.auth.currentUser?.email;
      if (email == null) {
        setState(() => _errorMessage = 'ログイン情報を取得できませんでした');
        return;
      }

      try {
        await supabase.auth.signInWithPassword(
          email: email,
          password: current,
        );
      } on AuthException {
        setState(() => _errorMessage = '現在のパスワードが違います');
        return;
      }

      await supabase.auth.updateUser(UserAttributes(password: newPassword));
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('パスワードを変更しました')),
      );
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

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color:Color(0xFFE1E3E8)),
    );
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        filled: true,
        fillColor: Colors.white,
        border: border,
        enabledBorder: border,
        suffixIcon: ExcludeFocus(
          child: IconButton(
            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
            tooltip: obscure ? 'パスワードを表示' : 'パスワードを隠す',
            onPressed: onToggle,
          ),
      ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('パスワード変更'),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _passwordField(
                controller: _currentController,
                label: '現在のパスワード',
                obscure: _obscureCurrent,
                onToggle: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              const SizedBox(height: 14),
              _passwordField(
                controller: _newController,
                label: '新しいパスワード',
                obscure: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
              ),
              const SizedBox(height: 14),
              _passwordField(
                controller: _confirmController,
                label: '新しいパスワード（確認）',
                obscure: _obscureConfirm,
                onToggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
                            if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                                child: FilledButton(
                  onPressed: _isLoading ? null : _changePassword,
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
                          'パスワードを変更',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}