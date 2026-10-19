enum TrafficRange {
  sevenDays('7d', 7, '7 天'),
  thirtyDays('30d', 30, '30 天');

  const TrafficRange(this.apiValue, this.days, this.label);

  final String apiValue;
  final int days;
  final String label;

  static TrafficRange fromApiValue(dynamic value) =>
      value == '30d' ? TrafficRange.thirtyDays : TrafficRange.sevenDays;
}

class DailyTraffic {
  const DailyTraffic({
    required this.date,
    required this.uploadBytes,
    required this.downloadBytes,
    required this.totalBytes,
  });

  final DateTime date;
  final int uploadBytes;
  final int downloadBytes;
  final int totalBytes;

  factory DailyTraffic.fromJson(Map<String, dynamic> json) {
    final upload = _nonNegativeInt(json['upload_bytes']);
    final download = _nonNegativeInt(json['download_bytes']);
    return DailyTraffic(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      uploadBytes: upload,
      downloadBytes: download,
      totalBytes: _nonNegativeInt(json['total_bytes'] ?? upload + download),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': _dateText(date),
        'upload_bytes': uploadBytes,
        'download_bytes': downloadBytes,
        'total_bytes': totalBytes,
      };
}

class TrafficTrend {
  const TrafficTrend({
    required this.range,
    required this.periodStart,
    required this.periodEnd,
    required this.uploadBytes,
    required this.downloadBytes,
    required this.usedBytes,
    required this.averageDailyBytes,
    required this.updatedAt,
    required this.daily,
  });

  final TrafficRange range;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final int uploadBytes;
  final int downloadBytes;
  final int usedBytes;
  final int averageDailyBytes;
  final DateTime? updatedAt;
  final List<DailyTraffic> daily;

  int get todayBytes => daily.isEmpty ? 0 : daily.last.totalBytes;

  factory TrafficTrend.fromJson(Map<String, dynamic> json) {
    final rawDaily = json['daily'];
    final daily = rawDaily is List
        ? rawDaily
            .whereType<Map>()
            .map((item) => DailyTraffic.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .toList(growable: false)
        : const <DailyTraffic>[];
    return TrafficTrend(
      range: TrafficRange.fromApiValue(json['range']),
      periodStart: _date(json['period_start']),
      periodEnd: _date(json['period_end']),
      uploadBytes: _nonNegativeInt(json['upload_bytes']),
      downloadBytes: _nonNegativeInt(json['download_bytes']),
      usedBytes: _nonNegativeInt(json['used_bytes']),
      averageDailyBytes: _nonNegativeInt(json['average_daily_bytes']),
      updatedAt: _dateTime(json['updated_at']),
      daily: daily,
    );
  }

  Map<String, dynamic> toJson() => {
        'range': range.apiValue,
        'period_start': periodStart == null ? null : _dateText(periodStart!),
        'period_end': periodEnd == null ? null : _dateText(periodEnd!),
        'upload_bytes': uploadBytes,
        'download_bytes': downloadBytes,
        'used_bytes': usedBytes,
        'average_daily_bytes': averageDailyBytes,
        'updated_at': updatedAt?.toUtc().millisecondsSinceEpoch == null
            ? null
            : updatedAt!.toUtc().millisecondsSinceEpoch ~/ 1000,
        'daily': daily.map((item) => item.toJson()).toList(growable: false),
      };
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

DateTime? _dateTime(dynamic value) {
  if (value == null) return null;
  if (value is num || int.tryParse(value.toString()) != null) {
    final seconds = value is num ? value.toInt() : int.parse(value.toString());
    if (seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true)
        .toLocal();
  }
  return DateTime.tryParse(value.toString())?.toLocal();
}

int _nonNegativeInt(dynamic value) {
  final number =
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
  return number < 0 ? 0 : number;
}

String _dateText(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
