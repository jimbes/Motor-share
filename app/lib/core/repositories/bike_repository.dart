import '../api_client.dart';
import '../models/bike.dart';

class BikeRepository {
  BikeRepository(this._client);

  final ApiClient _client;

  Future<List<Bike>> list() async {
    final response = await _client.dio.get('/bikes');
    return (response.data as List<dynamic>).map((e) => Bike.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Bike> create(Bike bike) async {
    final response = await _client.dio.post('/bikes', data: bike.toJson());
    return Bike.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Bike> update(int id, Bike bike) async {
    final response = await _client.dio.put('/bikes/$id', data: bike.toJson());
    return Bike.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _client.dio.delete('/bikes/$id');
}
