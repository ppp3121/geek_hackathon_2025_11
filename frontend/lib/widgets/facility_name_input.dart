import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_condition_provider.dart';

class FacilityNameInput extends ConsumerStatefulWidget {
  const FacilityNameInput({super.key});

  @override
  ConsumerState<FacilityNameInput> createState() => _FacilityNameInputState();
}

class _FacilityNameInputState extends ConsumerState<FacilityNameInput> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    // 初期値をコントローラーに設定
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialValue = ref.read(searchConditionProvider).facilityName;
      _controller.text = initialValue;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Providerの値が外部から変更された場合にTextFieldを同期
    ref.listen<SearchCondition>(searchConditionProvider, (previous, next) {
      if (next.facilityName != _controller.text) {
        _controller.text = next.facilityName;
      }
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '施設名で検索',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: '施設名を入力してください（例：スターバックス）',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                ref
                    .read(searchConditionProvider.notifier)
                    .updateFacilityName(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}