import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/api.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/preferences_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _serverController;
  bool _checking = false;
  String? _connectionMessage;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _serverController = TextEditingController(text: ApiConfig.initialBaseUrl);
    ApiClient().getBaseUrl().then((url) {
      if (mounted) _serverController.text = url;
    });
  }

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    setState(() {
      _checking = true;
      _connectionMessage = null;
    });
    try {
      final url = _serverController.text.trim();
      await ApiClient().updateBaseUrl(url);
      final response = await ApiClient().dio.get('/health');
      setState(() {
        _connected = response.data['status'] == 'ok';
        _connectionMessage = _connected
            ? 'Connected to RouteOS API'
            : 'API is degraded';
      });
    } catch (_) {
      setState(() {
        _connected = false;
        _connectionMessage = 'Could not reach this server';
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _section('Appearance'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Theme',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode),
                      ),
                    ],
                    selected: {prefs.themeMode},
                    onSelectionChanged: (value) => ref
                        .read(preferencesProvider.notifier)
                        .setThemeMode(value.first),
                  ),
                ],
              ),
            ),
          ),
          _section('Operations'),
          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  subtitle: const Text('Trip, approval, and delivery updates'),
                  value: prefs.notificationsEnabled,
                  onChanged: (value) => ref
                      .read(preferencesProvider.notifier)
                      .setNotificationsEnabled(value),
                ),
                SwitchListTile.adaptive(
                  secondary: const Icon(Icons.location_on_outlined),
                  title: const Text('Live location sharing'),
                  subtitle: const Text(
                    'Share GPS with your operations team during trips',
                  ),
                  value: prefs.locationSharingEnabled,
                  onChanged: (value) => ref
                      .read(preferencesProvider.notifier)
                      .setLocationSharingEnabled(value),
                ),
              ],
            ),
          ),
          _section('Server connection'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _serverController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'API base URL',
                      hintText: 'http://192.168.1.20:8000',
                      prefixIcon: Icon(Icons.dns_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _checking ? null : _checkConnection,
                      icon: _checking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_tethering),
                      label: Text(
                        _checking ? 'Checking…' : 'Save & test connection',
                      ),
                    ),
                  ),
                  if (_connectionMessage != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          _connected ? Icons.check_circle : Icons.error_outline,
                          color: _connected ? AppTheme.success : AppTheme.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _connectionMessage!,
                          style: TextStyle(
                            color: _connected
                                ? AppTheme.success
                                : AppTheme.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          _section('Account'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.error),
              title: const Text('Sign out'),
              subtitle: const Text('Remove this device session'),
              onTap: () => ref.read(authProvider.notifier).logout(),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'RouteOS 2.1.0 · Operations platform',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: AppTheme.primary,
      ),
    ),
  );
}
