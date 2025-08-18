import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../providers/search_condition_provider.dart';

class MapWidget extends ConsumerStatefulWidget {
  const MapWidget({super.key});

  @override
  ConsumerState<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends ConsumerState<MapWidget> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final searchCondition = ref.watch(searchConditionProvider);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: searchCondition.center,
        initialZoom: 15.0,
        onPositionChanged: (MapCamera position, bool hasGesture) {
          if (hasGesture) {
            // ユーザーの操作による位置変更の場合のみ、検索条件を更新
            ref
                .read(searchConditionProvider.notifier)
                .updateCenter(position.center);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.frontend',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: searchCondition.center,
              width: 40,
              height: 40,
              child: const Icon(
                Icons.location_pin,
                color: Colors.red,
                size: 40,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}