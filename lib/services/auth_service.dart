
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/app_user.dart';

class AuthService {
  Future<AppUser?> login({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = username.trim();

    if (normalizedUsername.isEmpty || password.isEmpty) {
      throw const AuthException(
        'Username dan password wajib diisi.',
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.loginUrl),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'username': normalizedUsername,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const AuthException(
          'Format respons dari server tidak valid.',
        );
      }

      if (response.statusCode == 401) {
        return null;
      }

      if (response.statusCode != 200) {
        final message = decoded['message'];

        throw AuthException(
          message is String
              ? message
              : 'Server gagal memproses login.',
        );
      }

      if (decoded['success'] != true ||
          decoded['data'] is! Map<String, dynamic>) {
        final message = decoded['message'];

        throw AuthException(
          message is String
              ? message
              : 'Respons login tidak sesuai format.',
        );
      }

      final userData =
          decoded['data'] as Map<String, dynamic>;

      final user = AppUser.fromJson(userData);

      if (!user.isActive) {
        return null;
      }

      if (user.token.trim().isEmpty) {
        throw const AuthException(
          'Token login tidak ditemukan dari server. '
          'Periksa login.php.',
        );
      }

      return user;
    } on TimeoutException {
      throw const AuthException(
        'Server terlalu lama merespons. Coba lagi.',
      );
    } on http.ClientException {
      throw const AuthException(
        'Tidak dapat terhubung ke server. '
        'Periksa koneksi dan URL API.',
      );
    } on FormatException {
      throw const AuthException(
        'Respons server bukan JSON yang valid.',
      );
    }
  }

  Future<AppUser?> validateSession(String token) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/validate_session.php',
            ),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return null;
      }

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic> ||
          decoded['success'] != true ||
          decoded['data'] is! Map<String, dynamic>) {
        return null;
      }

      final data =
          decoded['data'] as Map<String, dynamic>;

      data['token'] = token;

      final user = AppUser.fromJson(data);

      if (!user.isActive || user.token.isEmpty) {
        return null;
      }

      return user;
    } on Exception {
      return null;
    }
  }
}

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}
