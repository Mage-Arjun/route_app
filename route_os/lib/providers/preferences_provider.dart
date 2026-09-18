import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final preferencesProvider =
    StateNotifierProvider<PreferencesNotifier, AppPreferences>((ref) {
      return PreferencesNotifier();
    });

class AppPreferences {
  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final bool locationSharingEnabled;

  const AppPreferences({
    this.themeMode = ThemeMode.system,
    this.notificationsEnabled = true,
    this.locationSharingEnabled = true,
  });

  AppPreferences copyWith({
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    bool? locationSharingEnabled,
  }) => AppPreferences(
    themeMode: themeMode ?? this.themeMode,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    locationSharingEnabled:
        locationSharingEnabled ?? this.locationSharingEnabled,
  );
}

class PreferencesNotifier extends StateNotifier<AppPreferences> {
  static const _storage = FlutterSecureStorage();

  PreferencesNotifier() : super(const AppPreferences()) {
    _restore();
  }

  Future<void> _restore() async {
    final savedTheme = await _storage.read(key: 'theme_mode');
    final notifications = await _storage.read(key: 'notifications_enabled');
    final location = await _storage.read(key: 'location_sharing_enabled');
    if (!mounted) return;
    state = state.copyWith(
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == savedTheme,
        orElse: () => ThemeMode.system,
      ),
      notificationsEnabled: notifications != 'false',
      locationSharingEnabled: location != 'false',
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _storage.write(key: 'theme_mode', value: mode.name);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    state = state.copyWith(notificationsEnabled: value);
    await _storage.write(key: 'notifications_enabled', value: value.toString());
  }

  Future<void> setLocationSharingEnabled(bool value) async {
    state = state.copyWith(locationSharingEnabled: value);
    await _storage.write(
      key: 'location_sharing_enabled',
      value: value.toString(),
    );
  }
}
