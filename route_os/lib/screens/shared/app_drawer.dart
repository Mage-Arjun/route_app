import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../admin/dashboard_screen.dart';
import '../driver/driver_profile_screen.dart';
import '../driver/driver_home_screen.dart';
import '../admin/map_screen.dart';
import '../admin/live_tracking_screen.dart';
import '../admin/route_list_screen.dart';
import '../admin/customer_list_screen.dart';
import '../admin/vehicle_list_screen.dart';
import 'settings_screen.dart';

class AppDrawer extends ConsumerWidget {
  final bool isDriver;
  const AppDrawer({super.key, required this.isDriver});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF0E6B51)),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  (user?.name ?? 'R')[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    color: Color(0xFF0E6B51),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              accountName: Text(user?.name ?? 'RouteOS user'),
              accountEmail: Text(user?.email ?? ''),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => isDriver
                        ? const DriverHomeScreen()
                        : const DashboardScreen(),
                  ),
                );
              },
            ),
            if (!isDriver) ...[
              ListTile(
                leading: const Icon(Icons.route_outlined),
                title: const Text('Routes'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RouteListScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('Customers'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerListScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: const Text('Fleet'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VehicleListScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('Operations Map'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MapScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.my_location_outlined),
                title: const Text('Live Tracking'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LiveTrackingScreen(),
                    ),
                  );
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DriverProfileScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Sign out'),
              onTap: () => ref.read(authProvider.notifier).logout(),
            ),
          ],
        ),
      ),
    );
  }
}
