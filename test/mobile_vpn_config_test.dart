import 'package:flutter_test/flutter_test.dart';
import 'package:ip_lookup_app/models/mobile_vpn_config.dart';
import 'package:ip_lookup_app/models/network_node.dart';

Map<String, dynamic> hy2Fixture() => {
      'schema_version': 1,
      'issued_at': 1000,
      'refresh_after': 1300,
      'protocol': 'hysteria2',
      'node': {'id': 7, 'name': 'Fixture HY2'},
      'endpoint': {'address': 'node.example.com', 'port': 443},
      'authentication': {'password': 'fixture-password'},
      'transport': <String, dynamic>{'type': 'quic'},
      'security': <String, dynamic>{
        'type': 'tls',
        'server_name': 'tls.example.com'
      },
    };

void main() {
  test('HY2 has its own authentication and secure TLS default', () {
    final config = MobileVpnConfig.fromJson(hy2Fixture());
    expect(config.protocol, 'hysteria2');
    expect(config.password, 'fixture-password');
    expect(config.userId, isEmpty);
    expect(config.allowInsecure, isFalse);
    expect(config.toPlatformMap()['password'], 'fixture-password');
    expect(config.toPlatformMap()['allow_insecure'], isFalse);
  });

  test('HY2 preserves explicit TLS, obfuscation, hopping and bandwidth', () {
    final json = hy2Fixture();
    json['security']['allow_insecure'] = true;
    json['security']['pinned_peer_cert_sha256'] = 'a' * 64;
    json['transport'].addAll({
      'obfs': {'type': 'salamander', 'password': 'fixture-obfs'},
      'ports': '20000-21000',
      'hop_interval': 20,
      'up_mbps': 10,
      'down_mbps': 100,
    });
    final config = MobileVpnConfig.fromJson(json);
    expect(config.obfsPassword, 'fixture-obfs');
    expect(config.serverPorts, '20000-21000');
    expect(config.hopInterval, 20);
    expect(config.upMbps, 10);
    expect(config.downMbps, 100);
    expect(config.allowInsecure, isTrue);
    expect(config.pinnedPeerCertSha256, 'a' * 64);
  });

  for (final field in [
    'password',
    'ports',
    'obfs',
    'tls',
    'bandwidth',
    'transport',
    'protocol'
  ]) {
    test('reject malformed HY2 $field', () {
      final json = hy2Fixture();
      switch (field) {
        case 'password':
          json['authentication'] = {};
          break;
        case 'ports':
          json['transport']['ports'] = '40000-70000';
          break;
        case 'obfs':
          json['transport']['obfs'] = {'type': 'unknown'};
          break;
        case 'tls':
          json['security']['allow_insecure'] = 'false';
          break;
        case 'bandwidth':
          json['transport']['up_mbps'] = -10;
          break;
        case 'transport':
          json['transport']['type'] = 'raw';
          break;
        case 'protocol':
          json['protocol'] = 'hysteria';
          break;
      }
      expect(() => MobileVpnConfig.fromJson(json), throwsFormatException);
    });
  }

  test('online HY2 aliases are selectable; unsupported/offline nodes are not',
      () {
    for (final type in ['vless', 'hysteria', 'hysteria2', 'hy2']) {
      final node =
          NetworkNode.fromJson({'id': 7, 'type': type, 'available_status': 2});
      expect(node.canConnect, isTrue);
    }
    expect(
        NetworkNode.fromJson({'type': 'tuic', 'available_status': 2})
            .canConnect,
        isFalse);
    expect(
        NetworkNode.fromJson({'type': 'hysteria', 'available_status': 0})
            .canConnect,
        isFalse);
  });
}
