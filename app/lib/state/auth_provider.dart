import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/models/user.dart';
import '../core/repositories/auth_repository.dart';
import '../core/token_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider({required ApiClient apiClient, required AuthRepository authRepository, required TokenStorage tokenStorage})
      : _apiClient = apiClient,
        _authRepository = authRepository,
        _tokenStorage = tokenStorage;

  final ApiClient _apiClient;
  final AuthRepository _authRepository;
  final TokenStorage _tokenStorage;

  AuthStatus status = AuthStatus.unknown;
  AppUser? user;

  /// Called once at app startup: restore a previously stored session, if any.
  Future<void> restore() async {
    final token = await _tokenStorage.read();
    if (token == null) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    _apiClient.setToken(token);
    try {
      user = await _authRepository.me();
      status = AuthStatus.authenticated;
    } catch (_) {
      await _tokenStorage.clear();
      _apiClient.setToken(null);
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> register({required String name, required String email, required String password}) async {
    final result = await _authRepository.register(name: name, email: email, password: password);
    await _completeLogin(result);
  }

  Future<void> login({required String email, required String password}) async {
    final result = await _authRepository.login(email: email, password: password);
    await _completeLogin(result);
  }

  Future<void> _completeLogin(AuthResult result) async {
    await _tokenStorage.write(result.token);
    _apiClient.setToken(result.token);
    user = result.user;
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> updateProfile({required String name, String? username}) async {
    user = await _authRepository.updateProfile(name: name, username: username);
    notifyListeners();
  }

  Future<void> uploadAvatar(File avatar) async {
    user = await _authRepository.uploadAvatar(avatar);
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _authRepository.logout();
    } catch (_) {
      // Best effort - clear the local session regardless.
    }
    await _tokenStorage.clear();
    _apiClient.setToken(null);
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
