
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

class SessionManager {
  static const String _keyUser = 'user_session';
  static const String _keyLoginTime = 'login_timestamp';
  static const String _keyBiometricEnabled = 'biometric_login_enabled';
  static const String _keySecureToken = 'secure_session_token';

  static const int _sessionDurationMinutes = 5;

  static const FlutterSecureStorage _secureStorage =
      FlutterSecureStorage();

  static Future<void> saveSession(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();

    final userMap = user.toMap()..remove('token');

    await prefs.setString(_keyUser, jsonEncode(userMap));
    await prefs.setString(
      _keyLoginTime,
      DateTime.now().toIso8601String(),
    );

    if (user.token.trim().isNotEmpty) {
      await _secureStorage.write(
        key: _keySecureToken,
        value: user.token,
      );
    }
  }

  static Future<AppUser?> getValidSession() async {
    final prefs = await SharedPreferences.getInstance();

    final userJson = prefs.getString(_keyUser);
    final loginTimeStr = prefs.getString(_keyLoginTime);

    if (userJson == null || loginTimeStr == null) {
      return null;
    }

    try {
      final loginTime = DateTime.parse(loginTimeStr);
      final difference = DateTime.now().difference(loginTime);

      if (difference.isNegative ||
          difference >= const Duration(
            minutes: _sessionDurationMinutes,
          )) {
        await clearSession();
        return null;
      }

      final token = await _secureStorage.read(
        key: _keySecureToken,
      );

      if (token == null || token.isEmpty) {
        await clearSession();
        return null;
      }

      final userMap =
          jsonDecode(userJson) as Map<String, dynamic>;

      userMap['token'] = token;
      return AppUser.fromJson(userMap);
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  static Future<void> enableBiometricLogin(AppUser user) async {
    await saveSession(user);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, true);
  }

  static Future<bool> isBiometricLoginEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  static Future<String?> getSecureToken() async {
    return _secureStorage.read(key: _keySecureToken);
  }

  static Future<void> disableBiometricLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, false);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_keyUser);
    await prefs.remove(_keyLoginTime);
    await prefs.remove(_keyBiometricEnabled);

    await _secureStorage.delete(key: _keySecureToken);
  }
}