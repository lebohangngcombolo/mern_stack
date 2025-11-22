import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:provider/provider.dart';
import 'package:company_hub/core/services/api_service.dart';
import 'package:company_hub/presentation/providers/auth_provider.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  final Map<String, dynamic> _profileData = {};
  bool _isLoading = false;

  late final List<OnboardingStep> _steps;

  @override
  void initState() {
    super.initState();

    _steps = [
      OnboardingStep(
        title: 'Welcome to Company Hub',
        subtitle: 'Let\'s get you set up with your profile information.',
        fields: [
          OnboardingField(
            key: 'department',
            label: 'Department',
            type: FieldType.text,
            isRequired: true,
          ),
          OnboardingField(
            key: 'position',
            label: 'Position',
            type: FieldType.text,
            isRequired: true,
          ),
        ],
      ),
      OnboardingStep(
        title: 'Contact Information',
        subtitle: 'How can we reach you?',
        fields: [
          OnboardingField(
            key: 'phone',
            label: 'Phone Number',
            type: FieldType.phone,
            isRequired: false,
          ),
          OnboardingField(
            key: 'location',
            label: 'Location',
            type: FieldType.text,
            isRequired: false,
          ),
        ],
      ),
      OnboardingStep(
        title: 'Preferences',
        subtitle: 'Tell us about your work preferences.',
        fields: [
          OnboardingField(
            key: 'notifications',
            label: 'Email Notifications',
            type: FieldType.boolean,
            isRequired: false,
          ),
          OnboardingField(
            key: 'theme',
            label: 'Preferred Theme',
            type: FieldType.dropdown,
            options: ['Light', 'Dark', 'System'],
            isRequired: false,
          ),
        ],
      ),
    ];
  }

  bool get _canContinue {
    final fields = _steps[_currentStep].fields;
    for (var field in fields) {
      if (field.isRequired &&
          (_profileData[field.key] == null ||
              _profileData[field.key].toString().isEmpty)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _saveOnboarding() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await _apiService.saveOnboarding(
        _currentStep + 1,
        _profileData,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['onboarding_completed'] == true) {
          final authProvider =
              Provider.of<AuthProvider>(context, listen: false);
          await authProvider.initialize();

          if (authProvider.user!.isAdmin) {
            Navigator.pushReplacementNamed(context, '/admin-dashboard');
          } else {
            Navigator.pushReplacementNamed(context, '/user-dashboard');
          }
        } else {
          setState(() => _currentStep++);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save onboarding data.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onFieldChanged(String key, dynamic value) {
    setState(() {
      _profileData[key] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Onboarding'),
        automaticallyImplyLeading: false,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentStep + 1) / _steps.length,
              backgroundColor: Colors.grey.shade200,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step.title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(step.subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey.shade600)),
                    const SizedBox(height: 32),
                    ...step.fields.map(_buildField),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => setState(() => _currentStep--),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed:
                        (_canContinue && !_isLoading) ? _saveOnboarding : null,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_currentStep == _steps.length - 1
                            ? 'Complete'
                            : 'Continue'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(OnboardingField field) {
    switch (field.type) {
      case FieldType.text:
        return _buildTextField(field);
      case FieldType.phone:
        return _buildPhoneField(field);
      case FieldType.boolean:
        return _buildBooleanField(field);
      case FieldType.dropdown:
        return _buildDropdownField(field);
    }
  }

  Widget _buildTextField(OnboardingField field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: field.label,
          border: const OutlineInputBorder(),
        ),
        initialValue: _profileData[field.key]?.toString() ?? '',
        validator: (value) {
          if (field.isRequired && (value == null || value.isEmpty)) {
            return '${field.label} is required';
          }
          return null;
        },
        onChanged: (value) => _onFieldChanged(field.key, value),
      ),
    );
  }

  Widget _buildPhoneField(OnboardingField field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: field.label,
          border: const OutlineInputBorder(),
          prefixText: '+27 ',
        ),
        keyboardType: TextInputType.phone,
        initialValue: _profileData[field.key]?.toString() ?? '',
        onChanged: (value) => _onFieldChanged(field.key, value),
      ),
    );
  }

  Widget _buildBooleanField(OnboardingField field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Text(field.label),
          const Spacer(),
          Switch(
            value: _profileData[field.key] ?? false,
            onChanged: (value) => _onFieldChanged(field.key, value),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(OnboardingField field) {
    final value = _profileData[field.key] ?? field.options?.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: field.label,
          border: const OutlineInputBorder(),
        ),
        value: value,
        items: field.options
            ?.map((option) =>
                DropdownMenuItem(value: option, child: Text(option)))
            .toList(),
        onChanged: (val) => _onFieldChanged(field.key, val),
      ),
    );
  }
}

class OnboardingStep {
  final String title;
  final String subtitle;
  final List<OnboardingField> fields;

  const OnboardingStep({
    required this.title,
    required this.subtitle,
    required this.fields,
  });
}

class OnboardingField {
  final String key;
  final String label;
  final FieldType type;
  final bool isRequired;
  final List<String>? options;

  const OnboardingField({
    required this.key,
    required this.label,
    required this.type,
    required this.isRequired,
    this.options,
  });
}

enum FieldType { text, phone, boolean, dropdown }
