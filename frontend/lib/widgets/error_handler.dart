import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/facility_cache_provider.dart';
import '../services/facility_service.dart';

class ErrorHandler extends ConsumerWidget {
  final Widget child;

  const ErrorHandler({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 検索結果のエラー状態を監視
    ref.listen<AsyncValue<List<dynamic>>>(
      currentFacilitiesProvider,
      (previous, next) {
        if (next.hasError) {
          _showErrorMessage(context, next.error);
        }
      },
    );

    return child;
  }

  void _showErrorMessage(BuildContext context, Object? error) {
    String message;
    String title;
    bool showRetry = true;

    if (error is FacilityServiceException) {
      title = 'エラー';
      message = error.message;
      
      // 特定のエラーコードでリトライボタンの表示を制御
      if (error.statusCode == 401 || error.statusCode == 403) {
        showRetry = false;
      }
    } else {
      title = '予期しないエラー';
      message = 'アプリケーションでエラーが発生しました。時間をおいて再度お試しください。';
    }

    // SnackBarで簡潔にエラーを表示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: '詳細',
          textColor: Colors.white,
          onPressed: () {
            _showErrorDialog(context, title, message, showRetry);
          },
        ),
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String title, String message, bool showRetry) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('閉じる'),
            ),
            if (showRetry) ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // エラー発生時の再試行
                  final container = ProviderScope.containerOf(context);
                  container.invalidate(currentFacilitiesProvider);
                },
                child: const Text('再試行'),
              ),
            ],
          ],
        );
      },
    );
  }
}

// エラー状態を監視するためのProvider拡張
class ErrorNotifier extends StateNotifier<String?> {
  ErrorNotifier() : super(null);

  void showError(String message) {
    state = message;
  }

  void clearError() {
    state = null;
  }
}

final errorNotifierProvider = StateNotifierProvider<ErrorNotifier, String?>((ref) {
  return ErrorNotifier();
});