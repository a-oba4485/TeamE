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
        'user_email':user.email,
        'prefecture':widget.prefectureName,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.prefectureName}の思い出')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _postsStream,
        builder: (context, snapshot) {
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
                      leading:const Icon(Icons.account_circle,color:Colors.blue),
                      title: Text(
                        post['user_email'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold)
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