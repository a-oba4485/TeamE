import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'change_password_page.dart';
import 'delete_account_page.dart';
import 'profile.dart';

// マイページ：プロフィール（表示名・自分の色）＋アカウント管理
// プロフィールの保存には supabase-sharing-profiles.sql（profiles テーブル）が必要。
class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  String _selectedColorHex = kDefaultMapColorHex;
  bool _loadingProfile = true;
  bool _savingProfile = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _loadingProfile = false);
      return;
    }
    try {
      final profile = await fetchProfile(userId);
      if (!mounted) return;
      setState(() {
        _nameController.text = profile?['display_name'] as String? ?? '';
        final color = profile?['map_color'] as String?;
        if (color != null && color.isNotEmpty) {
          _selectedColorHex = color.toUpperCase();
        }
        _loadingProfile = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingProfile = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('プロフィールの読み込みに失敗しました: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _savingProfile = true);
    try {
      await _supabase.from('profiles').upsert({
        'user_id': user.id,
        'display_name': _nameController.text.trim(),
        'map_color': _selectedColorHex,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プロフィールを保存しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // ログイン状態が変わると、AuthGateがログイン画面に切り替える
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final email = _supabase.auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('マイページ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // プロフィール（表示名・自分の色）
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _loadingProfile
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.badge_outlined),
                            SizedBox(width: 8),
                            Text(
                              'プロフィール',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: '表示名（グループで表示されます）',
                            hintText: '例：username',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('地図で自分の県を塗る色'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: kMapColorPalette.map((hex) {
                            final selected = _selectedColorHex == hex;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedColorHex = hex),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: colorFromHex(hex),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selected
                                        ? Colors.black87
                                        : Colors.grey.shade300,
                                    width: selected ? 3 : 1,
                                  ),
                                ),
                                child: selected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 20,
                                      )
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _savingProfile ? null : _saveProfile,
                            child: Text(
                              _savingProfile ? '保存中…' : 'プロフィールを保存',
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          // ログイン中のメールアドレス
          Card(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('ログイン中のアカウント'),
              subtitle: Text(email),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.key),
                  title: const Text('パスワード変更'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordPage(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('ログアウト'),
                  onTap: () => _confirmLogout(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.person_remove_outlined,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'アカウント削除',
                    style: TextStyle(color: Colors.red),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.red),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DeleteAccountPage(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
