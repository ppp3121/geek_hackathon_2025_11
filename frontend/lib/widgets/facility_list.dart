import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/facility.dart';
import '../providers/facility_cache_provider.dart';

class FacilityList extends ConsumerWidget {
  const FacilityList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            Text(
              '検索中にエラーが発生しました\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(currentFacilitiesProvider);
              },
              child: const Text('再試行'),
            ),
          ],
        ),
      ),
      data: (facilities) {
        if (facilities.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 48,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  '条件に一致する施設が見つかりませんでした',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: facilities.length,
          itemBuilder: (context, index) {
            final facility = facilities[index];
            return FacilityListItem(facility: facility);
          },
        );
      },
    );
  }
}

class FacilityListItem extends StatelessWidget {
  final Facility facility;

  const FacilityListItem({
    super.key,
    required this.facility,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getCategoryColor(facility.category),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getCategoryIcon(facility.category),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          facility.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getCategoryDisplayName(facility.category)),
            const SizedBox(height: 2),
            Text(
              '${facility.lat.toStringAsFixed(4)}, ${facility.lon.toStringAsFixed(4)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          _showFacilityDetail(context, facility);
        },
      ),
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