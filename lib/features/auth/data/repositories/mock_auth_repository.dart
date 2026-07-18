import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/constants/app_roles.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Repositorio de autenticación mock para desarrollo sin Supabase.
///
/// Acepta cualquier email con contraseña '12345678'.
/// El rol se asigna según el prefijo del email:
///   - admin@ → municipal_admin
///   - coop@ → cooperativa_admin
///   - driver@ → conductor
///   - cualquier otro → usuario
///
/// Se activa automáticamente en debug cuando Supabase no está disponible,
/// controlado por [Env.enableMockAuth].
class MockAuthRepository implements AuthRepository {
  final StreamController<AppUser?> _authController =
      StreamController<AppUser?>.broadcast();

  AppUser? _currentUser;

  @override
  Future<Either<Failure, AppUser>> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (password != '12345678') {
      return const Left(AuthFailure('Credenciales inválidas. '
          'Usa contraseña: 12345678'));
    }

    final user = _createUser(email);
    _currentUser = user;
    _authController.add(user);

    return Right(user);
  }

  @override
  Future<Either<Failure, AppUser>> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));

    final user = AppUser(
      id: 'mock-${email.hashCode}',
      email: email,
      fullName: fullName,
      role: role,
      isPremium: false,
      createdAt: DateTime.now(),
    );

    _currentUser = user;
    _authController.add(user);

    return Right(user);
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    _currentUser = null;
    _authController.add(null);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> resetPassword(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return const Right(null);
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    return _currentUser;
  }

  @override
  Stream<AppUser?> get onAuthStateChanged => _authController.stream;

  @override
  Future<String?> get accessToken async => 'mock-token-${DateTime.now().millisecondsSinceEpoch}';

  @override
  Future<Either<Failure, void>> refreshSession() async {
    if (_currentUser != null) {
      _authController.add(_currentUser);
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> updateDeviceId(String deviceId) async {
    return const Right(null);
  }

  AppUser _createUser(String email) {
    final role = _resolveRole(email);
    final name = _resolveName(email, role);

    return AppUser(
      id: 'mock-${email.hashCode}',
      email: email,
      fullName: name,
      role: role,
      isPremium: email.contains('premium'),
      deviceId: null,
      createdAt: DateTime.now(),
    );
  }

  UserRole _resolveRole(String email) {
    final lower = email.toLowerCase();
    if (lower.startsWith('admin@') || lower.startsWith('municipal@')) {
      return UserRole.municipalAdmin;
    }
    if (lower.startsWith('coop@') || lower.startsWith('cooperativa@')) {
      return UserRole.cooperativaAdmin;
    }
    if (lower.startsWith('driver@') || lower.startsWith('conductor@')) {
      return UserRole.conductor;
    }
    if (lower.startsWith('premium@')) {
      return UserRole.usuario;
    }
    return UserRole.usuario;
  }

  String _resolveName(String email, UserRole role) {
    final prefix = email.split('@').first;
    switch (role) {
      case UserRole.municipalAdmin:
        return 'Admin Municipal (mock)';
      case UserRole.cooperativaAdmin:
        return 'Admin Cooperativa (mock)';
      case UserRole.conductor:
        return 'Conductor ${prefix.replaceAll(RegExp('[^a-zA-Z]'), ' ')}';
      default:
        if (email.toLowerCase().startsWith('premium@')) {
          return 'Usuario Premium';
        }
        return 'Usuario ${prefix.replaceAll(RegExp('[^a-zA-Z]'), ' ')}';
    }
  }
}
