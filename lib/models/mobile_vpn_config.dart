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
    this.password = '',
    this.allowInsecure = false,
    this.pinnedPeerCertSha256 = '',
    this.obfsPassword = '',
    this.serverPorts = '',
    this.hopInterval = 30,
    this.upMbps = 0,
    this.downMbps = 0,
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
    final isVless = protocol == 'vless' &&
        transportType == 'raw' &&
        securityType == 'reality';
    final isHy2 = protocol == 'hysteria2' &&
        transportType == 'quic' &&
        securityType == 'tls';
    if (!isVless && !isHy2) {
      throw const FormatException('Unsupported VPN node configuration');
    }

    final port = _requiredInt(endpoint, 'port');
    if (port < 1 || port > 65535) {
      throw const FormatException('Invalid VPN endpoint port');
    }

    final obfs = transport['obfs'];
    var obfsPassword = '';
    if (isHy2 && obfs != null) {
      if (obfs is! Map ||
          obfs['type'] != 'salamander' ||
          obfs['password'] is! String ||
          (obfs['password'] as String).isEmpty) {
        throw const FormatException('Unsupported HY2 obfuscation');
      }
      obfsPassword = obfs['password'] as String;
    }
    final ports = isHy2 ? _string(transport, 'ports') : '';
    if (ports.isNotEmpty) {
      final parts = ports.split('-');
      final first = int.tryParse(parts.first);
      final last = int.tryParse(parts.last);
      if (parts.length != 2 ||
          first == null ||
          last == null ||
          first < 1 ||
          last > 65535 ||
          first > last) {
        throw const FormatException('Invalid HY2 port range');
      }
    }
    final interval = isHy2 ? (transport['hop_interval'] ?? 30) : 30;
    if (interval is! int || interval < 5 || interval > 3600) {
      throw const FormatException('Invalid HY2 hop interval');
    }
    final insecure = security['allow_insecure'] ?? false;
    if (isHy2 && insecure is! bool) {
      throw const FormatException('Invalid HY2 TLS verification setting');
    }
    final pin = isHy2 ? _string(security, 'pinned_peer_cert_sha256') : '';
    if ((pin.isNotEmpty && !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(pin)) ||
        (isHy2 && insecure == true && pin.isEmpty)) {
      throw const FormatException(
          'HY2 certificate verification is not configured');
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
      userId: isVless ? _requiredString(authentication, 'id') : '',
      encryption: isVless ? _requiredString(authentication, 'encryption') : '',
      flow: isVless ? _requiredString(authentication, 'flow') : '',
      transportType: transportType,
      securityType: securityType,
      serverName: _requiredString(security, 'server_name'),
      publicKey: isVless ? _requiredString(security, 'public_key') : '',
      shortId: _string(security, 'short_id'),
      fingerprint: isVless ? _requiredString(security, 'fingerprint') : '',
      spiderX: isVless ? _requiredString(security, 'spider_x') : '',
      password: isHy2 ? _requiredString(authentication, 'password') : '',
      allowInsecure: isHy2 && insecure == true,
      pinnedPeerCertSha256: pin,
      obfsPassword: obfsPassword,
      serverPorts: ports,
      hopInterval: interval,
      upMbps: isHy2 ? _bandwidth(transport, 'up_mbps') : 0,
      downMbps: isHy2 ? _bandwidth(transport, 'down_mbps') : 0,
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
  final String password;
  final bool allowInsecure;
  final String pinnedPeerCertSha256;
  final String obfsPassword;
  final String serverPorts;
  final int hopInterval;
  final int upMbps;
  final int downMbps;

  Map<String, Object> toPlatformMap() => {
        'schema_version': schemaVersion,
        'protocol': protocol,
        'node_id': nodeId,
        'node_name': nodeName,
        'address': address,
        'port': port,
        'user_id': userId,
        'encryption': encryption,
        'flow': flow,
        'transport': transportType,
        'security': securityType,
        'server_name': serverName,
        'public_key': publicKey,
        'short_id': shortId,
        'fingerprint': fingerprint,
        'spider_x': spiderX,
        if (protocol == 'hysteria2') ...{
          'password': password,
          'allow_insecure': allowInsecure,
          'pinned_peer_cert_sha256': pinnedPeerCertSha256,
          'obfs_password': obfsPassword,
          'server_ports': serverPorts,
          'hop_interval': hopInterval,
          'up_mbps': upMbps,
          'down_mbps': downMbps,
        },
      };
}

int _bandwidth(Map<String, dynamic> json, String key) {
  final value = json[key] ?? 0;
  if (value is! int || value < 0 || value > 1000000) {
    throw const FormatException('Invalid HY2 bandwidth');
  }
  return value;
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
