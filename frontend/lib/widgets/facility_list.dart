import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/facility.dart';
import '../providers/facility_cache_provider.dart';

class FacilityList extends ConsumerStatefulWidget {
  final String? highlightedFacilityId;
  final ScrollController? scrollController;

  const FacilityList({
    super.key,
    this.highlightedFacilityId,
    this.scrollController,
  });

  @override
  ConsumerState<FacilityList> createState() => _FacilityListState();
}

class _FacilityListState extends ConsumerState<FacilityList> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void scrollToFacility(String facilityId, List<Facility> facilities) {
    final index = facilities.indexWhere((f) => f.id.toString() == facilityId);
    if (index == -1 || !_scrollController.hasClients) return;
    
    // レンダリング完了を待ってからスクロール実行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      
      final position = _scrollController.position;
      final itemHeight = 88.0;
      final viewportHeight = position.viewportDimension;
      
      // アイテムの開始位置
      final itemStart = index * itemHeight;
      final itemEnd = itemStart + itemHeight;
      
      // 現在の表示範囲
      final currentStart = position.pixels;
      final currentEnd = currentStart + viewportHeight;
      
      double? targetOffset;
      
      // アイテムが現在の表示範囲外にある場合のみスクロール
      if (itemEnd > currentEnd) {
        // 下にスクロールが必要
        targetOffset = itemEnd - viewportHeight + 20; // 20pxのマージン
      } else if (itemStart < currentStart) {
        // 上にスクロールが必要
        targetOffset = itemStart - 20; // 20pxのマージン
      }
      
      if (targetOffset != null) {
        final clampedOffset = targetOffset.clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        
        _scrollController.animateTo(
          clampedOffset,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final facilitiesAsync = ref.watch(currentFacilitiesProvider);

    return facilitiesAsync.when(
      loading: () => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('施設を検索中...'),
          ],
        ),
      ),
      error: (error, stackTrace) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              '検索中にエラーが発生しました',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'エラーの詳細は通知をご確認ください',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(currentFacilitiesProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('再試行'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
      data: (facilities) {
        if (facilities.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  '条件に一致する施設が見つかりませんでした',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '検索条件を変更するか、\n別の場所で検索してみてください',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () {
                    ref.invalidate(currentFacilitiesProvider);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('再検索'),
                ),
              ],
            ),
          );
        }

        // ハイライトされた施設があればスクロール
        if (widget.highlightedFacilityId != null) {
          scrollToFacility(widget.highlightedFacilityId!, facilities);
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(8),
          itemCount: facilities.length,
          itemBuilder: (context, index) {
            final facility = facilities[index];
            final isHighlighted = 
                widget.highlightedFacilityId == facility.id.toString();
            return FacilityListItem(
              facility: facility,
              isHighlighted: isHighlighted,
            );
          },
        );
      },
    );
  }
}

class FacilityListItem extends StatefulWidget {
  final Facility facility;
  final bool isHighlighted;

  const FacilityListItem({
    super.key,
    required this.facility,
    this.isHighlighted = false,
  });

  @override
  State<FacilityListItem> createState() => _FacilityListItemState();
}

class _FacilityListItemState extends State<FacilityListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _highlightController;
  late Animation<Color?> _highlightAnimation;

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _highlightAnimation = ColorTween(
      begin: Colors.blue.withOpacity(0.3),
      end: Colors.transparent,
    ).animate(CurvedAnimation(
      parent: _highlightController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void didUpdateWidget(FacilityListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !oldWidget.isHighlighted) {
      _highlightController.forward().then((_) {
        _highlightController.reset();
      });
    }
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _highlightAnimation,
      builder: (context, child) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          color: widget.isHighlighted ? _highlightAnimation.value : null,
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getCategoryColor(widget.facility.category),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getCategoryIcon(widget.facility.category),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              widget.facility.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_getCategoryDisplayName(widget.facility.category)),
                const SizedBox(height: 2),
                Text(
                  '${widget.facility.lat.toStringAsFixed(4)}, ${widget.facility.lon.toStringAsFixed(4)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _showFacilityDetail(context, widget.facility);
            },
          ),
        );
      },
    );
  }

  void _showFacilityDetail(BuildContext context, Facility facility) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(facility.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getCategoryIcon(facility.category),
                    color: _getCategoryColor(facility.category),
                  ),
                  const SizedBox(width: 8),
                  Text(_getCategoryDisplayName(facility.category)),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '位置情報',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('緯度: ${facility.lat.toStringAsFixed(6)}'),
              Text('経度: ${facility.lon.toStringAsFixed(6)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'restaurant':
        return Colors.orange;
      case 'cafe':
        return Colors.brown;
      case 'convenience':
        return Colors.green;
      case 'hospital':
        return Colors.red;
      case 'pharmacy':
        return Colors.pink;
      case 'bank':
        return Colors.blue;
      case 'atm':
        return Colors.lightBlue;
      case 'gas_station':
        return Colors.purple;
      case 'parking':
        return Colors.grey;
      case 'school':
        return Colors.indigo;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'restaurant':
        return Icons.restaurant;
      case 'cafe':
        return Icons.local_cafe;
      case 'convenience':
        return Icons.store;
      case 'hospital':
        return Icons.local_hospital;
      case 'pharmacy':
        return Icons.local_pharmacy;
      case 'bank':
        return Icons.account_balance;
      case 'atm':
        return Icons.atm;
      case 'gas_station':
        return Icons.local_gas_station;
      case 'parking':
        return Icons.local_parking;
      case 'school':
        return Icons.school;
      default:
        return Icons.place;
    }
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'restaurant':
        return 'レストラン';
      case 'cafe':
        return 'カフェ';
      case 'convenience':
        return 'コンビニ';
      case 'hospital':
        return '病院';
      case 'pharmacy':
        return '薬局';
      case 'bank':
        return '銀行';
      case 'atm':
        return 'ATM';
      case 'gas_station':
        return 'ガソリンスタンド';
      case 'parking':
        return '駐車場';
      case 'school':
        return '学校';
      default:
        return category;
    }
  }
}