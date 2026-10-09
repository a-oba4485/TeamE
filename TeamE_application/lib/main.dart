import 'package:flutter/material.dart';
import 'package:countries_world_map/countries_world_map.dart';
// import 'package:countries_world_map/data/maps/countries/japan/japan.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '思い出共有アプリ',
      theme: ThemeData(
        // アプリのメインカラーを青系に設定
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}

// ここから下が日本地図を表示する画面のコードです
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('思い出の地を選ぶ'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        // InteractiveViewerで囲むと、地図を指で拡大縮小（ピンチ）できるようになります！
        child: InteractiveViewer(
          child: SimpleMap(
            // 日本地図のデータを指定
            instructions: SMapJapan.instructions,
            
            // 地図の基本の色
            defaultColor: Colors.grey.shade50,
            countryBorder: CountryBorder(color: Colors.black),
            // 思い出が登録されている県（例）だけ色を変える
            colors: const {
              "JP-40": Colors.blue,   // 福岡県
              "JP-13": Colors.orange,
              "JP-1":Colors.red,// 東京都
              "JP-01":Colors.orange // 東京都
            },
            
            // タップされた時の処理
            callback: (id, name, tapDetails) {
              // VS Codeの「デバッグコンソール」にタップした県名が表示されます
              print("$name ($id) がタップされました！");
              
              // ※将来的に、ここに「〇〇県のアルバム画面へ移動する」コードを書きます
            },
          ),
        ),
      ),
    );
  }
}