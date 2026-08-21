import '../api_client.dart';
import '../models/point_of_interest.dart';

class PointOfInterestRepository {
  PointOfInterestRepository(this._client);

  final ApiClient _client;

  /// The community points-of-interest map within a bounding box.
  Future<List<PointOfInterest>> inBoundingBox({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    final response = await _client.dio.get(
      '/pois',
      queryParameters: {'bbox': '$south,$west,$north,$east'},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['data'] as List<dynamic>)
        .map((e) => PointOfInterest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PointOfInterest> show(int id) async {
    final response = await _client.dio.get('/pois/$id');
    return PointOfInterest.fromJson(response.data as Map<String, dynamic>);
  }
}
