import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/widgets/auth_wrapper.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';

import 'core/theme/premium_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Configure Firebase App Check with debug provider for development
  await setupAppCheck();

  runApp(MyApp());
}

Future<void> setupAppCheck() async {
  // ... (existing implementation)
  try {
    if (kDebugMode) {
      // Development mode - Use debug provider
      print('🛠️ Setting up App Check in DEBUG mode');

      // Simply activate debug provider without trying to get token
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
      );

      print('✅ Firebase App Check (Debug) initialized successfully');
      print(
        '📋 If you need to register a new debug token, check the Android logs for:',
      );
      print(
        '   "Enter this debug secret into the allow list in the Firebase Console"',
      );
    } else {
      // Production mode - Use Play Integrity
      print('🚀 Setting up App Check in PRODUCTION mode');
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
      );
      print('✅ Firebase App Check (Production) initialized successfully');
    }
  } catch (e) {
    print('❌ Firebase App Check initialization failed: $e');
    print('⚠️ Continuing without App Check...');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<DatabaseService>(create: (_) => DatabaseService()),
      ],
      child: MaterialApp(
        title: 'School Bus',
        theme: PremiumTheme.themeData,
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
