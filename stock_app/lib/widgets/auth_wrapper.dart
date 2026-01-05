import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/auth_provider.dart';
import '../screens/main_screen.dart';
import '../screens/login_screen.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // [MODIFIED] Watch authControllerProvider instead of Stream directly.
    // This allows manual state updates (like signOut setting null) to reflect IMMEDIATELY 
    // without waiting for the Stream (which avoids 'user@example.com' glitch).
    final authState = ref.watch(authControllerProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          return const MainScreen();
        }
        return const LoginScreen();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
    );
  }
}
