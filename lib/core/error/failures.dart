sealed class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => 'Failure: $message';
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Sin conexión a la red']);
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Error del servidor']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Error de autenticación']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Error de caché local']);
}

class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Datos inválidos']);
}

class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'Permisos insuficientes']);
}

class RealtimeFailure extends Failure {
  const RealtimeFailure([super.message = 'Error en el canal en tiempo real']);
}

class MqttFailure extends Failure {
  const MqttFailure([super.message = 'Error en conexión MQTT']);
}

class WebSocketFailure extends Failure {
  const WebSocketFailure([super.message = 'Error en conexión WebSocket']);
}

class DeviceBindingFailure extends Failure {
  const DeviceBindingFailure([super.message = 'Dispositivo no vinculado']);
}

class PaymentFailure extends Failure {
  const PaymentFailure([super.message = 'Error en el proceso de pago']);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Error desconocido']);
}

class EmailConfirmationPendingFailure extends Failure {
  const EmailConfirmationPendingFailure([super.message = 'Confirma tu correo electrónico para continuar']);
}
