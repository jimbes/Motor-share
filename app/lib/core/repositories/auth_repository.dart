import 'dart:io';

import 'package:dio/dio.dart';

import '../api_client.dart';
import '../models/user.dart';

class AuthResult {
  const AuthResult({required this.user, required this.token});

  final AppUser user;
  final String token;
}

class AuthRepository {
  AuthRepository(this._client);

  final ApiClient _client;

  Future<AuthResult> register({required String name, required String email, required String password}) async {
    final response = await _client.dio.post('/register', data: {
      'name': name,
      'email': email,
      'password': password,
    });
    return AuthResult(
      user: AppUser.fromJson(response.data['user'] as Map<String, dynamic>),
      token: response.data['token'] as String,
    );
  }

  Future<AuthResult> login({required String email, required String password}) async {
    final response = await _client.dio.post('/login', data: {
      'email': email,
      'password': password,
    });
    return AuthResult(
      user: AppUser.fromJson(response.data['user'] as Map<String, dynamic>),
      token: response.data['token'] as String,
    );
  }

  Future<AppUser> me() async {
    final response = await _client.dio.get('/me');
    return AppUser.fromJson(response.data as Map<String, dynamic>);
  }

  /// [username] is always sent, including as null to clear it - the other
  /// fields default to "leave unchanged" when omitted.
  Future<AppUser> updateProfile({required String name, String? username}) async {
    final response = await _client.dio.patch('/me', data: {
      'name': name,
      'username': username,
    });
    return AppUser.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AppUser> uploadAvatar(File avatar) async {
    final formData = FormData.fromMap({'avatar': await MultipartFile.fromFile(avatar.path)});
    final response = await _client.dio.post('/me/avatar', data: formData);
    return AppUser.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> logout() => _client.dio.post('/logout');
}
