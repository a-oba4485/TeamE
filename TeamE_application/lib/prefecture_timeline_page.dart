import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

// 投稿・タイムライン画面
class PrefectureTimelinePage extends StatefulWidget {
  final String prefectureName;
  const PrefectureTimelinePage({super.key, required this.prefectureName});

  @override
  State<PrefectureTimelinePage> createState() => _PrefectureTimelinePageState();
}

class _PrefectureTimelinePageState extends State<PrefectureTimelinePage> {
  final _commentController = TextEditingController();
  bool _isUploading = false;
  final supabase = Supabase.instance.client;

  late final Stream<List<Map<String, dynamic>>> _postsStream;

  // 編集ダイアログの都道府県ドロップダウン用（47都道府県）
  static const List<String> _allPrefectures = [
    '北海道',
    '青森県', '岩手県', '宮城県', '秋田県', '山形県', '福島県',
    '茨城県', '栃木県', '群馬県', '埼玉県', '千葉県', '東京都', '神奈川県',
    '新潟県', '富山県', '石川県', '福井県', '山梨県', '長野県',
    '岐阜県', '静岡県', '愛知県',
    '三重県', '滋賀県', '京都府', '大阪府', '兵庫県', '奈良県', '和歌山県',
    '鳥取県', '島根県', '岡山県', '広島県', '山口県',
    '徳島県', '香川県', '愛媛県', '高知県',
    '福岡県', '佐賀県', '長崎県', '熊本県', '大分県', '宮崎県', '鹿児島県',
    '沖縄県',
  ];

  @override
  void initState() {
    super.initState();

    // 現在ログインしているユーザーのIDを取得
    final userId = supabase.auth.currentUser?.id;

    if (userId != null) {
      // ログイン中の場合：県名 と 自分のID の両方で絞り込む！
      _postsStream = supabase
          .from('posts')
          .stream(primaryKey: ['id'])
          .eq('prefecture', widget.prefectureName)
          .eq('user_id', userId)
          .order('created_at', ascending: false);
    } else {
      // ログインしていない場合は空っぽにする
      _postsStream = const Stream.empty();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('写真を投稿するには、先にログインが必要です！')),
      );
      return;
    }
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final bytes = await image.readAsBytes();
      final fileExt = image.name.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage.from('photos').uploadBinary(fileName, bytes);

      final imageUrl = supabase.storage.from('photos').getPublicUrl(fileName);

      await supabase.from('posts').insert({
        'user_id': user.id,
        'user_email': user.email,
        'prefecture': widget.prefectureName,
        'image_url': imageUrl,
        'comment': _commentController.text,
      });

      _commentController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('アップロード成功！')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // ==========================================================
  // ★追加: 投稿の編集（コメント＋都道府県）
  // ==========================================================
  Future<void> _editPost(Map<String, dynamic> post) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final editController = TextEditingController(
      text: post['comment'] as String? ?? '',
    );
    String selectedPrefecture =
        _allPrefectures.contains(post['prefecture'])
            ? post['prefecture'] as String
            : widget.prefectureName;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('投稿を編集'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('都道府県'),
                    const SizedBox(height: 4),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selectedPrefecture,
                      items: _allPrefectures
                          .map(
                            (pref) => DropdownMenuItem(
                              value: pref,
                              child: Text(pref),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedPrefecture = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('コメント'),
                    const SizedBox(height: 4),
                    TextField(
                      controller: editController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'コメントを入力...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true || !mounted) {
      editController.dispose();
      return;
    }

    final newComment = editController.text;
    final newPrefecture = selectedPrefecture;
    editController.dispose();

    try {
      await supabase
          .from('posts')
          .update({'comment': newComment, 'prefecture': newPrefecture})
          .eq('id', post['id'])
          .eq('user_id', userId); // 自分の投稿だけ更新できるよう二重に絞る

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newPrefecture == widget.prefectureName
                ? '投稿を更新しました'
                : '$newPrefecture へ移動しました',
          ),
        ),
      );
      // 県を変えた場合、この画面のStreamからは自動で消える。
      // 地図の色付けは、戻ったときに main.dart 側で再取得される。
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('編集に失敗しました: $e')),
      );
    }
  }

  // ==========================================================
  // ★追加: 投稿の削除（DBの行＋Storageの実ファイル）
  // ==========================================================

  /// 公開URLから Storage 内のパスを取り出す
  /// 例: https://xxx.supabase.co/storage/v1/object/public/photos/123.jpg
  ///     → 123.jpg
  String? _storagePathFromUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    final segments = Uri.parse(imageUrl).pathSegments;
    final bucketIndex = segments.indexOf('photos');
    if (bucketIndex < 0 || bucketIndex + 1 >= segments.length) return null;
    return segments.sublist(bucketIndex + 1).join('/');
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('投稿を削除'),
          content: const Text('この思い出を削除しますか？\n写真も一緒に削除されます。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('削除する'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      // 1) Storageの実ファイルを先に消す（失敗したらDBは消さずに中断）
      final storagePath = _storagePathFromUrl(post['image_url'] as String?);
      if (storagePath != null) {
        await supabase.storage.from('photos').remove([storagePath]);
      }

      // 2) DBの行を消す
      await supabase
          .from('posts')
          .delete()
          .eq('id', post['id'])
          .eq('user_id', userId); // 自分の投稿だけ削除できるよう二重に絞る

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('投稿を削除しました')),
      );
      // Streamが自動で再描画する。県の投稿が0件になれば、
      // 地図に戻ったときに色も消える（main.dartで再取得済み）。
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.prefectureName}の思い出')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _postsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('読み込みに失敗しました'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final posts = snapshot.data!;
          if (posts.isEmpty) {
            return const Center(child: Text('まだ思い出がありません。'));
          }

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.account_circle,
                        color: Colors.blue,
                      ),
                      title: Text(
                        post['user_email'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      // ★追加: 編集／削除メニュー
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _editPost(post);
                          } else if (value == 'delete') {
                            _deletePost(post);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit_outlined),
                              title: Text('編集'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              title: Text(
                                '削除',
                                style: TextStyle(color: Colors.red),
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Image.network(
                      post['image_url'],
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(
                          height: 200,
                          child: Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        post['comment'] ?? '',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(hintText: 'コメントを入力...'),
                ),
              ),
              const SizedBox(width: 8),
              _isUploading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _pickAndUpload,
                      icon: const Icon(Icons.upload),
                      label: const Text('写真を選ぶ'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
