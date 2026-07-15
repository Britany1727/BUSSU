import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_roles.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/routing/role_guard.dart';
import '../../../../core/security/device_binding_service.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/recover_password_usecase.dart';
import '../../domain/usecases/refresh_session_usecase.dart';
import '../../domain/usecases/register_usecase.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final AppUser? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((_) {
  throw UnimplementedError('Registra AuthRepository en injection_container');
});

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.watch(authRepositoryProvider));
});

final registerUseCaseProvider = Provider<RegisterUseCase>((ref) {
  return RegisterUseCase(ref.watch(authRepositoryProvider));
});

final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  return LogoutUseCase(ref.watch(authRepositoryProvider));
});

final recoverPasswordUseCaseProvider = Provider<RecoverPasswordUseCase>((ref) {
  return RecoverPasswordUseCase(ref.watch(authRepositoryProvider));
});

final refreshSessionUseCaseProvider = Provider<RefreshSessionUseCase>((ref) {
  return RefreshSessionUseCase(ref.watch(authRepositoryProvider));
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final DeviceBindingService _deviceBinding;
  StreamSubscription<AppUser?>? _authSubscription;

  AuthNotifier(this._repository, this._deviceBinding)
      : super(const AuthState()) {
    _init();
  }

  void _init() {
    _authSubscription = _repository.onAuthStateChanged.listen((user) {
      if (user != null) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          clearError: true,
        );
      notifyAuthStateChanged(user.role);
      unawaited(_performDeviceBinding(user));
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          user: null,
          clearError: true,
        );
        notifyAuthStateChanged(null);
      }
    });
  }

  Future<void> checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.loading);

    final user = await _repository.getCurrentUser();

    if (user != null) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        clearError: true,
      );
      notifyAuthStateChanged(user.role);
      unawaited(_performDeviceBinding(user));
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    final usecase = LoginUseCase(_repository);
    final result = await usecase.execute(email: email, password: password);

    result.fold(
      (failure) => state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: failure.message,
      ),
      (user) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          clearError: true,
        );
        notifyAuthStateChanged(user.role);
      },
    );
  }

  Future<void> register({
    required String email,
    required String password,
    required String confirmPassword,
    required String fullName,
    required UserRole role,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    final usecase = RegisterUseCase(_repository);
    final result = await usecase.execute(
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      fullName: fullName,
      role: role,
    );

    result.fold(
      (failure) {
        if (failure is EmailConfirmationPendingFailure) {
          // Registro exitoso, pero requiere confirmación de correo
          state = state.copyWith(
            status: AuthStatus.unauthenticated,
            errorMessage: failure.message,
          );
        } else {
          state = state.copyWith(
            status: AuthStatus.unauthenticated,
            errorMessage: failure.message,
          );
        }
      },
      (user) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          clearError: true,
        );
        notifyAuthStateChanged(user.role);
      },
    );
  }

  Future<void> logout() async {
    final usecase = LogoutUseCase(_repository);
    await usecase.execute();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> recoverPassword(String email) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    final usecase = RecoverPasswordUseCase(_repository);
    final result = await usecase.execute(email);

    result.fold(
      (failure) => state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: failure.message,
      ),
      (_) => state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Correo de recuperación enviado.',
      ),
    );
  }

  Future<void> refreshSession() async {
    final usecase = RefreshSessionUseCase(_repository);
    await usecase.execute();
  }

  Future<void> _performDeviceBinding(AppUser user) async {
    try {
      final currentFingerprint = await _deviceBinding.getHardwareId();

      if (user.deviceId == null || user.deviceId!.isEmpty) {
        await _repository.updateDeviceId(currentFingerprint);
      } else {
        await _deviceBinding.validateDeviceBinding(user.deviceId!);
      }
    } catch (_) {
      // Device binding failed
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(deviceBindingServiceProvider),
  );
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authNotifierProvider).status == AuthStatus.authenticated;
});

final isAuthLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authNotifierProvider).status == AuthStatus.loading;
});

final authErrorMessageProvider = Provider<String?>((ref) {
  return ref.watch(authNotifierProvider).errorMessage;
});

final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authNotifierProvider).user;
});
