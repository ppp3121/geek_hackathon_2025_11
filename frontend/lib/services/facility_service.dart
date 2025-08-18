import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/facility.dart';

class FacilityService {
  static const String _baseUrl = 'https://YOUR_FIREBASE_FUNCTION_URL';

  static Future<List<Facility>> searchFacilities({
    required LatLng center,
    required double radius,
    required List<String> amenities,
    String? facilityName,
  }) async {
    final uri = Uri.parse('$_baseUrl/searchFacilities').replace(
      queryParameters: {
        'lat': center.latitude.toString(),
        'lon': center.longitude.toString(),
        'radius': radius.toString(),
        'amenities': amenities.join(','),
        if (facilityName != null && facilityName.isNotEmpty)
          'name': facilityName,
      },
    );

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body) as List;
        return jsonList
            .map((json) => Facility.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw FacilityServiceException(
          'Failed to fetch facilities: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is FacilityServiceException) {
        rethrow;
      }
      throw FacilityServiceException(
        'Network error: ${e.toString()}',
        null,
      );
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