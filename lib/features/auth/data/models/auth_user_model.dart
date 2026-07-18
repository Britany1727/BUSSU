import '../../../../core/constants/app_roles.dart';
import '../../domain/entities/auth_user.dart';

/// Modelo que extiende [AppUser] con capacidades de serialización
/// desde/hacia Supabase.
class AppUserModel extends AppUser {
  const AppUserModel({
    required super.id,
    required super.email,
    super.fullName,
    required super.role,
    super.isPremium = false,
    super.deviceId,
    super.cooperativaId,
    super.avatarUrl,
    required super.createdAt,
  });

  factory AppUserModel.fromJson(Map<String, dynamic> json) {
    return AppUserModel(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String?,
      role: UserRole.fromString(json['role'] as String),
      isPremium: json['is_premium'] as bool? ?? false,
      deviceId: json['device_id'] as String?,
      cooperativaId: json['cooperativa_id'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'role': role.toDatabaseValue,
      'is_premium': isPremium,
      'device_id': deviceId,
      'cooperativa_id': cooperativaId,
      'avatar_url': avatarUrl,
    };
  }

  AppUser toEntity() => AppUser(
        id: id,
        email: email,
        fullName: fullName,
        role: role,
        isPremium: isPremium,
        deviceId: deviceId,
        cooperativaId: cooperativaId,
        avatarUrl: avatarUrl,
        createdAt: createdAt,
      );
}
