import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

class SearchCondition {
  final LatLng center;
  final double radius;
  final List<String> amenities;
  final String facilityName;

  const SearchCondition({
    required this.center,
    this.radius = 500.0,
    this.amenities = const ['restaurant', 'cafe', 'convenience'],
    this.facilityName = '',
  });

  SearchCondition copyWith({
    LatLng? center,
    double? radius,
    List<String>? amenities,
    String? facilityName,
  }) {
    return SearchCondition(
      center: center ?? this.center,
      radius: radius ?? this.radius,
      amenities: amenities ?? this.amenities,
      facilityName: facilityName ?? this.facilityName,
    );
  }
}

class SearchConditionNotifier extends StateNotifier<SearchCondition> {
  SearchConditionNotifier()
      : super(const SearchCondition(
          center: LatLng(34.960165, 137.071687), // 名古屋市を初期位置として設定
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

  void updateFacilityName(String newFacilityName) {
    state = state.copyWith(facilityName: newFacilityName);
  }
}

final searchConditionProvider =
    StateNotifierProvider<SearchConditionNotifier, SearchCondition>((ref) {
  return SearchConditionNotifier();
});