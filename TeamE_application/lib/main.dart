import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:countries_world_map/countries_world_map.dart';

import 'login_page.dart';
// 3枚目のファイル名を 'prefecture_timeline_page.dart' とした場合のインポート
import 'prefecture_timeline_page.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://rrobtjgxsjkpirquaxrq.supabase.co',
    publishableKey: 'sb_publishable_4d8Iwa0SLDhMsmpUnuf73w_OVXa0aIJ',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '思い出共有アプリ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

// 統合されたメインの地図画面
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('思い出の地を選ぶ'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // ご指定のログアウト処理をそのまま使用
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: SimpleMap(
            instructions: SMapJapan.instructions,
            defaultColor: Colors.grey.shade50,
            countryBorder: const CountryBorder(color: Colors.black),
            colors: const {
              "JP-40": Colors.blue,
              "JP-13": Colors.orange,
              "JP-1": Colors.red,
              "JP-01": Colors.orange,
            },
            callback: (id, name, tapDetails) {
              // 県をタップしたら投稿画面へ移動する（繋がりを持たせる）
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      PrefectureTimelinePage(prefectureName: name),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}