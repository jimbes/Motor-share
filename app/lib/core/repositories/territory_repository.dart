import '../api_client.dart';
import '../models/territory.dart';

class TerritoryRepository {
  TerritoryRepository(this._client);

  final ApiClient _client;

  Future<List<Territory>> inBoundingBox({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    final response = await _client.dio.get(
      '/territories',
      queryParameters: {'bbox': '$south,$west,$north,$east'},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['territories'] as List<dynamic>)
        .map((e) => Territory.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
