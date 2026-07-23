import 'dart:io';

import 'package:dio/dio.dart';

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

  Future<Bike> addPhoto(int id, File photo) async {
    final formData = FormData.fromMap({'photo': await MultipartFile.fromFile(photo.path)});
    final response = await _client.dio.post('/bikes/$id/photos', data: formData);
    return Bike.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Bike> removePhoto(int id, int photoId) async {
    final response = await _client.dio.delete('/bikes/$id/photos/$photoId');
    return Bike.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Bike> setDefault(int id) async {
    final response = await _client.dio.post('/bikes/$id/default');
    return Bike.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _client.dio.delete('/bikes/$id');
}
