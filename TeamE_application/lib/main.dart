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
    // 地方ごとの都道府県一覧
  final Map<String, List<String>> _regions = {
    '北海道地方': ['北海道'],
    '東北地方': [
      '青森県', '岩手県', '宮城県',
      '秋田県', '山形県', '福島県',
    ],
    '関東地方': [
      '茨城県', '栃木県', '群馬県',
      '埼玉県', '千葉県', '東京都', '神奈川県',
    ],
    '中部地方': [
      '新潟県', '富山県', '石川県',
      '福井県', '山梨県', '長野県',
      '岐阜県', '静岡県', '愛知県',
    ],
    '近畿地方': [
      '三重県', '滋賀県', '京都府',
      '大阪府', '兵庫県', '奈良県', '和歌山県',
    ],
    '中国地方': [
      '鳥取県', '島根県', '岡山県',
      '広島県', '山口県',
    ],
    '四国地方': [
      '徳島県', '香川県', '愛媛県', '高知県',
    ],
    '九州地方': [
      '福岡県', '佐賀県', '長崎県',
      '熊本県', '大分県', '宮崎県', '鹿児島県', '沖縄県',
    ],
  };
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

    // 都道府県を選択して写真画面へ移動
  Future<void> _openPrefecture(String prefectureName) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrefectureTimelinePage(
          prefectureName: prefectureName,
        ),
      ),
    );

    if (!mounted) return;

    // 写真画面から戻ったら地図の色を更新
    _fetchActivePrefectures();
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
        automaticallyImplyLeading: false,
      ),
      drawer: Drawer(
        width: 300,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFFFFB4A8),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  '地方・都道府県を選択',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            ..._regions.entries.expand((region) {
              return [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    region.key,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD84A38),
                    ),
                  ),
                ),

                ...region.value.map((prefecture) {
                  return ListTile(
                    dense: true,
                    title: Text(prefecture),
                    leading: const Icon(
                      Icons.location_on_outlined,
                      size: 20,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _openPrefecture(prefecture);
                    },
                  );
                }),
              ];
            }),
          ],
        ),
      ),
      body: Stack(
  children: [
    // 既存の日本地図
    Center(
      child: InteractiveViewer(
        child: SimpleMap(
          key: ValueKey(_mapColors.toString()),
          instructions: SMapJapan.instructions,
          defaultColor: Colors.grey.shade50,
          countryBorder: const CountryBorder(
            color: Colors.black,
          ),
          colors: _mapColors,
          callback: (id, name, tapDetails) async {
  final lowerId = id.toLowerCase();
  final japaneseName = _idToPrefName[lowerId] ?? '不明な地域';

  if (japaneseName == '不明な地域') return;

  await _openPrefecture(japaneseName);
},
        ),
      ),
    ),

    // 左下のハンバーガーメニュー
    Positioned(
      left: 20,
      bottom: 20,
      child: Builder(
        builder: (context) => FloatingActionButton(
          heroTag: 'regionMenu',
          backgroundColor: const Color(0xFFFFB4A8),
          foregroundColor: Colors.black87,
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
          child: const Icon(Icons.menu),
        ),
      ),
    ),
  ],
),
    );
  }

}