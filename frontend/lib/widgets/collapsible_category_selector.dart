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

  // カテゴリのマップ（表示名 -> API用の値）
  final Map<String, String> _categories = {
    // 飲食店
    'カフェ': 'カフェ',
    'レストラン': 'レストラン',
    'ラーメン': 'ラーメン',
    'うどん': 'うどん',
    'そば': 'そば',
    '寿司': '寿司',
    '焼肉': '焼肉',
    '焼き鳥': '焼き鳥',
    '天ぷら': '天ぷら',
    'とんかつ': 'とんかつ',
    '丼物': '丼物',
    'お好み焼き': 'お好み焼き',
    'ピザ': 'ピザ',
    'カレー': 'カレー',
    'ハンバーガー': 'ハンバーガー',
    '中華料理': '中華料理',
    '韓国料理': '韓国料理',
    'タイ料理': 'タイ料理',
    'ベトナム料理': 'ベトナム料理',
    'インド料理': 'インド料理',
    '居酒屋': '居酒屋',
    'バー': 'バー',
    
    // 小売店
    'コンビニ': 'コンビニ',
    'スーパーマーケット': 'スーパーマーケット',
    'デパート': 'デパート',
    'パン屋': 'パン屋',
    'ケーキ屋': 'ケーキ屋',
    '和菓子屋': '和菓子屋',
    '本屋': '本屋',
    '文房具店': '文房具店',
    '服屋': '服屋',
    '靴屋': '靴屋',
    'メガネ屋': 'メガネ屋',
    '家具屋': '家具屋',
    '雑貨屋': '雑貨屋',
    '花屋': '花屋',
    'ホームセンター': 'ホームセンター',
    '家電量販店': '家電量販店',
    'ドラッグストア': 'ドラッグストア',
    'おもちゃ屋': 'おもちゃ屋',
    'スポーツ用品店': 'スポーツ用品店',
    '自転車屋': '自転車屋',
    'ペットショップ': 'ペットショップ',
    
    // 医療・健康
    '薬局': '薬局',
    '病院': '病院',
    'クリニック': 'クリニック',
    '歯科': '歯科',
    
    // 金融・郵便
    '郵便局': '郵便局',
    '銀行': '銀行',
    'ATM': 'ATM',
    
    // 公共施設
    '図書館': '図書館',
    '市役所': '市役所',
    '警察署': '警察署',
    '消防署': '消防署',
    
    // サービス
    '駐車場': '駐車場',
    'コインランドリー': 'コインランドリー',
    'クリーニング': 'クリーニング',
    'レンタカー': 'レンタカー',
    '美容院': '美容院',
    '理髪店': '理髪店',
    'ネイルサロン': 'ネイルサロン',
    
    // 宿泊
    'ホテル': 'ホテル',
    '旅館': '旅館',
    
    // 娯楽・レジャー
    '公園': '公園',
    '映画館': '映画館',
    '美術館': '美術館',
    '博物館': '博物館',
    'ゲームセンター': 'ゲームセンター',
    'ボウリング場': 'ボウリング場',
    'フィットネスジム': 'フィットネスジム',
    
    // その他
    'ガソリンスタンド': 'ガソリンスタンド',
  };

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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.entries.map((entry) {
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}