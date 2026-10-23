enum NodeAvailability { online, heartbeat, offline }

class NetworkNode {
  const NetworkNode({
    required this.id,
    required this.name,
    required this.protocol,
    required this.rate,
    required this.availability,
    required this.loadLevel,
    required this.loadEstimated,
    required this.lastCheckAt,
  });

  final String id;
  final String name;
  final String protocol;
  final double rate;
  final NodeAvailability availability;
  final String loadLevel;
  final bool loadEstimated;
  final DateTime? lastCheckAt;

  bool get isOnline => availability == NodeAvailability.online;

  factory NetworkNode.fromJson(Map<String, dynamic> json) {
    final status = _toInt(json['available_status'] ?? json['is_online']);
    final rawType = _text(json['type']);
    return NetworkNode(
      id: _text(json['id']),
      name: _text(json['name']).isEmpty ? '未命名线路' : _text(json['name']),
      protocol: rawType.isEmpty ? '未知' : rawType.toUpperCase(),
      rate: _toDouble(json['rate'], fallback: 1).clamp(0, 100),
      availability: status >= 2
          ? NodeAvailability.online
          : status == 1
              ? NodeAvailability.heartbeat
              : NodeAvailability.offline,
      loadLevel: _normalizeLoad(json['load_level']),
      loadEstimated:
          json['load_estimated'] == true || _toInt(json['load_estimated']) == 1,
      lastCheckAt: _toDateTime(json['last_check_at']),
    );
  }
}

String _normalizeLoad(dynamic value) {
  final text = _text(value).toLowerCase();
  return const {'relaxed', 'moderate', 'busy'}.contains(text)
      ? text
      : 'unknown';
}

DateTime? _toDateTime(dynamic value) {
  final timestamp = _toInt(value);
  if (timestamp <= 0) return null;
  final milliseconds = timestamp > 1000000000000 ? timestamp : timestamp * 1000;
  return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true)
      .toLocal();
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _toDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

String _text(dynamic value) => value?.toString().trim() ?? '';
