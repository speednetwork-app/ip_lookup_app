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

  /// 兼容 ipwho.is 与 ipapi.co 两种响应格式。
  /// ipwho.is 把 isp/timezone 放在嵌套对象里，ipapi.co 是平铺字段。
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
        connection is Map ? (connection['isp'] ?? connection['org']) : json['org'],
      ),
      timezone: _str(
        timezone is Map ? timezone['id'] : timezone,
      ),
    );
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
