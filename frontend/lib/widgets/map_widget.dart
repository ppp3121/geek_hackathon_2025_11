import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../providers/search_condition_provider.dart';
import '../providers/facility_cache_provider.dart';
import '../models/facility.dart';
import '../utils/map_tiles.dart';

class MapWidget extends ConsumerStatefulWidget {
  final Function(String facilityId)? onFacilityTapped;

  const MapWidget({super.key, this.onFacilityTapped});

  @override
  ConsumerState<MapWidget> createState() => MapWidgetState();
}

extension MapWidgetExtension on GlobalKey<MapWidgetState> {
  void focusOnFacility(Facility facility) {
    currentState?.focusOnFacility(facility);
  }
}

class MapWidgetState extends ConsumerState<MapWidget> {
  final MapController _mapController = MapController();
  List<Facility> _lastFacilities = [];
  String? _highlightedFacilityId;

  void focusOnFacility(Facility facility) {
    setState(() {
      _highlightedFacilityId = facility.id.toString();
    });

    // カスタムアニメーションで滑らかに移動
    _animateToLocation(LatLng(facility.lat, facility.lon), 17.0);

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _highlightedFacilityId = null;
        });
      }
    });
  }

  void _animateToLocation(LatLng target, double targetZoom) {
    final currentCenter = _mapController.camera.center;
    final currentZoom = _mapController.camera.zoom;
    
    const duration = Duration(milliseconds: 1000);
    const steps = 30;
    const stepDuration = Duration(milliseconds: 33); // 30fps相当

    for (int i = 1; i <= steps; i++) {
      final progress = i / steps;
      final easedProgress = Curves.easeInOut.transform(progress);
      
      final lat = currentCenter.latitude + 
          (target.latitude - currentCenter.latitude) * easedProgress;
      final lng = currentCenter.longitude + 
          (target.longitude - currentCenter.longitude) * easedProgress;
      final zoom = currentZoom + 
          (targetZoom - currentZoom) * easedProgress;

      Future.delayed(stepDuration * i, () {
        if (mounted) {
          _mapController.move(LatLng(lat, lng), zoom);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchCondition = ref.watch(searchConditionProvider);
    final facilitiesAsync = ref.watch(currentFacilitiesProvider);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: searchCondition.center,
        initialZoom: 15.0,
        onTap: (TapPosition tapPosition, LatLng point) {
          // タップした位置を検索中心として設定
          ref.read(searchConditionProvider.notifier).updateCenter(point);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: MapTiles.current,
          subdomains: MapTiles.subdomains,
          userAgentPackageName: 'com.example.frontend',
        ),
        MarkerLayer(
          markers: [
            // 検索中心位置のマーカー
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
            // 検索結果の施設マーカー
            ...facilitiesAsync.when(
              data: (facilities) {
                // 新しい検索結果が得られたら保存
                _lastFacilities = facilities;
                return facilities
                    .map(
                      (facility) => Marker(
                        point: LatLng(facility.lat, facility.lon),
                        width: 30,
                        height: 30,
                        child: GestureDetector(
                          onTap: () {
                            if (widget.onFacilityTapped != null) {
                              widget.onFacilityTapped!(facility.id.toString());
                            } else {
                              _showFacilityInfo(context, facility);
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _getCategoryColor(facility.category),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _highlightedFacilityId == facility.id.toString()
                                    ? Colors.yellow
                                    : Colors.white,
                                width: _highlightedFacilityId == facility.id.toString() ? 4 : 2,
                              ),
                            ),
                            child: Icon(
                              _getCategoryIcon(facility.category),
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList();
              },
              loading: () {
                // 読み込み中は前回の結果を表示
                return _lastFacilities
                    .map(
                      (facility) => Marker(
                        point: LatLng(facility.lat, facility.lon),
                        width: 30,
                        height: 30,
                        child: GestureDetector(
                          onTap: () {
                            if (widget.onFacilityTapped != null) {
                              widget.onFacilityTapped!(facility.id.toString());
                            } else {
                              _showFacilityInfo(context, facility);
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _getCategoryColor(
                                facility.category,
                              ).withOpacity(0.7),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              _getCategoryIcon(facility.category),
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList();
              },
              error: (_, __) {
                // エラー時も前回の結果を表示
                return _lastFacilities
                    .map(
                      (facility) => Marker(
                        point: LatLng(facility.lat, facility.lon),
                        width: 30,
                        height: 30,
                        child: GestureDetector(
                          onTap: () {
                            if (widget.onFacilityTapped != null) {
                              widget.onFacilityTapped!(facility.id.toString());
                            } else {
                              _showFacilityInfo(context, facility);
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _getCategoryColor(facility.category),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _highlightedFacilityId == facility.id.toString()
                                    ? Colors.yellow
                                    : Colors.white,
                                width: _highlightedFacilityId == facility.id.toString() ? 4 : 2,
                              ),
                            ),
                            child: Icon(
                              _getCategoryIcon(facility.category),
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList();
              },
            ),
          ],
        ),
      ],
    );
  }

  void _showFacilityInfo(BuildContext context, Facility facility) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                facility.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('カテゴリ: ${_getCategoryDisplayName(facility.category)}'),
              const SizedBox(height: 4),
              Text('緯度: ${facility.lat.toStringAsFixed(6)}'),
              const SizedBox(height: 4),
              Text('経度: ${facility.lon.toStringAsFixed(6)}'),
            ],
          ),
        );
      },
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'restaurant':
        return Colors.orange;
      case 'cafe':
        return Colors.brown;
      case 'convenience':
        return Colors.green;
      case 'hospital':
        return Colors.red;
      case 'pharmacy':
        return Colors.pink;
      case 'bank':
        return Colors.blue;
      case 'atm':
        return Colors.lightBlue;
      case 'gas_station':
        return Colors.purple;
      case 'parking':
        return Colors.grey;
      case 'school':
        return Colors.indigo;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'restaurant':
        return Icons.restaurant;
      case 'cafe':
        return Icons.local_cafe;
      case 'convenience':
        return Icons.store;
      case 'hospital':
        return Icons.local_hospital;
      case 'pharmacy':
        return Icons.local_pharmacy;
      case 'bank':
        return Icons.account_balance;
      case 'atm':
        return Icons.atm;
      case 'gas_station':
        return Icons.local_gas_station;
      case 'parking':
        return Icons.local_parking;
      case 'school':
        return Icons.school;
      default:
        return Icons.place;
    }
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'restaurant':
        return 'レストラン';
      case 'cafe':
        return 'カフェ';
      case 'convenience':
        return 'コンビニ';
      case 'hospital':
        return '病院';
      case 'pharmacy':
        return '薬局';
      case 'bank':
        return '銀行';
      case 'atm':
        return 'ATM';
      case 'gas_station':
        return 'ガソリンスタンド';
      case 'parking':
        return '駐車場';
      case 'school':
        return '学校';
      default:
        return category;
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
