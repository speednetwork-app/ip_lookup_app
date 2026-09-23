import 'package:flutter/foundation.dart';

import '../models/history_entry.dart';
import '../models/ip_info.dart';
import '../services/history_service.dart';

class HistoryProvider with ChangeNotifier {
  HistoryProvider({HistoryService? service})
      : _service = service ?? HistoryService();

  final HistoryService _service;

  List<HistoryEntry> _entries = [];
  bool _loaded = false;

  List<HistoryEntry> get entries => List.unmodifiable(_entries);
  bool get isLoaded => _loaded;
  bool get isEmpty => _loaded && _entries.isEmpty;

  Future<void> load() async {
    _entries = await _service.load();
    _loaded = true;
    notifyListeners();
  }

  /// 记录一次查询。同一个 IP 只保留最近一次，避免反复查同一个地址
  /// 就把历史刷满。
  Future<void> add(IpInfo info) async {
    _entries.removeWhere((e) => e.info.ip == info.ip);
    _entries.insert(0, HistoryEntry(info: info, queriedAt: DateTime.now()));
    if (_entries.length > HistoryService.maxEntries) {
      _entries = _entries.sublist(0, HistoryService.maxEntries);
    }
    notifyListeners();
    await _service.save(_entries);
  }

  Future<void> remove(String ip) async {
    _entries.removeWhere((e) => e.info.ip == ip);
    notifyListeners();
    await _service.save(_entries);
  }

  Future<void> clear() async {
    _entries = [];
    notifyListeners();
    await _service.clear();
  }
}
