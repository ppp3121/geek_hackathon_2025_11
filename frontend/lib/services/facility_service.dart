import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/facility.dart';
import '../config/api_config.dart';

class FacilityService {
  static Future<List<Facility>> searchFacilities({
    required LatLng center,
    required double radius,
    required List<String> amenities,
    String? facilityName,
  }) async {
    final uri = Uri.parse(ApiConfig.searchFacilitiesEndpoint).replace(
      queryParameters: {
        'lat': center.latitude.toString(),
        'lon': center.longitude.toString(),
        'radius': radius.toString(),
        'categories': amenities.join(','),
        if (facilityName != null && facilityName.isNotEmpty)
          'name': facilityName,
      },
    );

    try {
      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body) as List;
        return jsonList
            .map((json) => Facility.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        // HTTPステータスコードに基づいてより詳細なエラーメッセージを提供
        String userMessage = _getErrorMessageForStatusCode(response.statusCode);
        throw FacilityServiceException(
          userMessage,
          response.statusCode,
        );
      }
    } on http.ClientException catch (e) {
      // ネットワーク接続エラー
      throw const FacilityServiceException(
        'インターネット接続を確認してください',
        null,
      );
    } on FormatException catch (e) {
      // JSONデコードエラー
      throw const FacilityServiceException(
        'サーバーからの応答が不正です',
        null,
      );
    } on FacilityServiceException {
      // 既にFacilityServiceExceptionの場合はそのまま再スロー
      rethrow;
    } catch (e) {
      // その他の予期しないエラー
      throw FacilityServiceException(
        '予期しないエラーが発生しました: ${e.toString()}',
        null,
      );
    }
  }

  static String _getErrorMessageForStatusCode(int statusCode) {
    switch (statusCode) {
      case 400:
        return '検索条件が不正です。入力内容を確認してください';
      case 401:
        return '認証エラーが発生しました';
      case 403:
        return 'アクセスが拒否されました';
      case 404:
        return 'サービスが見つかりません';
      case 429:
        return '検索回数の上限に達しました。しばらく時間をおいてからお試しください';
      case 500:
        return 'サーバーエラーが発生しました。時間をおいて再度お試しください';
      case 502:
      case 503:
      case 504:
        return 'サーバーが一時的に利用できません。時間をおいて再度お試しください';
      default:
        return 'サーバーエラーが発生しました (エラーコード: $statusCode)';
    }
  }
}

class FacilityServiceException implements Exception {
  final String message;
  final int? statusCode;

  const FacilityServiceException(this.message, this.statusCode);

  @override
  String toString() => 'FacilityServiceException: $message';
}
