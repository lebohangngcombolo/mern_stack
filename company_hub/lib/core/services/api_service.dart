// lib/core/services/api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:company_hub/core/constants/app_constants.dart';
import 'package:company_hub/core/services/storage_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final StorageService _storage = StorageService();
  final String _baseUrl = AppConstants.apiUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.readSecure(AppConstants.tokenKey);
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _handleResponse(http.Response response) async {
    if (response.statusCode == 401) {
      // Token expired, try to refresh
      final refreshed = await _refreshToken();
      if (!refreshed) {
        throw Exception('Authentication failed');
      }
      // Retry the request with new token
      return response;
    }
    return response;
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.readSecure(
        AppConstants.refreshTokenKey,
      );
      if (refreshToken == null) return false;

      final response = await http.post(
        Uri.parse(AppConstants.refreshToken),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _storage.writeSecure(AppConstants.tokenKey, data['access_token']);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ---------------- Auth ----------------
  Future<http.Response> login(String email, String password) async {
    return await http.post(
      Uri.parse(AppConstants.login),
      headers: await _getHeaders(),
      body: jsonEncode({'email': email, 'password': password}),
    );
  }

  Future<http.Response> logout() async {
    final response = await http.post(
      Uri.parse(AppConstants.logout),
      headers: await _getHeaders(),
    );
    await _storage.clearAll();
    return response;
  }

  Future<http.Response> refreshToken() async {
    return await http.post(
      Uri.parse(AppConstants.refreshToken),
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> changePassword(
      String currentPassword, String newPassword) async {
    return await http.post(
      Uri.parse(AppConstants.changePassword),
      headers: await _getHeaders(),
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
  }

  Future<http.Response> forgotPassword(String email) async {
    return await http.post(
      Uri.parse(AppConstants.forgotPassword),
      headers: await _getHeaders(),
      body: jsonEncode({'email': email}),
    );
  }

  Future<http.Response> resetPassword(String token, String newPassword) async {
    return await http.post(
      Uri.parse(AppConstants.resetPassword),
      headers: await _getHeaders(),
      body: jsonEncode({'token': token, 'new_password': newPassword}),
    );
  }

  Future<http.Response> setupMFA() async {
    return await http.post(
      Uri.parse(AppConstants.setupMfa),
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> verifyMFA(String mfaCode) async {
    final headers = await _getHeaders();
    final token = await _storage.readSecure(AppConstants.tokenKey);

    // Debug logging (remove in production)
    if (kDebugMode) {
      print('🔐 MFA Verify - Token present: ${token != null}');
      print('🔐 MFA Verify - Token length: ${token?.length ?? 0}');
      if (token != null && token.length > 20) {
        print('🔐 MFA Verify - Token preview: ${token.substring(0, 20)}...');
      }
    }

    return await http.post(
      Uri.parse(AppConstants.verifyMfa),
      headers: headers,
      body: jsonEncode({'mfa_code': mfaCode}),
    );
  }

  Future<http.Response> verifyMFASetup(String mfaCode) async {
    return await http.post(
      Uri.parse(AppConstants.verifyMfaSetup),
      headers: await _getHeaders(),
      body: jsonEncode({'mfa_code': mfaCode}),
    );
  }

  // ---------------- Admin ----------------
  Future<http.Response> getAdminDashboard() async {
    return await http.get(
      Uri.parse(AppConstants.adminDashboard),
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> getUsers({
    int page = 1,
    int perPage = 10,
    String search = '',
  }) async {
    final params = {
      'page': page.toString(),
      'per_page': perPage.toString(),
      if (search.isNotEmpty) 'search': search,
    };
    return await http.get(
      Uri.parse(AppConstants.getUsers).replace(queryParameters: params),
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> enrollUser(Map<String, dynamic> userData) async {
    return await http.post(
      Uri.parse(AppConstants.enrollUser),
      headers: await _getHeaders(),
      body: jsonEncode(userData),
    );
  }

  Future<http.Response> updateUser(
      int userId, Map<String, dynamic> userData) async {
    return await http.put(
      Uri.parse('${AppConstants.updateUser}/$userId'),
      headers: await _getHeaders(),
      body: jsonEncode(userData),
    );
  }

  Future<http.Response> getAuditLogs({
    int page = 1,
    int perPage = 20,
    int? userId,
    String action = '',
  }) async {
    final params = {
      'page': page.toString(),
      'per_page': perPage.toString(),
      if (userId != null) 'user_id': userId.toString(),
      if (action.isNotEmpty) 'action': action,
    };
    return await http.get(
      Uri.parse(AppConstants.auditLogs).replace(queryParameters: params),
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> getCompanyApps() async {
    return await http.get(
      Uri.parse(AppConstants.companyApps),
      headers: await _getHeaders(),
    );
  }

  // ---------------- User ----------------
  Future<http.Response> getCurrentUser() async {
    return await http.get(
      Uri.parse(AppConstants.getProfile),
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> updateProfile(String firstName, String lastName) async {
    return await http.put(
      Uri.parse(AppConstants.updateProfile),
      headers: await _getHeaders(),
      body: jsonEncode({'first_name': firstName, 'last_name': lastName}),
    );
  }

  Future<http.Response> getOnboarding() async {
    return await http.get(
      Uri.parse(AppConstants.getOnboarding),
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> saveOnboarding(
      int step, Map<String, dynamic> profileData) async {
    return await http.post(
      Uri.parse(AppConstants.saveOnboarding),
      headers: await _getHeaders(),
      body: jsonEncode({'step': step, 'profile_data': profileData}),
    );
  }

  // ---------------- SSO ----------------
  Future<http.Response> generateSSOToken(int appId) async {
    return await http.post(
      Uri.parse(AppConstants.generateSsoToken),
      headers: await _getHeaders(),
      body: jsonEncode({'app_id': appId}),
    );
  }

  Future<http.Response> validateSSOToken(String token) async {
    return await http.post(
      Uri.parse(AppConstants.validateSsoToken),
      headers: await _getHeaders(),
      body: jsonEncode({'token': token}),
    );
  }
}
