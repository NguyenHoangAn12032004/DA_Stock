import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/auth_wrapper.dart';
import 'firebase_options.dart'; 
import 'core/services/notification_service.dart';

import 'presentation/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
     print("Firebase initialization error: $e");
  }

  // Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox('settings');

  // Initialize Notifications
  await NotificationService().initialize();

  final prefs = await SharedPreferences.getInstance();
  final showOnboarding = prefs.getBool('showOnboarding') ?? true;

  runApp(
    ProviderScope(
      child: MyApp(showOnboarding: showOnboarding),
    ),
  );
}

class MyApp extends ConsumerWidget {
  final bool showOnboarding;

  const MyApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);
    
    return themeMode.when(
      data: (mode) => MaterialApp(
        title: 'Stock App Graduation Project',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: mode,
        home: showOnboarding ? const OnboardingScreen() : const AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
      loading: () => const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator()))),
      error: (_, __) => const MaterialApp(home: Scaffold(body: Center(child: Text('Error loading theme')))),
    );
  }
}

