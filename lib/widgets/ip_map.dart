import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/ip_info.dart';

/// IP 归属地地图。用 OpenStreetMap 的公共瓦片服务——免费且不需要 API key，
/// 换 Google Maps 要绑信用卡。
class IpMap extends StatelessWidget {
  const IpMap({super.key, required this.info, this.height = 200});

  final IpInfo info;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (!info.hasLocation) {
      return _NoLocation(height: height);
    }

    final point = LatLng(info.latitude, info.longitude);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 9,
                // IP 定位精度本来就只到城市级，让用户随意缩放/拖动
                // 反而会误导人以为这是精确位置。
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  // OSM 的使用条款要求请求带上可识别的 User-Agent
                  userAgentPackageName: 'com.speednetwork.iplookupapp',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.location_on,
                        size: 40,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // ODbL 许可证要求标注数据来源，不能省
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: Colors.white70,
                child: const Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 9, color: Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoLocation extends StatelessWidget {
  const _NoLocation({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined,
                size: 32, color: scheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              '该 IP 没有可用的位置信息',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
