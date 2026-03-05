import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/user.dart';
import '../services/auth_service.dart';
import '../platform/logger.dart';

/// Immutable auth state for the entire app.
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;

  AuthState copyWith({User? user, bool? isLoading, String? error}) => AuthState(
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );

  /// Cleared state for logout.
  AuthState cleared() => const AuthState();
}

/// Notifier that owns the auth lifecycle.
///
/// Relationships (C4):
///   AppStateStore holds auth state, reads/writes EncryptedLocalStorage.
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AuthState());

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authService.login(email, password);
      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      AppLogger.log(LogLevel.error, 'Login failed: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = state.cleared();
  }

  Future<void> refreshToken() async {
    try {
      await _authService.refreshToken();
      state = state.copyWith(user: _authService.currentUser);
    } catch (e) {
      AppLogger.log(LogLevel.warning, 'Token refresh failed: $e');
    }
  }

  /// Try to restore a previous session on app start.
  Future<void> tryRestore() async {
    state = state.copyWith(isLoading: true);
    final restored = await _authService.tryRestoreSession();
    if (restored) {
      state = AuthState(user: _authService.currentUser);
    } else {
      state = const AuthState();
    }
  }
}
