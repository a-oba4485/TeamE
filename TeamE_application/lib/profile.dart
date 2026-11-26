import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// プロフィール（表示名・自分の色）の共通ヘルパー
// profiles テーブル：user_id (uuid, PK) / display_name (text) / map_color (text '#RRGGBB')
// 使い方：
//   1. Supabase ダッシュボードの SQL Editor で supabase-sharing-profiles.sql を実行する。
//   2. このファイルを lib/profile.dart として追加する（main.dart / mypage.dart /
//      group.dart が import する）。
// profiles に行が無いユーザーは「表示名なし・色はデフォルト」として扱う。
// 行はマイページで初めて保存したときに upsert で作られる。

/// デフォルトの地図色（従来のテーマ赤）
const String kDefaultMapColorHex = '#D84A38';

/// 色ピッカーに出すプリセット（'#RRGGBB'）
const List<String> kMapColorPalette = [
  '#D84A38', // 赤（デフォルト）
  '#E8862D', // オレンジ
  '#D9A404', // 黄
  '#4C9F70', // 緑
  '#2D9CDB', // 水色
  '#2F5FD0', // 青
  '#7B61C9', // 紫
  '#D45D9E', // ピンク
  '#8A6D4B', // 茶
  '#595959', // グレー
];

/// '#RRGGBB' を Color に変換する。不正な値ならデフォルト色を返す。
Color colorFromHex(String? hex) {
  final cleaned = (hex ?? '').replaceAll('#', '');
  final value = int.tryParse(cleaned, radix: 16);
  if (cleaned.length != 6 || value == null) {
    return const Color(0xFFD84A38);
  }
  return Color(0xFF000000 | value);
}

/// 指定ユーザーの profiles 行を1件取る（無ければ null）
Future<Map<String, dynamic>?> fetchProfile(String userId) async {
  return Supabase.instance.client
      .from('profiles')
      .select('user_id, display_name, map_color')
      .eq('user_id', userId)
      .maybeSingle();
}

/// 複数ユーザーの profiles を user_id → 行 のマップで取る（グループ表示用）
Future<Map<String, Map<String, dynamic>>> fetchProfiles(
  List<String> userIds,
) async {
  if (userIds.isEmpty) return {};
  final data = await Supabase.instance.client
      .from('profiles')
      .select('user_id, display_name, map_color')
      .inFilter('user_id', userIds);
  final result = <String, Map<String, dynamic>>{};
  for (final row in data) {
    final map = Map<String, dynamic>.from(row as Map);
    result[map['user_id'] as String] = map;
  }
  return result;
}

/// profiles 行から表示名を取り出す（未設定・空なら null）
String? displayNameOf(Map<String, dynamic>? profile) {
  final name = profile?['display_name'] as String?;
  if (name == null || name.trim().isEmpty) return null;
  return name.trim();
}

/// profiles 行から地図色を取り出す（無ければデフォルト色）
Color mapColorOf(Map<String, dynamic>? profile) {
  return colorFromHex(profile?['map_color'] as String?);
}
