import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api.dart';
import '../models/user.dart';
import '../services/api_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiServiceProvider));
});

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  AuthState({this.user, this.isLoading = false, this.error});

  AuthState copyWith({User? user, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isLoggedIn => user != null;
  bool get isAdmin => user?.isAdmin ?? false;
  bool get isDriver => user?.isDriver ?? false;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api;
  final _client = ApiClient();

  AuthNotifier(this._api) : super(AuthState()) {
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final token = await _client.getToken();
    if (token == null) {
      state = state.copyWith(isLoading: false);
      return;
    }
    try {
      final user = await _api.getMe();
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      await _client.clearToken();
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _api.login(email, password);
      await _client.saveToken(result['access_token']);
      final user = User.fromJson(result['user']);
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Invalid email or password');
    }
  }

  Future<void> logout() async {
    await _client.clearToken();
    state = AuthState();
  }

  void updateUser(User user) {
    state = state.copyWith(user: user);
  }
}
