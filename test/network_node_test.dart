import 'package:flutter_test/flutter_test.dart';
import 'package:ip_lookup_app/models/network_node.dart';

void main() {
  test('parses safe network node summary', () {
    final node = NetworkNode.fromJson({
      'id': 12,
      'name': '香港线路',
      'type': 'shadowsocks',
      'rate': '1.5',
      'available_status': 2,
      'load_level': 'relaxed',
      'load_estimated': 1,
      'last_check_at': 1761181200,
    });

    expect(node.id, '12');
    expect(node.protocol, 'SHADOWSOCKS');
    expect(node.rate, 1.5);
    expect(node.isOnline, isTrue);
    expect(node.loadEstimated, isTrue);
    expect(node.lastCheckAt, isNotNull);
  });

  test('treats an unavailable node as offline', () {
    final node = NetworkNode.fromJson({
      'id': '7',
      'name': '维护中',
      'type': 'trojan',
      'available_status': 0,
    });

    expect(node.availability, NodeAvailability.offline);
    expect(node.isOnline, isFalse);
    expect(node.rate, 1);
  });
}
