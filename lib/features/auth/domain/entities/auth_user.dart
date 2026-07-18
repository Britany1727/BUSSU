import '../../../../core/constants/app_roles.dart';

/// Entidad que representa al usuario autenticado en el dominio.
class AppUser {
  /// ID del usuario en Supabase Auth (UUID).
  final String id;

  /// Correo electrónico del usuario.
  final String email;

  /// Nombre completo del perfil.
  final String? fullName;

  /// Rol del usuario en el sistema.
  final UserRole role;

  /// Indica si el usuario tiene suscripción Premium activa.
  final bool isPremium;

  /// Fingerprint del dispositivo vinculado.
  final String? deviceId;

  /// ID de cooperativa asociada (si el usuario es cooperativa_admin o conductor).
  final String? cooperativaId;

  /// URL del avatar del usuario.
  final String? avatarUrl;

  /// Fecha de creación del perfil.
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.email,
    this.fullName,
    required this.role,
    this.isPremium = false,
    this.deviceId,
    this.cooperativaId,
    this.avatarUrl,
    required this.createdAt,
  });

  AppUser copyWith({
    String? id,
    String? email,
    String? fullName,
    UserRole? role,
    bool? isPremium,
    String? deviceId,
    String? cooperativaId,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      isPremium: isPremium ?? this.isPremium,
      deviceId: deviceId ?? this.deviceId,
      cooperativaId: cooperativaId ?? this.cooperativaId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AppUser(id: $id, email: $email, role: $role)';
}
