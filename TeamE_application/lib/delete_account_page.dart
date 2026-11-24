import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  bool _isLoading = false;
  String? _errorMessage;

  static const _bucket = 'photos';
  static const _imageColumn = 'image_url';

  String? _pathFromUrl(String? url) {
    if (url == null) return null;
    final match = RegExp(
      '/object/(?:public|sign|authenticated)/$_bucket/([^?]+)',
    ).firstMatch(url);
    if (match == null) return null;
    return Uri.decodeComponent(match.group(1)!);
  }

  Future<void> _confirmAndDelete() async {
    if (_isLoading) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('アカウントを削除しますか？'),
        content: const Text('この操作は取り消せません。\nアカウントと、これまでの記録が削除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _errorMessage = 'ログイン情報を取得できませんでした');
        return;
      }

      final rows = await supabase
          .from('posts')
          .select(_imageColumn)
          .eq('user_id', userId);

      // ★修正: Storage の掃除はベストエフォートにする。
      // 以前は「パスが特定できない」「削除件数が一致しない」で return して
      // 退会自体を中断していたため、画像が1枚でも既に消えていると
      // 件数が永遠に合わず、二度とアカウントを削除できなくなっていた。
      // 画像の後片付けで退会をブロックしない。
      final paths = <String>[];
      for (final row in rows) {
        final url = row[_imageColumn] as String?;
        final path = _pathFromUrl(url);
        if (url != null && path == null) {
          // 特定できない画像はスキップして退会を続行する
          debugPrint('パスを取り出せませんでした（スキップします）: $url');
          continue;
        }
        if (path != null) paths.add(path);
      }
      debugPrint('削除する画像のパス: $paths');

      if (paths.isNotEmpty) {
        try {
          final removed = await supabase.storage.from(_bucket).remove(paths);
          debugPrint('画像: 対象${paths.length}件 / 削除${removed.length}件');
          if (removed.length != paths.length) {
            // 件数が合わなくても退会は続行する（残った画像は孤立ファイルとして残るだけ）
            debugPrint('一部の画像を削除できませんでしたが、退会を続行します');
          }
        } catch (e) {
          // Storage削除で例外が出ても退会は続行する
          debugPrint('画像削除でエラー（退会は続行します）: $e');
        }
      }

      // ここが本処理。失敗したらエラー表示して止まるのは従来どおり。
      await supabase.rpc('delete_my_account');

      await supabase.auth.signOut(scope: SignOutScope.local);
      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      debugPrint('アカウント削除エラー: $e');
      if (mounted) {
        setState(() => _errorMessage = '削除に失敗しました。時間をおいて再度お試しください');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アカウント削除'),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFFFDECE8),
                child: Icon(Icons.warning_amber_rounded, color: Colors.red),
              ),
              const SizedBox(height: 16),
              const Text(
                'アカウントを削除すると、元に戻せません',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'アカウント情報と、これまでの記録が削除されます。\n同じメールアドレスで、もう一度登録することはできますが、削除したデータは戻りません。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, height: 1.6),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _isLoading ? null : _confirmAndDelete,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
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
                          'アカウントを削除',
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
