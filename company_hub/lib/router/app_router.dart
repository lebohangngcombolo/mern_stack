// lib/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:company_hub/presentation/pages/auth/login_page.dart';
import 'package:company_hub/presentation/pages/auth/mfa_setup_page.dart';
import 'package:company_hub/presentation/pages/auth/mfa_verify_page.dart';
import 'package:company_hub/presentation/pages/dashboard/admin_dashboard_page.dart';
import 'package:company_hub/presentation/pages/dashboard/user_dashboard_page.dart';
import 'package:company_hub/presentation/pages/onboarding/onboarding_page.dart';
import 'package:company_hub/presentation/pages/profile/profile_page.dart';
import 'package:company_hub/presentation/pages/splash_page.dart';
import 'package:company_hub/presentation/pages/auth/sso_callback_page.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const SplashPage());
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case '/mfa-setup':
        return MaterialPageRoute(builder: (_) => const MFASetupPage());
      case '/mfa-verify':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => MFAVerifyPage(
            userId: args['user_id'],
            isFirstTime: args['is_first_time'] ?? false,
          ),
        );
      case '/onboarding':
        return MaterialPageRoute(builder: (_) => const OnboardingPage());
      case '/user-dashboard':
        return MaterialPageRoute(builder: (_) => const UserDashboardPage());
      case '/sso-callback': // ADD THIS ROUTE
        return MaterialPageRoute(builder: (_) => const SSOCallbackPage());
      case '/admin-dashboard':
        return MaterialPageRoute(builder: (_) => const AdminDashboardPage());
      case '/profile':
        return MaterialPageRoute(builder: (_) => const ProfilePage());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
