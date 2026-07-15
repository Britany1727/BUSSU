import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_roles.dart';
import '../../domain/enums/auth_event_type.dart';
import '../models/auth_user_model.dart';

/// Resultado del registro: puede ser el usuario creado o indicación
/// de que se requiere confirmación de correo.
class SignUpResult {
  final AppUserModel? user;
  final bool emailConfirmationPending;

  const SignUpResult({this.user, this.emailConfirmationPending = false});
}

/// Datasource remoto de autenticación usando Supabase Auth.
abstract class AuthRemoteDataSource {
  Future<AppUserModel> signIn(String email, String password);

  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
  });

  Future<void> signOut();

  Future<void> resetPassword(String email);

  Future<AppUserModel?> fetchProfile(String userId);

  Future<void> insertProfile(AppUserModel user);

  Future<void> updateDeviceId(String userId, String deviceId);

  Stream<AuthEventType> get onAuthStateChange;

  Session? get currentSession;

  Future<Session?> refreshSession();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient _client;

  AuthRemoteDataSourceImpl(this._client);

  @override
  Future<AppUserModel> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final userId = response.user?.id;
    if (userId == null) {
      throw const AuthException('Usuario no encontrado tras login');
    }

    final profile = await fetchProfile(userId);
    if (profile == null) {
      throw const AuthException('Perfil no encontrado');
    }

    return profile;
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'role': role},
      emailRedirectTo: 'io.verve.bussu://login-callback',
    );

    final userId = response.user?.id;

    // Si userId es null, Supabase está esperando confirmación de correo
    if (userId == null) {
      return const SignUpResult(emailConfirmationPending: true);
    }

    final user = AppUserModel(
      id: userId,
      email: email,
      fullName: fullName,
      role: UserRole.fromString(role),
      createdAt: DateTime.now(),
    );

    // Si ya hay sesión (confirmación automática o deshabilitada), crear perfil
    if (response.session != null) {
      await insertProfile(user);
    }
    // Si no hay sesión, el trigger handle_new_user() crea el perfil
    // cuando el usuario confirma su correo

    return SignUpResult(user: user);
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  @override
  Future<AppUserModel?> fetchProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      final profile = AppUserModel.fromJson({
        ...response,
        'email': _client.auth.currentUser?.email ?? '',
        'role': response['role'] ?? 'usuario',
      });

      return profile;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> insertProfile(AppUserModel user) async {
    await _client.from('profiles').upsert(user.toJson());
  }

  @override
  Future<void> updateDeviceId(String userId, String deviceId) async {
    await _client.from('profiles').update({
      'device_id': deviceId,
    }).eq('id', userId);
  }

  @override
  Stream<AuthEventType> get onAuthStateChange =>
      _client.auth.onAuthStateChange.map((data) => _mapEvent(data.event));

  static AuthEventType _mapEvent(AuthChangeEvent event) {
    switch (event) {
      case AuthChangeEvent.signedIn:
        return AuthEventType.signedIn;
      case AuthChangeEvent.signedOut:
        return AuthEventType.signedOut;
      case AuthChangeEvent.tokenRefreshed:
        return AuthEventType.tokenRefreshed;
      case AuthChangeEvent.userUpdated:
        return AuthEventType.userUpdated;
      case AuthChangeEvent.userDeleted:
        return AuthEventType.userDeleted;
      case AuthChangeEvent.passwordRecovery:
        return AuthEventType.passwordRecovery;
      case AuthChangeEvent.initialSession:
        return AuthEventType.initialSession;
      case AuthChangeEvent.mfaChallengeVerified:
        return AuthEventType.tokenRefreshed;
    }
  }

  @override
  Session? get currentSession => _client.auth.currentSession;

  @override
  Future<Session?> refreshSession() async {
    try {
      final response = await _client.auth.refreshSession();
      return response.session;
    } catch (_) {
      return null;
    }
  }
}
