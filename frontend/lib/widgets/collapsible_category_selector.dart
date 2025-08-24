import 'package:flutter/material.dart';

class CollapsibleCategorySelector extends StatefulWidget {
  final List<String> selectedCategories;
  final Function(List<String>) onCategoriesChanged;

  const CollapsibleCategorySelector({
    super.key,
    required this.selectedCategories,
    required this.onCategoriesChanged,
  });

  @override
  State<CollapsibleCategorySelector> createState() =>
      _CollapsibleCategorySelectorState();
}

class _CollapsibleCategorySelectorState
    extends State<CollapsibleCategorySelector>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  // カテゴリを分類別に整理
  final Map<String, Map<String, String>> _categoryGroups = {
    '飲食店': {
      'カフェ': 'カフェ',
      'レストラン': 'レストラン',
      'ラーメン': 'ラーメン',
      'うどん': 'うどん',
      'そば': 'そば',
      '寿司': '寿司',
      '焼肉': '焼肉',
      '焼き鳥': '焼き鳥',
      'カレー': 'カレー',
      'ハンバーガー': 'ハンバーガー',
      '中華料理': '中華料理',
      '韓国料理': '韓国料理',
      '居酒屋': '居酒屋',
    },
    'ショッピング': {
      'コンビニ': 'コンビニ',
      'スーパーマーケット': 'スーパーマーケット',
      'デパート': 'デパート',
      'ドラッグストア': 'ドラッグストア',
      '本屋': '本屋',
      '服屋': '服屋',
      '家電量販店': '家電量販店',
      'ホームセンター': 'ホームセンター',
    },
    '生活サービス': {
      '銀行': '銀行',
      'ATM': 'ATM',
      '郵便局': '郵便局',
      '美容院': '美容院',
      '理髪店': '理髪店',
      'クリーニング': 'クリーニング',
      'コインランドリー': 'コインランドリー',
      '駐車場': '駐車場',
    },
    '医療・健康': {
      '病院': '病院',
      'クリニック': 'クリニック',
      '歯科': '歯科',
      '薬局': '薬局',
      'フィットネスジム': 'フィットネスジム',
    },
    '公共施設': {
      '図書館': '図書館',
      '市役所': '市役所',
      '警察署': '警察署',
      '消防署': '消防署',
      '公園': '公園',
    },
    '娯楽・観光': {
      '映画館': '映画館',
      '美術館': '美術館',
      '博物館': '博物館',
      'ゲームセンター': 'ゲームセンター',
      'ボウリング場': 'ボウリング場',
      'ホテル': 'ホテル',
    },
  };

  String? _selectedGroup;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _toggleCategory(String category) {
    final List<String> newCategories = List.from(widget.selectedCategories);
    if (newCategories.contains(category)) {
      newCategories.remove(category);
    } else {
      newCategories.add(category);
    }
    widget.onCategoriesChanged(newCategories);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(
                    Icons.category,
                    color: Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'カテゴリ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (widget.selectedCategories.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${widget.selectedCategories.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  // カテゴリグループのタブ
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categoryGroups.keys.map((groupName) {
                        final isSelected = _selectedGroup == groupName;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              groupName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() {
                                _selectedGroup = isSelected ? null : groupName;
                              });
                            },
                            backgroundColor: Colors.grey.shade200,
                            selectedColor: Theme.of(context).primaryColor,
                            checkmarkColor: Colors.white,
                            side: BorderSide(
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey.shade400,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 選択されたグループのカテゴリ一覧
                  if (_selectedGroup != null)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categoryGroups[_selectedGroup]!.entries.map((entry) {
                        final displayName = entry.key;
                        final apiValue = entry.value;
                        final isSelected =
                            widget.selectedCategories.contains(apiValue);

                        return FilterChip(
                          label: Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (_) => _toggleCategory(apiValue),
                          backgroundColor: Colors.grey.shade100,
                          selectedColor: Theme.of(context).primaryColor,
                          checkmarkColor: Colors.white,
                          side: BorderSide(
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.grey.shade300,
                          ),
                        );
                      }).toList(),
                    ),
                  // グループが選択されていない場合のメッセージ
                  if (_selectedGroup == null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '上のカテゴリを選択してください',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}