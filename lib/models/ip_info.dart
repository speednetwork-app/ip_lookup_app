class IpInfo {
  final String ip;
  final String country;
  final String region;
  final String city;
  final double latitude;
  final double longitude;
  final String isp;
  final String timezone;

  IpInfo({
    required this.ip,
    required this.country,
    required this.region,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.isp,
    required this.timezone,
  });

  /// 兼容 ipwho.is、ipapi.co 两种接口响应，以及 [toJson] 写出的本地存储格式。
  /// ipwho.is 把 isp/timezone 放在嵌套对象里，另外两种是平铺字段。
  factory IpInfo.fromJson(Map<String, dynamic> json) {
    final connection = json['connection'];
    final timezone = json['timezone'];

    return IpInfo(
      ip: _str(json['ip']),
      country: _str(json['country'] ?? json['country_name']),
      region: _str(json['region'] ?? json['region_name']),
      city: _str(json['city']),
      latitude: _num(json['latitude']),
      longitude: _num(json['longitude']),
      isp: _str(
        connection is Map
            ? (connection['isp'] ?? connection['org'])
            : (json['isp'] ?? json['org']),
      ),
      timezone: _str(
        timezone is Map ? timezone['id'] : timezone,
      ),
    );
  }

  /// 扁平化成本地存储用的格式，[fromJson] 可以原样读回。
  Map<String, dynamic> toJson() => {
        'ip': ip,
        'country': country,
        'region': region,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
        'isp': isp,
        'timezone': timezone,
      };

  /// 接口偶尔会缺坐标，此时不该在地图上把它标到几内亚湾（0,0）去。
  bool get hasLocation => latitude != 0.0 || longitude != 0.0;

  /// 「城市, 地区, 国家」，自动跳过缺失的层级。
  String get location {
    final parts = [city, region, country]
        .where((p) => p != 'N/A' && p.isNotEmpty)
        .toSet(); // 香港这类城市=地区=国家的地方会重复，去重
    return parts.isEmpty ? 'N/A' : parts.join(', ');
  }

  static String _str(dynamic value) {
    if (value == null) return 'N/A';
    final text = value.toString().trim();
    return text.isEmpty ? 'N/A' : text;
  }

  static double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
