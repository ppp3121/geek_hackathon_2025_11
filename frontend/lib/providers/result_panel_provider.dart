import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ResultPanelState {
  minimal,     // 最小
  collapsed,   // 省略表示
  expanded,    // 全画面
}

class ResultPanelNotifier extends StateNotifier<ResultPanelState> {
  ResultPanelNotifier() : super(ResultPanelState.collapsed);

  void setState(ResultPanelState newState) {
    state = newState;
  }

  void toggleToNextState() {
    switch (state) {
      case ResultPanelState.minimal:
        state = ResultPanelState.collapsed;
        break;
      case ResultPanelState.collapsed:
        state = ResultPanelState.expanded;
        break;
      case ResultPanelState.expanded:
        state = ResultPanelState.minimal;
        break;
    }
  }

  void showFromMinimal() {
    if (state == ResultPanelState.minimal) {
      state = ResultPanelState.collapsed;
    }
  }
}

final resultPanelProvider = StateNotifierProvider<ResultPanelNotifier, ResultPanelState>((ref) {
  return ResultPanelNotifier();
});