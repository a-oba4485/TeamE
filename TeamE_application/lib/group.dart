import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// グループ機能（B案：グループ管理まで。投稿共有は次回）
// 使い方：
//   1. Supabase ダッシュボードの SQL Editor で
//      supabase-groups-tables.sql を実行する（テーブル作成＋RLS＋ポリシーがセット）。
//      ※ groups / group_members を作る前に RLS の話はこの SQL の中に書いてある。
//      ※ posts の RLS（supabase-rls-posts-live.sql）は未適用のままでも、
//         このグループ管理だけは動く。投稿共有（A案）をやるときは別途 posts の
//         RLS 拡張が必要になるので、そのときに一緒に設計すること。
//   2. このファイルで lib/group.dart を置き換える。
//      main.dart の変更は不要（MapScreen のタブに GroupScreen がすでに登録済み）。
//   3. グループ作成→招待コードをメンバーに共有→相手はコード入力で参加、の流れで確認する。

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  // group_members の行＋埋め込みの groups。1要素＝所属グループ1つ。
  List<Map<String, dynamic>> _myGroups = [];

  // 招待コード用：紛らわしい I / O / 0 / 1 を除いた6文字
  static const String _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _generateInviteCode() {
    final random = Random.secure();
    return List.generate(
      6,
      (_) => _codeChars[random.nextInt(_codeChars.length)],
    ).join();
  }

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _myGroups = [];
        _loading = false;
      });
      return;
    }
    try {
      final data = await _supabase
          .from('group_members')
          .select('group_id, joined_at, groups(id, name, invite_code, created_by, created_at)')
          .eq('user_id', userId)
          .order('joined_at', ascending: true);
      if (!mounted) return;
      setState(() {
        _myGroups = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('グループの読み込みに失敗しました: $e')),
      );
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ==========================================================
  // グループ作成：groups に1行＋自分を group_members に1行
  // ==========================================================
  Future<void> _createGroup() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final nameController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('グループを作成'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: 'グループ名（例：TeamE）',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('作成'),
            ),
          ],
        );
      },
    );

    final name = nameController.text.trim();
    nameController.dispose();
    if (created != true || name.isEmpty || !mounted) return;

    try {
      // 招待コードが既存グループと被らないものを発行する（最大5回まで引き直す）
      String inviteCode = '';
      for (var i = 0; i < 5; i++) {
        final candidate = _generateInviteCode();
        final existing = await _supabase
            .from('groups')
            .select('id')
            .eq('invite_code', candidate)
            .maybeSingle();
        if (existing == null) {
          inviteCode = candidate;
          break;
        }
      }
      if (inviteCode.isEmpty) {
        _showSnack('招待コードの発行に失敗しました。もう一度試してください。');
        return;
      }

      final group = await _supabase
          .from('groups')
          .insert({
            'name': name,
            'invite_code': inviteCode,
            'created_by': user.id,
          })
          .select()
          .single();

      await _supabase.from('group_members').insert({
        'group_id': group['id'],
        'user_id': user.id,
        'user_email': user.email,
      });

      _showSnack('「$name」を作成しました。招待コード：$inviteCode');
      await _loadGroups();
    } catch (e) {
      _showSnack('作成に失敗しました: $e');
    }
  }

  // ==========================================================
  // 招待コードで参加
  // ==========================================================
  Future<void> _joinGroup() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final codeController = TextEditingController();
    final joined = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('招待コードで参加'),
          content: TextField(
            controller: codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: '6文字の招待コード',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('参加'),
            ),
          ],
        );
      },
    );

    final code = codeController.text.trim().toUpperCase();
    codeController.dispose();
    if (joined != true || code.isEmpty || !mounted) return;

    try {
      final group = await _supabase
          .from('groups')
          .select('id, name')
          .eq('invite_code', code)
          .maybeSingle();
      if (group == null) {
        _showSnack('その招待コードのグループが見つかりませんでした。');
        return;
      }

      final already = await _supabase
          .from('group_members')
          .select('id')
          .eq('group_id', group['id'])
          .eq('user_id', user.id)
          .maybeSingle();
      if (already != null) {
        _showSnack('すでに「${group['name']}」に参加しています。');
        return;
      }

      await _supabase.from('group_members').insert({
        'group_id': group['id'],
        'user_id': user.id,
        'user_email': user.email,
      });

      _showSnack('「${group['name']}」に参加しました。');
      await _loadGroups();
    } catch (e) {
      _showSnack('参加に失敗しました: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('グループ')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _myGroups.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'まだグループに参加していません。\nグループを作るか、招待コードで参加してください。',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadGroups,
                  child: ListView.builder(
                    itemCount: _myGroups.length,
                    itemBuilder: (context, index) {
                      final row = _myGroups[index];
                      final group = row['groups'] as Map<String, dynamic>? ?? {};
                      final isOwner =
                          group['created_by'] ==
                          _supabase.auth.currentUser?.id;
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.group_outlined),
                          title: Text(
                            group['name'] as String? ?? '(名前なし)',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            isOwner ? '作成者：あなた' : 'メンバーとして参加中',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GroupDetailPage(
                                  group: group,
                                  isOwner: isOwner,
                                ),
                              ),
                            );
                            _loadGroups();
                          },
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'joinGroup',
            onPressed: _joinGroup,
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('招待コードで参加'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'createGroup',
            onPressed: _createGroup,
            icon: const Icon(Icons.add),
            label: const Text('グループを作成'),
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// グループ詳細：メンバー一覧・招待コード・退会／削除
// ==========================================================
class GroupDetailPage extends StatefulWidget {
  final Map<String, dynamic> group;
  final bool isOwner;
  const GroupDetailPage({
    super.key,
    required this.group,
    required this.isOwner,
  });

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _members = [];

  String get _groupId => widget.group['id'] as String;
  String get _groupName => widget.group['name'] as String? ?? '(名前なし)';
  String get _inviteCode => widget.group['invite_code'] as String? ?? '';

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final data = await _supabase
          .from('group_members')
          .select('user_id, user_email, joined_at')
          .eq('group_id', _groupId)
          .order('joined_at', ascending: true);
      if (!mounted) return;
      setState(() {
        _members = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('メンバーの読み込みに失敗しました: $e')),
      );
    }
  }

  Future<void> _copyInviteCode() async {
    await Clipboard.setData(ClipboardData(text: _inviteCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('招待コードをコピーしました')),
    );
  }

  // メンバーは退会、作成者はグループ削除（メンバー行も一緒に消える）
  Future<void> _leaveGroup() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('グループを退会しますか？'),
        content: Text('「$_groupName」から抜けます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('退会する'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _supabase
          .from('group_members')
          .delete()
          .eq('group_id', _groupId)
          .eq('user_id', userId);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('退会に失敗しました: $e')),
      );
    }
  }

  Future<void> _deleteGroup() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('グループを削除しますか？'),
        content: const Text('グループと全メンバーの参加記録が削除されます。\n投稿そのものは各メンバーのものとして残ります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      // 先にメンバー行を消してからグループ本体を消す
      await _supabase.from('group_members').delete().eq('group_id', _groupId);
      await _supabase.from('groups').delete().eq('id', _groupId);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = _supabase.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(title: Text(_groupName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Colors.white,
                  child: ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: const Text('招待コード'),
                    subtitle: Text(
                      _inviteCode,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: _copyInviteCode,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'このコードをメンバーに共有すると、相手は「招待コードで参加」から入れます。',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Text(
                  'メンバー（${_members.length}人）',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ..._members.map((member) {
                  final isCreator =
                      member['user_id'] == widget.group['created_by'];
                  final isMe = member['user_id'] == myId;
                  return Card(
                    color: Colors.white,
                    child: ListTile(
                      leading: const Icon(Icons.account_circle_outlined),
                      title: Text(
                        member['user_email'] as String? ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        [
                          if (isCreator) '作成者',
                          if (isMe) 'あなた',
                        ].join('・'),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
                if (widget.isOwner)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: _deleteGroup,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('グループを削除する'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _leaveGroup,
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('グループを退会する'),
                  ),
              ],
            ),
    );
  }
}
