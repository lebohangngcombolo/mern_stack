// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:company_hub/core/services/storage_service.dart';
import 'package:company_hub/presentation/providers/auth_provider.dart';
import 'package:company_hub/presentation/themes/app_theme.dart';
import 'package:company_hub/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await StorageService().init();

  runApp(const CompanyHubApp());
}

class CompanyHubApp extends StatelessWidget {
  const CompanyHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: MaterialApp(
        title: 'Company Hub',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        onGenerateRoute: AppRouter.generateRoute,
        initialRoute: '/',
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
