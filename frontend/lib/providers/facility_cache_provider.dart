import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/facility.dart';
import '../services/facility_service.dart';
import 'search_condition_provider.dart';

class SearchKey {
  final LatLng center;
  final double radius;
  final List<String> amenities;
  final String facilityName;

  const SearchKey({
    required this.center,
    required this.radius,
    required this.amenities,
    required this.facilityName,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchKey &&
        other.center.latitude == center.latitude &&
        other.center.longitude == center.longitude &&
        other.radius == radius &&
        _listEquals(other.amenities, amenities) &&
        other.facilityName == facilityName;
  }

  @override
  int get hashCode {
    return Object.hash(
      center.latitude,
      center.longitude,
      radius,
      amenities.join(','),
      facilityName,
    );
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  double distanceFrom(SearchKey other) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, center, other.center);
  }
}

final searchKeyProvider = Provider<SearchKey>((ref) {
  final condition = ref.watch(searchConditionProvider);
  return SearchKey(
    center: condition.center,
    radius: condition.radius,
    amenities: condition.amenities,
    facilityName: condition.facilityName,
  );
});

final facilityCacheProvider = FutureProvider.family<List<Facility>, SearchKey>(
  (ref, searchKey) async {
    final cacheManager = ref.read(cacheManagerProvider.notifier);
    
    // 新しい検索を実行
    final result = await FacilityService.searchFacilities(
      center: searchKey.center,
      radius: searchKey.radius,
      amenities: searchKey.amenities,
      facilityName: searchKey.facilityName.isNotEmpty ? searchKey.facilityName : null,
    );
    
    // 検索成功後にキャッシュクリア判定を実行
    cacheManager.checkAndInvalidateCache(searchKey);
    
    return result;
  },
);

final currentFacilitiesProvider = FutureProvider<List<Facility>>((ref) {
  final searchKey = ref.watch(searchKeyProvider);
  return ref.watch(facilityCacheProvider(searchKey).future);
});

class CacheManager extends StateNotifier<SearchKey?> {
  CacheManager(this.ref) : super(null);

  final Ref ref;
  SearchKey? _lastKey;

  void checkAndInvalidateCache(SearchKey currentKey) {
    if (_lastKey != null) {
      final distance = currentKey.distanceFrom(_lastKey!);
      
      // 500m以上離れた場合、古いキャッシュを無効化
      if (distance > 500) {
        // 新しい検索が成功したので、古い結果のキャッシュをクリア
        ref.invalidate(facilityCacheProvider(_lastKey!));
      }
    }
    
    _lastKey = currentKey;
    state = currentKey;
  }
}

final cacheManagerProvider = StateNotifierProvider<CacheManager, SearchKey?>((ref) {
  return CacheManager(ref);
});