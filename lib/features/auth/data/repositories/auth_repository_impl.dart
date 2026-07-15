import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/constants/app_roles.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/result_mapper.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/enums/auth_event_type.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

/// Implementación concreta de [AuthRepository] usando Supabase.
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, AppUser>> signIn({
    required String email,
    required String password,
  }) async {
    return ResultMapper.fromAsync(() async {
      final model = await _remoteDataSource.signIn(email, password);
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, AppUser>> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    try {
      final result = await _remoteDataSource.signUp(
        email: email,
        password: password,
        fullName: fullName,
        role: role.toDatabaseValue,
      );

      if (result.emailConfirmationPending) {
        return const Left(EmailConfirmationPendingFailure());
      }

      return Right(result.user!.toEntity());
    } catch (e) {
      return Left(ResultMapper.mapExceptionToFailure(e, StackTrace.current));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    return ResultMapper.fromAsync(() => _remoteDataSource.signOut());
  }

  @override
  Future<Either<Failure, void>> resetPassword(String email) async {
    return ResultMapper.fromAsync(
      () => _remoteDataSource.resetPassword(email),
    );
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    try {
      final session = _remoteDataSource.currentSession;
      if (session == null) return null;

      final profile = await _remoteDataSource.fetchProfile(session.user.id);
      return profile?.toEntity();
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<AppUser?> get onAuthStateChanged {
    return _remoteDataSource.onAuthStateChange.asyncMap((event) async {
      if (event == AuthEventType.signedOut || event == AuthEventType.userDeleted) {
        return null;
      }

      final session = _remoteDataSource.currentSession;
      if (session == null) return null;

      final profile = await _remoteDataSource.fetchProfile(session.user.id);
      return profile?.toEntity();
    });
  }

  @override
  Future<String?> get accessToken async {
    return _remoteDataSource.currentSession?.accessToken;
  }

  @override
  Future<Either<Failure, void>> refreshSession() async {
    return ResultMapper.fromAsync(() async {
      final session = await _remoteDataSource.refreshSession();
      if (session == null) {
        throw const AuthFailureException('No se pudo refrescar la sesión');
      }
    });
  }

  @override
  Future<Either<Failure, void>> updateDeviceId(String deviceId) async {
    return ResultMapper.fromAsync(() async {
      final session = _remoteDataSource.currentSession;
      if (session == null) {
        throw const AuthFailureException('No hay sesión activa');
      }
      await _remoteDataSource.updateDeviceId(session.user.id, deviceId);
    });
  }
}
