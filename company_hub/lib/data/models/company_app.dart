// lib/data/models/company_app.dart
class CompanyApp {
  final int id;
  final String name;
  final String description;
  final String appUrl;
  final bool isActive;

  CompanyApp({
    required this.id,
    required this.name,
    required this.description,
    required this.appUrl,
    required this.isActive,
  });

  factory CompanyApp.fromJson(Map<String, dynamic> json) {
    return CompanyApp(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      appUrl: json['app_url'],
      isActive: json['is_active'],
    );
  }
}
