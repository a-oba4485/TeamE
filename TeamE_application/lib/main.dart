import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:countries_world_map/countries_world_map.dart';

import 'auth_gate.dart';
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
      debugShowCheckedModeBanner: false,
      title: '思い出共有アプリ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD84A38)),
        scaffoldBackgroundColor: const Color(0xFFFAF9F6),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

// 統合されたメインの地図画面
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});


  @override
  State<MapScreen> createState() => _MapScreenState();
}
class _MapScreenState extends State<MapScreen> {
  final supabase = Supabase.instance.client;
  
  Map<String, Color> _mapColors = {};

  // 英語のIDと日本語の県名の変換辞書
  final Map<String, String> _prefNameToId = {
    '北海道': 'jp-01', '青森県': 'jp-02', '岩手県': 'jp-03', '宮城県': 'jp-04',
    '秋田県': 'jp-05', '山形県': 'jp-06', '福島県': 'jp-07', '茨城県': 'jp-08',
    '栃木県': 'jp-09', '群馬県': 'jp-10', '埼玉県': 'jp-11', '千葉県': 'jp-12',
    '東京都': 'jp-13', '神奈川県': 'jp-14', '新潟県': 'jp-15', '富山県': 'jp-16',
    '石川県': 'jp-17', '福井県': 'jp-18', '山梨県': 'jp-19', '長野県': 'jp-20',
    '岐阜県': 'jp-21', '静岡県': 'jp-22', '愛知県': 'jp-23', '三重県': 'jp-24',
    '滋賀県': 'jp-25', '京都府': 'jp-26', '大阪府': 'jp-27', '兵庫県': 'jp-28',
    '奈良県': 'jp-29', '和歌山県': 'jp-30', '鳥取県': 'jp-31', '島根県': 'jp-32',
    '岡山県': 'jp-33', '広島県': 'jp-34', '山口県': 'jp-35', '徳島県': 'jp-36',
    '香川県': 'jp-37', '愛媛県': 'jp-38', '高知県': 'jp-39', '福岡県': 'jp-40',
    '佐賀県': 'jp-41', '長崎県': 'jp-42', '熊本県': 'jp-43', '大分県': 'jp-44',
    '宮崎県': 'jp-45', '鹿児島県': 'jp-46', '沖縄県': 'jp-47',
  };

  // ★追加：ID（jp-40）から日本語（福岡県）に翻訳する「逆引き辞書」を自動作成
  late final Map<String, String> _idToPrefName = 
      _prefNameToId.map((key, value) => MapEntry(value, key));

  @override
  void initState() {
    super.initState();
    _fetchActivePrefectures(); 
  }

  Future<void> _fetchActivePrefectures() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final data = await supabase
          .from('posts')
          .select('prefecture')
          .eq('user_id', userId);

      Map<String, Color> newColors = {};
      
      for (var row in data) {
        final prefName = row['prefecture'] as String?;
        if (prefName != null && _prefNameToId.containsKey(prefName)) {
          final id = _prefNameToId[prefName]!.toUpperCase();
          newColors[id] = const Color(0xFFD84A38);
        }
      }

      setState(() {
        _mapColors = newColors;
      });
    } catch (e) {
      debugPrint('色付けエラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('思い出の地を選ぶ'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: SimpleMap(
            key: ValueKey(_mapColors.toString()), 
            instructions: SMapJapan.instructions,
            defaultColor: Colors.grey.shade50,
            countryBorder: const CountryBorder(color: Colors.black),
            colors: _mapColors, 
            callback: (id, name, tapDetails) async {
              // ★ここが超重要！
              // マップから来たID（例: jp-40）を小文字に揃えて、逆引き辞書で「福岡県」に翻訳する
              final lowerId = id.toLowerCase();
              final japaneseName = _idToPrefName[lowerId] ?? '不明な地域';

              // 英語の name ではなく、翻訳した japaneseName を次の画面へ渡す
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PrefectureTimelinePage(prefectureName: japaneseName),
                ),
              );
              _fetchActivePrefectures();
            },
          ),
        ),
      ),
    );
  }
}