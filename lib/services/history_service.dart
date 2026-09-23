import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/history_entry.dart';

/// 查询历史的本地持久化。只存在设备上，不上传任何地方。
class HistoryService {
  static const _key = 'query_history';

  /// 超过这个数量就丢掉最旧的——历史是给人翻的，不是日志，
  /// 无上限增长只会拖慢启动读取。
  static const maxEntries = 50;

  Future<List<HistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);
    if (raw == null) return [];

    return raw
        .map((line) {
          try {
            final decoded = jsonDecode(line);
            return decoded is Map<String, dynamic>
                ? HistoryEntry.fromJson(decoded)
                : null;
          } catch (_) {
            // 单条数据损坏不该让整个历史读不出来，跳过即可
            return null;
          }
        })
        .whereType<HistoryEntry>()
        .toList();
  }

  Future<void> save(List<HistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      entries.take(maxEntries).map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
