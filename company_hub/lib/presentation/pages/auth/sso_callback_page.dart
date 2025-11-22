// lib/presentation/pages/auth/sso_callback_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:company_hub/presentation/providers/auth_provider.dart';
import 'package:company_hub/core/services/storage_service.dart';

class SSOCallbackPage extends StatefulWidget {
  const SSOCallbackPage({super.key});

  @override
  State<SSOCallbackPage> createState() => _SSOCallbackPageState();
}

class _SSOCallbackPageState extends State<SSOCallbackPage> {
  bool _isProcessing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _processSSOCallback();
  }

  Future<void> _processSSOCallback() async {
    try {
      // Get the URL parameters
      final uri = Uri.base;
      final accessToken = uri.queryParameters['access_token'];
      final refreshToken = uri.queryParameters['refresh_token'];

      if (accessToken != null) {
        final storage = StorageService();

        // Store the tokens
        await storage.writeSecure('auth_token', accessToken);
        if (refreshToken != null) {
          await storage.writeSecure('refresh_token', refreshToken);
        }

        // Initialize auth provider to get user data
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.initialize();

        // Redirect to appropriate page
        if (authProvider.isAuthenticated) {
          if (authProvider.user!.onboardingCompleted) {
            if (authProvider.user!.isAdmin) {
              Navigator.pushReplacementNamed(context, '/admin-dashboard');
            } else {
              Navigator.pushReplacementNamed(context, '/user-dashboard');
            }
          } else {
            Navigator.pushReplacementNamed(context, '/onboarding');
          }
        } else {
          setState(() {
            _error = 'Authentication failed';
            _isProcessing = false;
          });
        }
      } else {
        setState(() {
          _error = 'No access token provided';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'SSO processing failed: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isProcessing) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text(
                'Signing you in...',
                style: TextStyle(fontSize: 16),
              ),
            ] else if (_error != null) ...[
              const Icon(Icons.error, color: Colors.red, size: 50),
              const SizedBox(height: 20),
              Text(
                'Error: $_error',
                style: const TextStyle(fontSize: 16, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: const Text('Return to Login'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
