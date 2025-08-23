import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/facility_cache_provider.dart';

class SearchButton extends ConsumerWidget {
  const SearchButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facilitiesAsync = ref.watch(currentFacilitiesProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            // 検索実行：Providerを再取得することでAPIリクエストをトリガー
            ref.invalidate(currentFacilitiesProvider);
          },
          icon: facilitiesAsync.when(
            loading: () => const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            data: (_) => const Icon(Icons.search),
            error: (_, __) => const Icon(Icons.error),
          ),
          label: facilitiesAsync.when(
            loading: () => const Text('検索中...'),
            data: (facilities) => Text('施設を検索 (${facilities.length}件)'),
            error: (_, __) => const Text('検索エラー'),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}