import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_condition_provider.dart';

class CategorySelector extends ConsumerWidget {
  const CategorySelector({super.key});

  static const Map<String, String> _categoryMap = {
    'restaurant': 'レストラン',
    'cafe': 'カフェ',
    'convenience': 'コンビニ',
    'hospital': '病院',
    'pharmacy': '薬局',
    'bank': '銀行',
    'atm': 'ATM',
    'gas_station': 'ガソリンスタンド',
    'parking': '駐車場',
    'school': '学校',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchCondition = ref.watch(searchConditionProvider);
    final selectedAmenities = Set<String>.from(searchCondition.amenities);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'カテゴリ選択',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: _categoryMap.entries.map((entry) {
                final categoryKey = entry.key;
                final categoryLabel = entry.value;
                final isSelected = selectedAmenities.contains(categoryKey);

                return FilterChip(
                  label: Text(categoryLabel),
                  selected: isSelected,
                  onSelected: (bool selected) {
                    final newAmenities = Set<String>.from(selectedAmenities);
                    if (selected) {
                      newAmenities.add(categoryKey);
                    } else {
                      newAmenities.remove(categoryKey);
                    }
                    
                    ref
                        .read(searchConditionProvider.notifier)
                        .updateAmenities(newAmenities.toList());
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}