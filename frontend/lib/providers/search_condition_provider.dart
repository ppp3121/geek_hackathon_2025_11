import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

class SearchCondition {
  final LatLng center;
  final double radius;
  final List<String> amenities;

  const SearchCondition({
    required this.center,
    this.radius = 1000.0,
    this.amenities = const ['restaurant', 'cafe', 'convenience'],
  });

  SearchCondition copyWith({
    LatLng? center,
    double? radius,
    List<String>? amenities,
  }) {
    return SearchCondition(
      center: center ?? this.center,
      radius: radius ?? this.radius,
      amenities: amenities ?? this.amenities,
    );
  }
}

class SearchConditionNotifier extends StateNotifier<SearchCondition> {
  SearchConditionNotifier()
      : super(const SearchCondition(
          center: LatLng(35.6762, 139.6503), // 東京駅を初期位置として設定
        ));

  void updateCenter(LatLng newCenter) {
    state = state.copyWith(center: newCenter);
  }

  void updateRadius(double newRadius) {
    state = state.copyWith(radius: newRadius);
  }

  void updateAmenities(List<String> newAmenities) {
    state = state.copyWith(amenities: newAmenities);
  }
}

final searchConditionProvider =
    StateNotifierProvider<SearchConditionNotifier, SearchCondition>((ref) {
  return SearchConditionNotifier();
});