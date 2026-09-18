import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/preferences_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/admin/dashboard_screen.dart';
import 'screens/driver/driver_home_screen.dart';

void main() {
  // ProviderScope makes authentication, preferences, and ApiService available
  // to every screen without passing them through widget constructors.
  runApp(const ProviderScope(child: RouteApp()));
}

class RouteApp extends ConsumerWidget {
  const RouteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This is the only top-level navigation decision. Individual screens
    // should not decide which role home to display.
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

    // ThemeMode is persisted by PreferencesNotifier and applied app-wide here.
    final preferences = ref.watch(preferencesProvider);
    return MaterialApp(
      title: 'RouteOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: preferences.themeMode,
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
