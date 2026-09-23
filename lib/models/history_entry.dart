import 'ip_info.dart';

/// 一条查询历史。[queriedAt] 用本地时区，只用于展示。
class HistoryEntry {
  HistoryEntry({required this.info, required this.queriedAt});

  final IpInfo info;
  final DateTime queriedAt;

  Map<String, dynamic> toJson() => {
        'info': info.toJson(),
        'queriedAt': queriedAt.toIso8601String(),
      };

  static HistoryEntry? fromJson(Map<String, dynamic> json) {
    final info = json['info'];
    final at = DateTime.tryParse(json['queriedAt']?.toString() ?? '');
    if (info is! Map<String, dynamic> || at == null) return null;
    return HistoryEntry(info: IpInfo.fromJson(info), queriedAt: at);
  }
}
