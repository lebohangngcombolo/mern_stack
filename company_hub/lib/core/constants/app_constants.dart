// lib/core/constants/app_constants.dart
class AppConstants {
  static const String appName = 'Company Hub';
  static const String appVersion = '1.0.0';

  // Base URLs
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://the-hub-92vl.onrender.com',
  );
  static const String apiUrl = '$baseUrl/api';

  // Auth Endpoints
  static const String login = '$apiUrl/auth/login';
  static const String logout = '$apiUrl/auth/logout';
  static const String refreshToken = '$apiUrl/auth/refresh';
  static const String changePassword = '$apiUrl/auth/change-password';
  static const String forgotPassword = '$apiUrl/auth/forgot-password';
  static const String resetPassword = '$apiUrl/auth/reset-password';
  static const String setupMfa = '$apiUrl/auth/setup-mfa';
  static const String verifyMfa = '$apiUrl/auth/verify-mfa';
  static const String verifyMfaSetup = '$apiUrl/auth/verify-mfa-setup';

  // Admin Endpoints
  static const String adminDashboard = '$apiUrl/admin/dashboard';
  static const String getUsers = '$apiUrl/admin/users';
  static const String enrollUser = '$apiUrl/admin/users/enroll';
  static const String updateUser =
      '$apiUrl/admin/users'; // append /{id} for PUT
  static const String auditLogs = '$apiUrl/admin/audit-logs';
  static const String companyApps = '$apiUrl/admin/apps';

  // User Endpoints
  static const String userDashboard = '$apiUrl/user/dashboard';
  static const String getProfile = '$apiUrl/user/profile';
  static const String updateProfile = '$apiUrl/user/profile';
  static const String getOnboarding = '$apiUrl/user/onboarding';
  static const String saveOnboarding = '$apiUrl/user/onboarding';

  // SSO Endpoints
  static const String generateSsoToken = '$apiUrl/sso/generate-token';
  static const String validateSsoToken = '$apiUrl/sso/validate';

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';

  // App Routes
  static const String loginRoute = '/login';
  static const String dashboardRoute = '/dashboard';
  static const String adminDashboardRoute = '/admin-dashboard';
  static const String profileRoute = '/profile';
  static const String onboardingRoute = '/onboarding';
  static const String mfaSetupRoute = '/mfa-setup';
  static const String mfaVerifyRoute = '/mfa-verify';
}
