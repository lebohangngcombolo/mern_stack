// lib/presentation/pages/auth/login_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:company_hub/presentation/providers/auth_provider.dart';
import 'package:company_hub/presentation/widgets/custom_text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    setState(() {
      authProvider.clearError();
    });

    print('Starting login for: ${_emailController.text}');

    final result = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    print('Login result: $result');

    if (result['success'] == true) {
      // MFA flow
      if (result['mfa_required'] == true) {
        final userId = result['user_id'].toString();
        Navigator.pushReplacementNamed(
          context,
          '/mfa-verify',
          arguments: {'user_id': userId, 'is_first_time': false},
        );
        return;
      }

      // First login flow
      if (result['first_login'] == true) {
        final userId = result['user_id'].toString();
        _showChangePasswordDialog(userId);
        return;
      }

      // Onboarding flow
      if (result['onboarding_required'] == true) {
        Navigator.pushReplacementNamed(context, '/onboarding');
        return;
      }

      // Regular login
      if (authProvider.user == null) {
        print('User null after login, initializing...');
        await authProvider.initialize(); // fetch user if null
      }

      final user = authProvider.user;

      if (user != null) {
        if (user.isAdmin || user.isSuperAdmin) {
          Navigator.pushReplacementNamed(context, '/admin-dashboard');
        } else {
          Navigator.pushReplacementNamed(context, '/user-dashboard');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Unable to fetch user information. Please login again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result['error'] ?? 'Login failed'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _showChangePasswordDialog(String userId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ChangePasswordDialog(userId: userId),
    );
  }

  void _forgotPassword() {
    showDialog(
        context: context, builder: (context) => const ForgotPasswordDialog());
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

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
            child: Form(
              key: _formKey,
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
                  const SizedBox(height: 80),
                  Column(
                    children: [
                      Image.asset(
                        'assets/images/logo2.png',
                        width: 320,
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Company Hub',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
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
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to your account',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          shadows: [
                            Shadow(
                              blurRadius: 5,
                              color: Colors.black.withOpacity(0.3),
                              offset: const Offset(1, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Email field with decreased width
                  SizedBox(
                    width: 300, // Decreased width
                    child: CustomTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      prefixIcon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      fillColor: Colors.transparent,
                      borderColor: Colors.transparent,
                      textStyle: const TextStyle(color: Colors.white),
                      labelStyle:
                          TextStyle(color: Colors.white.withOpacity(0.8)),
                      iconColor: Colors.white.withOpacity(0.8),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Please enter your email';
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value))
                          return 'Please enter a valid email';
                        return null;
                      },
                    ),
                  ),

                  // Red line divider
                  SizedBox(
                    width: 300, // Same width as text field
                    child: Container(
                      height: 1,
                      color: Colors.red,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Password field with decreased width
                  SizedBox(
                    width: 300, // Decreased width
                    child: CustomTextField(
                      controller: _passwordController,
                      label: 'Password',
                      prefixIcon: Icons.lock,
                      obscureText: _obscurePassword,
                      fillColor: Colors.transparent,
                      borderColor: Colors.transparent,
                      textStyle: const TextStyle(color: Colors.white),
                      labelStyle:
                          TextStyle(color: Colors.white.withOpacity(0.8)),
                      iconColor: Colors.white.withOpacity(0.8),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off),
                        color: Colors.white.withOpacity(0.8),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Please enter your password';
                        return null;
                      },
                    ),
                  ),

                  // Red line divider
                  SizedBox(
                    width: 300, // Same width as text field
                    child: Container(
                      height: 1,
                      color: Colors.red,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),

                  const SizedBox(height: 8),
                  SizedBox(
                    width: 300, // Same width as text field
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgotPassword,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Red Sign In button - smaller width
                  SizedBox(
                    width: 200,
                    child: ElevatedButton(
                      onPressed: authProvider.isLoading ? null : _login,
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
                      child: authProvider.isLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Sign In',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // SSO Section with red divider
                  SizedBox(
                    width: 300,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.red,
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Enterprise SSO',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.red,
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Red Microsoft SSO button - smaller width
                  SizedBox(
                    width: 250,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Add Microsoft SSO logic here
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 3,
                        minimumSize: const Size(0, 40),
                      ),
                      icon: Image.asset(
                        'assets/images/micro.png',
                        width: 20,
                        height: 20,
                      ),
                      label: const Text(
                        'Sign in with Microsoft',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  if (authProvider.error != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 300,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          authProvider.error!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =======================
// Change Password Dialog
// =======================
class ChangePasswordDialog extends StatefulWidget {
  final String userId;
  const ChangePasswordDialog({super.key, required this.userId});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await authProvider.changePassword(
      _currentPasswordController.text,
      _newPasswordController.text,
    );

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      Navigator.of(context).pop();
      Navigator.pushReplacementNamed(context, '/mfa-setup');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result['error'] ?? 'Password change failed'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This is your first login. Please change your temporary password.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _currentPasswordController,
              label: 'Temporary Password',
              obscureText: _obscureCurrentPassword,
              prefixIcon: Icons.lock,
              suffixIcon: IconButton(
                icon: Icon(_obscureCurrentPassword
                    ? Icons.visibility
                    : Icons.visibility_off),
                onPressed: () => setState(
                    () => _obscureCurrentPassword = !_obscureCurrentPassword),
              ),
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Please enter your temporary password'
                  : null,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _newPasswordController,
              label: 'New Password',
              obscureText: _obscureNewPassword,
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(_obscureNewPassword
                    ? Icons.visibility
                    : Icons.visibility_off),
                onPressed: () =>
                    setState(() => _obscureNewPassword = !_obscureNewPassword),
              ),
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Please enter a new password';
                if (value.length < 8)
                  return 'Password must be at least 8 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _confirmPasswordController,
              label: 'Confirm New Password',
              obscureText: _obscureConfirmPassword,
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPassword
                    ? Icons.visibility
                    : Icons.visibility_off),
                onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
              validator: (value) => (value != _newPasswordController.text)
                  ? 'Passwords do not match'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _changePassword,
          child: _isLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Change Password'),
        ),
      ],
    );
  }
}

// =======================
// Forgot Password Dialog
// =======================
class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendResetLink() async {
    if (_emailController.text.isEmpty) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final response =
        await authProvider.forgotPassword(_emailController.text.trim());

    setState(() => _isLoading = false);

    if (response['success'] == true) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password reset instructions sent to your email'),
            backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(response['error'] ?? 'Failed to send reset link'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Enter your email address and we will send you instructions to reset your password.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _emailController,
            label: 'Email Address',
            prefixIcon: Icons.email,
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendResetLink,
          child: _isLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Send Reset Link'),
        ),
      ],
    );
  }
}
