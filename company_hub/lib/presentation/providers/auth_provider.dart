// lib/presentation/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:company_hub/data/models/user_model.dart';
import 'package:company_hub/core/services/api_service.dart';
import 'package:company_hub/core/services/storage_service.dart';
import 'package:company_hub/core/constants/app_constants.dart';
import 'dart:convert';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;

  // Initialize auth state
  Future<void> initialize() async {
    // DO NOT rebuild UI during initialize after login
    try {
      final token = await _storageService.readSecure(AppConstants.tokenKey);
      if (token != null) {
        await _getCurrentUser();
      }
    } catch (e) {
      await _storageService.clearAll();
    }
  }

  // Login
  // ---------------------- LOGIN ----------------------
  Future<Map<String, dynamic>> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.login(email, password);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // MFA required
        if (data['mfa_required'] == true) {
          final mfaToken = data['mfa_session_token'];
          if (mfaToken == null) {
            _error = 'MFA session token missing from server response';
            return {'success': false, 'error': _error};
          }

          await _storageService.writeSecure(
            AppConstants.tokenKey,
            mfaToken.toString(),
          );

          // Debug: Verify token was stored
          final storedToken =
              await _storageService.readSecure(AppConstants.tokenKey);
          print('🔐 Login - MFA token stored: ${storedToken != null}');
          print('🔐 Login - Stored token length: ${storedToken?.length ?? 0}');

          return {
            'success': true,
            'mfa_required': true,
            'user_id': data['user_id'], // ok (int allowed in memory)
            'user': data['user'],
          };
        }

        // First login
        else if (data['first_login'] == true) {
          await _storageService.writeSecure(
            AppConstants.tokenKey,
            data['first_login_token'].toString(),
          );
          return {
            'success': true,
            'first_login': true,
            'user_id': data['user_id'],
            'user': data['user'],
          };
        }

        // Regular login
        else {
          await _storeAuthData(data);
          await _getCurrentUser();
          return {
            'success': true,
            'onboarding_required': data['onboarding_required'] ?? false,
          };
        }
      } else {
        _error = data['error'] ?? 'Login failed';
        return {'success': false, 'error': _error};
      }
    } catch (e) {
      _error = 'Network error occurred';
      return {'success': false, 'error': _error};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Verify MFA
  Future<Map<String, dynamic>> verifyMFA(String mfaCode) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    Map<String, dynamic> result;

    try {
      // Debug: Check token before making request
      final tokenBeforeRequest =
          await _storageService.readSecure(AppConstants.tokenKey);
      print(
          '🔐 VerifyMFA - Token before request: ${tokenBeforeRequest != null}');
      print('🔐 VerifyMFA - Token length: ${tokenBeforeRequest?.length ?? 0}');

      final response = await _apiService.verifyMFA(mfaCode);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await _storeAuthData(data);
        await _getCurrentUser();

        result = {
          'success': true,
          'onboarding_required': !(_user?.onboardingCompleted ?? true),
        };
      } else {
        _error = data['error'] ?? 'MFA verification failed';
        final details = data['details'];
        if (details != null) {
          print('⚠️ MFA Error Details: $details');
        }
        result = {'success': false, 'error': _error};
      }
    } catch (e) {
      print('❌ VerifyMFA Exception: $e');
      _error = 'Network error: $e';
      result = {'success': false, 'error': _error};
    }

    _isLoading = false;

    // Notify ONCE after everything settles
    await Future.delayed(const Duration(milliseconds: 120));
    notifyListeners();

    return result;
  }

  // Setup MFA
  Future<Map<String, dynamic>> setupMFA() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.setupMFA();
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        _error = data['error'] ?? 'MFA setup failed';
        return {'success': false, 'error': _error};
      }
    } catch (e) {
      _error = 'Network error occurred';
      return {'success': false, 'error': _error};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Verify MFA Setup
  Future<Map<String, dynamic>> verifyMFASetup(String mfaCode) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.verifyMFASetup(mfaCode);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // ✅ Update local user state with returned user
        if (data['user'] != null) {
          _user = User.fromJson(data['user']);
        }

        await Future.delayed(const Duration(milliseconds: 100));
        notifyListeners();

        return {
          'success': true,
          'onboarding_required': data['onboarding_required'] ?? false,
          'user': data['user'],
        };
      }

      _error = data['error'] ?? 'MFA setup verification failed';
      notifyListeners();
      return {'success': false, 'error': _error};
    } catch (e) {
      _error = 'Network error occurred';
      notifyListeners();
      return {'success': false, 'error': _error};
    } finally {
      _isLoading = false;
    }
  }

  // Change Password
  Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.changePassword(
        currentPassword,
        newPassword,
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        _error = data['error'] ?? 'Password change failed';
        return {'success': false, 'error': _error};
      }
    } catch (e) {
      _error = 'Network error occurred';
      return {'success': false, 'error': _error};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _apiService.logout();
    } catch (e) {
      // Silent fail - clear local storage anyway
    } finally {
      _user = null;
      _isAuthenticated = false;
      await _storageService.clearAll();
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------- GET CURRENT USER ----------------------
  Future<void> _getCurrentUser() async {
    try {
      final response = await _apiService.getCurrentUser();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['user'] != null) {
          _user = User.fromJson(data['user']);
          _isAuthenticated = true; // ONLY here
        } else {
          _user = null;
          _isAuthenticated = false; // ❗ Fix
        }
      } else if (response.statusCode == 401) {
        await logout();
        return;
      }
    } catch (e) {
      print("⚠ getCurrentUser() failed but keeping session alive: $e");
    }

    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 80));
  }

  // Forgot Password
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.forgotPassword(email);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Reset link sent'
        };
      } else {
        _error = data['error'] ?? 'Forgot password failed';
        return {'success': false, 'error': _error};
      }
    } catch (e) {
      _error = 'Network error occurred';
      return {'success': false, 'error': _error};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Store auth data
  Future<void> _storeAuthData(Map<String, dynamic> data) async {
    if (data['access_token'] != null) {
      await _storageService.writeSecure(
        AppConstants.tokenKey,
        data['access_token'].toString(),
      );
    }

    if (data['refresh_token'] != null) {
      await _storageService.writeSecure(
        AppConstants.refreshTokenKey,
        data['refresh_token'].toString(),
      );
    }

    if (data['user'] != null) {
      await _storageService.write(
        AppConstants.userDataKey,
        jsonEncode(data['user']), // always string
      );
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
