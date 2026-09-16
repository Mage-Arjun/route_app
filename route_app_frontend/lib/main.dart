import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/admin/dashboard_screen.dart';
import 'screens/driver/driver_home_screen.dart';

void main() {
  runApp(const ProviderScope(child: RouteApp()));
}

class RouteApp extends ConsumerWidget {
  const RouteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final isDriver = auth.isDriver;

    Widget home;
    if (auth.isLoading) {
      home = const _SplashScreen();
    } else if (auth.isLoggedIn) {
      home = isDriver ? const DriverHomeScreen() : const DashboardScreen();
    } else {
      home = const LoginScreen();
    }

    return MaterialApp(
      title: 'RouteOS',
      debugShowCheckedModeBanner: false,
      theme: isDriver ? AppTheme.driverTheme : AppTheme.theme,
      home: home,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.bg,
      child: const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
    );
  }
}
