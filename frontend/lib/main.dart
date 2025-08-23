import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/map_widget.dart';
import 'widgets/facility_list.dart';
import 'widgets/error_handler.dart';
import 'widgets/floating_search_bar.dart';
import 'widgets/collapsible_category_selector.dart';
import 'widgets/resizable_result_panel.dart';
import 'providers/search_condition_provider.dart';
import 'providers/result_panel_provider.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '施設検索アプリ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends ConsumerStatefulWidget {
  const MyHomePage({super.key});

  @override
  ConsumerState<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends ConsumerState<MyHomePage> {
  String? _highlightedFacilityId;

  void _handleSearch(String query) {
    // TODO: 自然言語検索の実装
    ref.read(searchConditionProvider.notifier).updateFacilityName(query);
    print('検索クエリ: $query');
  }

  void _handleClearSearch() {
    ref.read(searchConditionProvider.notifier).updateFacilityName('');
    print('検索をクリア');
  }

  void _handleCategoriesChanged(List<String> categories) {
    ref.read(searchConditionProvider.notifier).updateAmenities(categories);
    print('カテゴリが変更されました: $categories');
  }

  void _handleFacilityTapped(String facilityId) {
    setState(() {
      _highlightedFacilityId = facilityId;
    });
    print('施設がタップされました: $facilityId');

    // ピンタップ時に最小表示から省略表示に移行
    ref.read(resultPanelProvider.notifier).showFromMinimal();

    // ハイライトを一定時間後にクリア
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _highlightedFacilityId = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ErrorHandler(
      child: Scaffold(
        body: Stack(
          children: [
            // マップエリア
            Positioned.fill(
              child: MapWidget(onFacilityTapped: _handleFacilityTapped),
            ),
            // 検索バーとカテゴリセレクター（背面）
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  FloatingSearchBar(
                    onSearch: _handleSearch,
                    onClear: _handleClearSearch,
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      final searchCondition = ref.watch(searchConditionProvider);
                      return CollapsibleCategorySelector(
                        selectedCategories: searchCondition.amenities,
                        onCategoriesChanged: _handleCategoriesChanged,
                      );
                    },
                  ),
                ],
              ),
            ),
            // リサイズ可能な結果パネル（前面）
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ResizableResultPanel(
                highlightedFacilityId: _highlightedFacilityId,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
