import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/map_widget.dart';
import 'widgets/facility_list.dart';
import 'widgets/error_handler.dart';
import 'widgets/floating_search_bar.dart';
import 'widgets/collapsible_category_selector.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
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

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<String> _selectedCategories = ['restaurant', 'cafe', 'convenience'];

  void _handleSearch(String query) {
    // TODO: 自然言語検索の実装
    print('検索クエリ: $query');
    print('選択されたカテゴリ: $_selectedCategories');
  }

  void _handleClearSearch() {
    // TODO: 検索結果のクリア
    print('検索をクリア');
  }

  void _handleCategoriesChanged(List<String> categories) {
    setState(() {
      _selectedCategories = categories;
    });
    print('カテゴリが変更されました: $categories');
  }

  @override
  Widget build(BuildContext context) {
    return ErrorHandler(
      child: Scaffold(
        body: Stack(
          children: [
            Column(
              children: [
                const Expanded(
                  flex: 2,
                  child: MapWidget(),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.list, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        '検索結果',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Expanded(
                  flex: 1,
                  child: FacilityList(),
                ),
              ],
            ),
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
                  CollapsibleCategorySelector(
                    selectedCategories: _selectedCategories,
                    onCategoriesChanged: _handleCategoriesChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
