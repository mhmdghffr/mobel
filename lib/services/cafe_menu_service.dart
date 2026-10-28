import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/app_user.dart';
import '../models/cafe_menu.dart';

class CafeMenuService {
  final AppUser user;

  CafeMenuService(this.user);

  Uri get _endpoint => Uri.parse(
        '${ApiConfig.baseUrl}/menu.php',
      );

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${user.token}',
      };

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception(
        'Respons server bukan JSON yang valid '
        '(HTTP ${response.statusCode}).',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Format respons server tidak sesuai.');
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] != true) {
      throw Exception(
        decoded['message']?.toString() ??
            'Permintaan gagal (HTTP ${response.statusCode}).',
      );
    }

    return decoded;
  }

  Future<List<CafeMenu>> fetchMenus() async {
    final response = await http.get(
      _endpoint,
      headers: _headers,
    );

    final result = _decodeResponse(response);
    final data = result['data'];

    if (data is! List) {
      throw Exception('Data menu dari server tidak valid.');
    }

    return data
        .map(
          (item) => CafeMenu.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> addMenu({
    required String name,
    required String category,
    required double price,
    required bool isAvailable,
  }) async {
    final response = await http.post(
      _endpoint,
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'category': category,
        'price': price,
        'is_available': isAvailable,
      }),
    );

    _decodeResponse(response);
  }

  Future<void> updateMenu({
    required int id,
    required String name,
    required String category,
    required double price,
    required bool isAvailable,
  }) async {
    final response = await http.put(
      _endpoint,
      headers: _headers,
      body: jsonEncode({
        'id': id,
        'name': name,
        'category': category,
        'price': price,
        'is_available': isAvailable,
      }),
    );

    _decodeResponse(response);
  }

  Future<void> deleteMenu(int id) async {
    final uri = _endpoint.replace(
      queryParameters: {'id': id.toString()},
    );

    final response = await http.delete(
      uri,
      headers: _headers,
    );

    _decodeResponse(response);
  }
}