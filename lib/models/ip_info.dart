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

  factory IpInfo.fromJson(Map<String, dynamic> json) {
    return IpInfo(
      ip: json['query'] ?? json['ip'] ?? 'N/A',
      country: json['country'] ?? 'N/A',
      region: json['regionName'] ?? json['region'] ?? 'N/A',
      city: json['city'] ?? 'N/A',
      latitude: (json['lat'] ?? 0.0).toDouble(),
      longitude: (json['lon'] ?? 0.0).toDouble(),
      isp: json['isp'] ?? json['org'] ?? 'N/A',
      timezone: json['timezone'] ?? 'N/A',
    );
  }
}
