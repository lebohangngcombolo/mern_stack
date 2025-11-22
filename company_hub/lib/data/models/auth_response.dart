// lib/data/models/auth_response.dart
import 'user_model.dart';

class AuthResponse {
  final String? accessToken;
  final String? refreshToken;
  final User? user;
  final bool? mfaRequired;
  final bool? firstLogin;
  final String? mfaSessionToken;
  final String? firstLoginToken;
  final bool? onboardingRequired;
  final String? dashboard;

  AuthResponse({
    this.accessToken,
    this.refreshToken,
    this.user,
    this.mfaRequired,
    this.firstLogin,
    this.mfaSessionToken,
    this.firstLoginToken,
    this.onboardingRequired,
    this.dashboard,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'],
      refreshToken: json['refresh_token'],
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      mfaRequired: json['mfa_required'],
      firstLogin: json['first_login'],
      mfaSessionToken: json['mfa_session_token'],
      firstLoginToken: json['first_login_token'],
      onboardingRequired: json['onboarding_required'],
      dashboard: json['dashboard'],
    );
  }
}
