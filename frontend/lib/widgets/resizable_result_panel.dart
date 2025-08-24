import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/result_panel_provider.dart';
import '../models/facility.dart';
import 'facility_list.dart';

class ResizableResultPanel extends ConsumerStatefulWidget {
  final String? highlightedFacilityId;
  final Function(Facility facility)? onFacilityTapped;

  const ResizableResultPanel({
    super.key,
    this.highlightedFacilityId,
    this.onFacilityTapped,
  });

  @override
  ConsumerState<ResizableResultPanel> createState() => _ResizableResultPanelState();
}

class _ResizableResultPanelState extends ConsumerState<ResizableResultPanel>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;
  
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _heightAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  double _getHeightRatio(ResultPanelState state) {
    switch (state) {
      case ResultPanelState.minimal:
        return 0.15; // 最小：画面の15%
      case ResultPanelState.collapsed:
        return 0.35; // 省略表示：画面の35%
      case ResultPanelState.expanded:
        return 0.85; // 全画面：画面の85%
    }
  }

  @override
  Widget build(BuildContext context) {
    final panelState = ref.watch(resultPanelProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final targetHeight = screenHeight * _getHeightRatio(panelState);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: targetHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: GestureDetector(
        onPanEnd: (details) {
          // スワイプによる状態切り替え
          if (details.velocity.pixelsPerSecond.dy < -500) {
            // 上スワイプ
            _handleSwipeUp();
          } else if (details.velocity.pixelsPerSecond.dy > 500) {
            // 下スワイプ
            _handleSwipeDown();
          }
        },
        child: Column(
          children: [
            // ドラッグハンドル
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ドラッグインジケーター
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // タイトル
                  if (panelState != ResultPanelState.minimal) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.list, color: Colors.grey, size: 20),
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
                  ],
                ],
              ),
            ),
            // コンテンツエリア
            if (panelState != ResultPanelState.minimal)
              Expanded(
                child: FacilityList(
                  highlightedFacilityId: widget.highlightedFacilityId,
                  scrollController: _scrollController,
                  onFacilityTapped: widget.onFacilityTapped,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleSwipeUp() {
    final currentState = ref.read(resultPanelProvider);
    switch (currentState) {
      case ResultPanelState.minimal:
        ref.read(resultPanelProvider.notifier).setState(ResultPanelState.collapsed);
        break;
      case ResultPanelState.collapsed:
        ref.read(resultPanelProvider.notifier).setState(ResultPanelState.expanded);
        break;
      case ResultPanelState.expanded:
        // 全画面では上スワイプで変化なし
        break;
    }
  }

  void _handleSwipeDown() {
    final currentState = ref.read(resultPanelProvider);
    switch (currentState) {
      case ResultPanelState.minimal:
        // 最小では下スワイプで変化なし
        break;
      case ResultPanelState.collapsed:
        ref.read(resultPanelProvider.notifier).setState(ResultPanelState.minimal);
        break;
      case ResultPanelState.expanded:
        ref.read(resultPanelProvider.notifier).setState(ResultPanelState.collapsed);
        break;
    }
  }
}