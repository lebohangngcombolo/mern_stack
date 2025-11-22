// lib/presentation/pages/auth/mfa_setup_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:company_hub/presentation/providers/auth_provider.dart';
import 'package:company_hub/presentation/widgets/custom_text_field.dart';

class MFASetupPage extends StatefulWidget {
  const MFASetupPage({super.key});

  @override
  State<MFASetupPage> createState() => _MFASetupPageState();
}

class _MFASetupPageState extends State<MFASetupPage> {
  final _mfaCodeController = TextEditingController();
  String? _mfaSecret;
  String? _provisioningUri;
  String? _qrCode;
  bool _isLoading = false;
  bool _showVerification = false;

  @override
  void initState() {
    super.initState();
    _setupMFA();
  }

  Future<void> _setupMFA() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await authProvider.setupMFA();

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      setState(() {
        _mfaSecret = result['data']['mfa_secret'];
        _provisioningUri = result['data']['provisioning_uri'];
        _qrCode = result['data']['qr_code'];
        _showVerification = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to setup MFA'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _verifyMFASetup() async {
    if (_mfaCodeController.text.isEmpty) return;

    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final result = await authProvider.verifyMFASetup(_mfaCodeController.text);

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('MFA setup completed!'),
            backgroundColor: Colors.green),
      );

      // Navigate to onboarding
      Navigator.pushReplacementNamed(context, '/onboarding');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result['error'] ?? 'MFA verification failed'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup MFA'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Prevent going back
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('MFA setup is required'),
                backgroundColor: Colors.orange,
              ),
            );
          },
        ),
      ),
      body: _isLoading && !_showVerification
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  const Icon(Icons.security, size: 80, color: Colors.blue),
                  const SizedBox(height: 20),
                  Text(
                    'Setup Multi-Factor Authentication',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Scan the QR code with your authenticator app (Google Authenticator, Authy, etc.)',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // QR Code
                  if (_qrCode != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            QrImageView(
                              data: _provisioningUri!,
                              version: QrVersions.auto,
                              size: 200,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Or enter this code manually:',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SelectableText(
                                _mfaSecret!,
                                style: const TextStyle(
                                  fontFamily: 'Monospace',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                  // Verification Section
                  if (_showVerification) ...[
                    Text(
                      'Enter verification code',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _mfaCodeController,
                      label: '6-digit code',
                      prefixIcon: Icons.security,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _verifyMFASetup,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Verify and Continue'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
