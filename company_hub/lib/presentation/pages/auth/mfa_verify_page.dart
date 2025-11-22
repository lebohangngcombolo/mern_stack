// lib/presentation/pages/auth/mfa_verify_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:company_hub/presentation/providers/auth_provider.dart';
import 'package:company_hub/presentation/widgets/custom_text_field.dart';

class MFAVerifyPage extends StatefulWidget {
  final String userId;
  final bool isFirstTime;

  const MFAVerifyPage({
    super.key,
    required this.userId,
    this.isFirstTime = false,
  });

  @override
  State<MFAVerifyPage> createState() => _MFAVerifyPageState();
}

class _MFAVerifyPageState extends State<MFAVerifyPage> {
  final _mfaCodeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyMFA() async {
    if (_mfaCodeController.text.isEmpty) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await authProvider.verifyMFA(_mfaCodeController.text);

    // ✅ DON'T set loading to false here - wait for navigation

    if (result['success'] == true) {
      // ✅ Use the onboarding_required directly from the result
      final onboardingRequired = result['onboarding_required'] ?? true;

      if (onboardingRequired) {
        Navigator.pushReplacementNamed(context, '/onboarding');
      } else {
        // ✅ Use the updated user state from auth provider
        if (authProvider.user!.isAdmin) {
          Navigator.pushReplacementNamed(context, '/admin-dashboard');
        } else {
          Navigator.pushReplacementNamed(context, '/user-dashboard');
        }
      }
    } else {
      // ✅ Only set loading to false on error
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'MFA verification failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateBasedOnUserState(
      AuthProvider authProvider, Map<String, dynamic> result) {
    final user = authProvider.user!;

    // ✅ Use the onboarding_required flag from backend response
    if (result['onboarding_required'] == true) {
      Navigator.pushReplacementNamed(context, '/onboarding');
    } else if (user.isAdmin) {
      Navigator.pushReplacementNamed(context, '/admin-dashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/user-dashboard');
    }
  }

  // ✅ Add debug method to check state (remove after testing)
  void _debugCheckState() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    print('🔍 DEBUG - User authenticated: ${authProvider.isAuthenticated}');
    print('🔍 DEBUG - User: ${authProvider.user?.toJson()}');
  }

  @override
  void initState() {
    super.initState();
    // Call debug on init to see initial state
    WidgetsBinding.instance.addPostFrameCallback((_) => _debugCheckState());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/dark.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header with logos
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset(
                      'assets/images/logo3.png',
                      width: 280,
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                    Image.asset(
                      'assets/images/logow.png',
                      width: 280,
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Main content
                Column(
                  children: [
                    Image.asset(
                      'assets/images/logo2.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Multi-Factor Authentication',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 10,
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(2, 2),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Enter the 6-digit code from your authenticator app',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        shadows: [
                          Shadow(
                            blurRadius: 5,
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(1, 1),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Code Input with red line styling
                SizedBox(
                  width: 300,
                  child: CustomTextField(
                    controller: _mfaCodeController,
                    label: '6-digit code',
                    prefixIcon: Icons.security,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    fillColor: Colors.transparent,
                    borderColor: Colors.transparent,
                    textStyle: const TextStyle(color: Colors.white),
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                    iconColor: Colors.white.withOpacity(0.8),
                    onChanged: (value) {
                      if (value.length == 6) {
                        _verifyMFA();
                      }
                    },
                  ),
                ),

                // Red line divider
                SizedBox(
                  width: 300,
                  child: Container(
                    height: 1,
                    color: Colors.red,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),

                const SizedBox(height: 24),

                // Red Verify Button - smaller width
                SizedBox(
                  width: 200,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyMFA,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 3,
                      shadowColor: Colors.black.withOpacity(0.3),
                      minimumSize: const Size(0, 40),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Verify',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Help Text
                SizedBox(
                  width: 300,
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Need Help?'),
                                content: const Text(
                                  'Open your authenticator app (Google Authenticator, Authy, etc.) and enter the 6-digit code displayed for Company Hub.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      'Having trouble?',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                // ✅ Debug button (remove after testing)
                if (!_isLoading) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 200,
                    child: OutlinedButton(
                      onPressed: _debugCheckState,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.5)),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        'Debug Check State',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mfaCodeController.dispose();
    super.dispose();
  }
}
