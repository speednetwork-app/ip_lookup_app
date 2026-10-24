class MobileVpnConfig {
  const MobileVpnConfig({
    required this.schemaVersion,
    required this.issuedAt,
    required this.refreshAfter,
    required this.protocol,
    required this.nodeId,
    required this.nodeName,
    required this.address,
    required this.port,
    required this.userId,
    required this.encryption,
    required this.flow,
    required this.transportType,
    required this.securityType,
    required this.serverName,
    required this.publicKey,
    required this.shortId,
    required this.fingerprint,
    required this.spiderX,
  });

  factory MobileVpnConfig.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _requiredInt(json, 'schema_version');
    if (schemaVersion != 1) {
      throw FormatException('Unsupported VPN config schema: $schemaVersion');
    }

    final node = _requiredMap(json, 'node');
    final endpoint = _requiredMap(json, 'endpoint');
    final authentication = _requiredMap(json, 'authentication');
    final transport = _requiredMap(json, 'transport');
    final security = _requiredMap(json, 'security');

    final protocol = _requiredString(json, 'protocol');
    final transportType = _requiredString(transport, 'type');
    final securityType = _requiredString(security, 'type');
    if (protocol != 'vless' ||
        transportType != 'raw' ||
        securityType != 'reality') {
      throw const FormatException('Unsupported VPN node configuration');
    }

    final port = _requiredInt(endpoint, 'port');
    if (port < 1 || port > 65535) {
      throw const FormatException('Invalid VPN endpoint port');
    }

    return MobileVpnConfig(
      schemaVersion: schemaVersion,
      issuedAt: DateTime.fromMillisecondsSinceEpoch(
        _requiredInt(json, 'issued_at') * 1000,
        isUtc: true,
      ),
      refreshAfter: DateTime.fromMillisecondsSinceEpoch(
        _requiredInt(json, 'refresh_after') * 1000,
        isUtc: true,
      ),
      protocol: protocol,
      nodeId: _requiredInt(node, 'id'),
      nodeName: _requiredString(node, 'name'),
      address: _requiredString(endpoint, 'address'),
      port: port,
      userId: _requiredString(authentication, 'id'),
      encryption: _requiredString(authentication, 'encryption'),
      flow: _requiredString(authentication, 'flow'),
      transportType: transportType,
      securityType: securityType,
      serverName: _requiredString(security, 'server_name'),
      publicKey: _requiredString(security, 'public_key'),
      shortId: _string(security, 'short_id'),
      fingerprint: _requiredString(security, 'fingerprint'),
      spiderX: _requiredString(security, 'spider_x'),
    );
  }

  final int schemaVersion;
  final DateTime issuedAt;
  final DateTime refreshAfter;
  final String protocol;
  final int nodeId;
  final String nodeName;
  final String address;
  final int port;
  final String userId;
  final String encryption;
  final String flow;
  final String transportType;
  final String securityType;
  final String serverName;
  final String publicKey;
  final String shortId;
  final String fingerprint;
  final String spiderX;
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Missing VPN config object: $key');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _string(json, key);
  if (value.isEmpty) throw FormatException('Missing VPN config field: $key');
  return value;
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is String ? value.trim() : '';
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw FormatException('Missing VPN config number: $key');
}
