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
    
    // 距離順にソート（距離がnullの場合は最後に配置）
    result.sort((a, b) {
      if (a.distance == null && b.distance == null) return 0;
      if (a.distance == null) return 1;
      if (b.distance == null) return -1;
      return a.distance!.compareTo(b.distance!);
    });
    
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

// カテゴリ別のキャッシュキー
class CategorySearchKey {
  final LatLng center;
  final double radius;
  final String category;
  final String facilityName;

  const CategorySearchKey({
    required this.center,
    required this.radius,
    required this.category,
    required this.facilityName,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategorySearchKey &&
        other.center.latitude == center.latitude &&
        other.center.longitude == center.longitude &&
        other.radius == radius &&
        other.category == category &&
        other.facilityName == facilityName;
  }

  @override
  int get hashCode {
    return Object.hash(
      center.latitude,
      center.longitude,
      radius,
      category,
      facilityName,
    );
  }
}

// カテゴリ別検索プロバイダー
final categoryCacheProvider = FutureProvider.family<List<Facility>, CategorySearchKey>(
  (ref, searchKey) async {
    final result = await FacilityService.searchFacilities(
      center: searchKey.center,
      radius: searchKey.radius,
      amenities: [searchKey.category], // 単一カテゴリで検索
      facilityName: searchKey.facilityName.isNotEmpty ? searchKey.facilityName : null,
    );
    
    // 距離順にソート
    result.sort((a, b) {
      if (a.distance == null && b.distance == null) return 0;
      if (a.distance == null) return 1;
      if (b.distance == null) return -1;
      return a.distance!.compareTo(b.distance!);
    });
    
    return result;
  },
);

// インクリメンタル検索管理
class IncrementalSearchManager extends StateNotifier<Map<String, List<Facility>>> {
  IncrementalSearchManager(this.ref) : super({});

  final Ref ref;
  LatLng? _lastCenter;
  double? _lastRadius;
  String? _lastFacilityName;
  Set<String> _cachedCategories = {};

  Future<List<Facility>> getFacilities(
    LatLng center,
    double radius,
    List<String> amenities,
    String facilityName,
  ) async {
    // 検索条件が大きく変わった場合はキャッシュクリア
    if (_shouldClearCache(center, radius, facilityName)) {
      _clearCache();
    }

    _lastCenter = center;
    _lastRadius = radius;
    _lastFacilityName = facilityName;

    // 新しく追加されたカテゴリを特定
    final newCategories = amenities.where((category) => 
      !_cachedCategories.contains(category)).toList();

    // 新しいカテゴリを検索してキャッシュに追加
    for (final category in newCategories) {
      final categoryKey = CategorySearchKey(
        center: center,
        radius: radius,
        category: category,
        facilityName: facilityName,
      );
      
      final categoryResults = await ref.read(categoryCacheProvider(categoryKey).future);
      final currentState = {...state};
      currentState[category] = categoryResults;
      state = currentState;
      _cachedCategories.add(category);
    }

    // 削除されたカテゴリをキャッシュから除去
    final removedCategories = _cachedCategories.where((category) => 
      !amenities.contains(category)).toList();
    
    for (final category in removedCategories) {
      final currentState = {...state};
      currentState.remove(category);
      state = currentState;
      _cachedCategories.remove(category);
    }

    // 現在選択されているカテゴリの結果をマージ
    final allResults = <Facility>[];
    final facilityIds = <int>{};
    
    for (final category in amenities) {
      final categoryResults = state[category] ?? [];
      for (final facility in categoryResults) {
        if (!facilityIds.contains(facility.id)) {
          allResults.add(facility);
          facilityIds.add(facility.id);
        }
      }
    }

    // 距離順にソート
    allResults.sort((a, b) {
      if (a.distance == null && b.distance == null) return 0;
      if (a.distance == null) return 1;
      if (b.distance == null) return -1;
      return a.distance!.compareTo(b.distance!);
    });

    return allResults;
  }

  bool _shouldClearCache(LatLng center, double radius, String facilityName) {
    if (_lastCenter == null) return false;
    
    const Distance distance = Distance();
    final centerDistance = distance.as(LengthUnit.Meter, _lastCenter!, center);
    
    // 500m以上移動、半径が大きく変更、施設名が変更された場合
    return centerDistance > 500 || 
           (_lastRadius != null && (radius - _lastRadius!).abs() > 500) ||
           _lastFacilityName != facilityName;
  }

  void _clearCache() {
    state = {};
    _cachedCategories.clear();
  }
}

final incrementalSearchProvider = StateNotifierProvider<IncrementalSearchManager, Map<String, List<Facility>>>((ref) {
  return IncrementalSearchManager(ref);
});

// 新しいメイン検索プロバイダー
final optimizedFacilitiesProvider = FutureProvider<List<Facility>>((ref) async {
  final condition = ref.watch(searchConditionProvider);
  final searchManager = ref.read(incrementalSearchProvider.notifier);
  
  return await searchManager.getFacilities(
    condition.center,
    condition.radius,
    condition.amenities,
    condition.facilityName,
  );
});