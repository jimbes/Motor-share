import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import 'api_config.dart';

/// Thin Dio wrapper. Holds the current bearer token in memory (set by
/// [AuthProvider] on login/restore, cleared on logout) so every request
/// carries it automatically.
class ApiClient {
  ApiClient() : dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl, connectTimeout: const Duration(seconds: 15))) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          options.headers['Accept'] = 'application/json';
          handler.next(options);
        },
      ),
    );
  }

  final Dio dio;
  String? _token;

  void setToken(String? token) => _token = token;
}

/// Flattens Laravel's validation error payload
/// ({"message": "...", "errors": {"field": ["msg"]}}) into a single string.
String apiErrorMessage(BuildContext context, Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        return errors.values.first is List ? (errors.values.first as List).first.toString() : errors.values.first.toString();
      }
      if (data['message'] != null) return data['message'].toString();
    }
    if (error.type == DioExceptionType.connectionTimeout || error.type == DioExceptionType.connectionError) {
      return AppLocalizations.of(context)!.apiErrorNetwork;
    }
  }
  return AppLocalizations.of(context)!.apiErrorGeneric;
}
