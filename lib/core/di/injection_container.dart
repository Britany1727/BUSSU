import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/data/repositories/mock_auth_repository.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/usuario/domain/repositories/bus_tracking_repository.dart';
import '../../features/usuario/domain/repositories/eta_repository.dart';
import '../../features/usuario/presentation/providers/eta_provider.dart';
import '../../features/usuario/presentation/providers/live_map_provider.dart';
import '../../features/conductor/domain/repositories/stops_repository.dart';
import '../../features/conductor/domain/repositories/trip_repository.dart';
import '../../features/conductor/presentation/providers/trip_provider.dart';
import '../../features/cooperativa/domain/repositories/fleet_repository.dart';
import '../../features/cooperativa/presentation/providers/fleet_provider.dart';
import '../../features/admin_municipal/domain/repositories/network_monitor_repository.dart';
import '../../features/admin_municipal/presentation/providers/system_alerts_provider.dart';
import '../../features/chat/data/datasources/chat_remote_datasource.dart';
import '../../features/chat/data/repositories/chat_repository_impl.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/usuario/data/datasources/bus_tracking_remote_datasource.dart';
import '../../features/usuario/data/datasources/eta_remote_datasource.dart';
import '../../features/usuario/data/repositories/bus_tracking_repository_impl.dart';
import '../../features/usuario/data/repositories/eta_repository_impl.dart';
import '../../features/conductor/data/datasources/obd_telemetry_datasource.dart';
import '../../features/conductor/data/datasources/stops_remote_datasource.dart';
import '../../features/conductor/data/datasources/trip_remote_datasource.dart';
import '../../features/conductor/data/repositories/stops_repository_impl.dart';
import '../../features/conductor/data/repositories/trip_repository_impl.dart';
import '../../features/cooperativa/data/datasources/fleet_remote_datasource.dart';
import '../../features/cooperativa/data/repositories/fleet_repository_impl.dart';
import '../../features/admin_municipal/data/datasources/network_monitor_remote_datasource.dart';
import '../../features/admin_municipal/data/repositories/network_monitor_repository_impl.dart';
import '../config/env.dart';
import '../network/connectivity_service.dart';
import '../network/mqtt_service.dart';
import '../network/websocket_service.dart';
import '../notifications/push_service.dart';
import '../notifications/push_service_impl.dart';
import '../payments/payment_gateway_service.dart';
import '../payments/payment_gateway_service_impl.dart';
import '../security/device_binding_service.dart';
import '../security/device_binding_service_impl.dart';
import '../routing/role_guard.dart';
import '../services/auth_session_manager.dart';
import 'mock_repositories.dart';

final GetIt sl = GetIt.instance;

// ─── No-op implementations for mock mode ────────────────────────────
class _NoopPushService implements PushService {
  @override Future<void> initialize() async {}
  @override Future<String?> getToken() async => null;
  @override Stream<Map<String, dynamic>> get onMessageReceived => const Stream.empty();
  @override Future<void> subscribeToTopic(String topic) async {}
  @override Future<void> unsubscribeFromTopic(String topic) async {}
}

// ─── DI Configuration ──────────────────────────────────────────────

Future<void> configureDependencies() async {
  _registerCoreServices();
  _registerNetworkServices();
  _registerSupabaseServices();
  _registerAuthDependencies();
  if (Env.enableMockAuth) {
    _registerMockDependencies();
  } else {
    _registerRealFeatureDependencies();
  }
  _configureRiverpodOverrides();
}

void _registerCoreServices() {
  sl.registerLazySingleton<Connectivity>(Connectivity.new);
  sl.registerLazySingleton<DeviceInfoPlugin>(DeviceInfoPlugin.new);
  sl.registerLazySingleton<DeviceBindingService>(
    () => DeviceBindingServiceImpl(sl<DeviceInfoPlugin>()),
  );

  sl.registerLazySingleton<PaymentGatewayService>(
    PaymentGatewayServiceImpl.new,
  );
}

void _registerSupabaseServices() {
  if (Env.enableMockAuth) return;
  if (!sl.isRegistered<SupabaseClient>()) return;

  sl.registerLazySingleton<PushService>(
    () => PushServiceImpl(sl<SupabaseClient>()),
  );
}

void _registerNetworkServices() {
  sl.registerLazySingleton<ConnectivityService>(
    () => ConnectivityServiceImpl(sl<Connectivity>()),
  );

  sl.registerLazySingleton<MqttService>(MqttServiceImpl.new);

  sl.registerLazySingleton<WebSocketService>(WebSocketServiceImpl.new);
}

void _registerAuthDependencies() {
  if (Env.enableMockAuth) {
    sl.registerLazySingleton<AuthRepository>(MockAuthRepository.new);
    return;
  }

  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl<SupabaseClient>()),
  );

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl<AuthRemoteDataSource>()),
  );

  sl.registerLazySingleton<AuthSessionManager>(
    () => AuthSessionManager(sl<SupabaseClient>()),
  );
}

void _registerMockDependencies() {
  sl.registerLazySingleton<BusTrackingRepository>(MockBusTrackingRepository.new);
  sl.registerLazySingleton<EtaRepository>(MockEtaRepository.new);
  sl.registerLazySingleton<TripRepository>(MockTripRepository.new);
  sl.registerLazySingleton<StopsRepository>(MockStopsRepository.new);
  sl.registerLazySingleton<FleetRepository>(MockFleetRepository.new);
  sl.registerLazySingleton<NetworkMonitorRepository>(
    MockNetworkMonitorRepository.new,
  );
  sl.registerLazySingleton<ChatRepository>(() => ChatRepositoryImpl());
}

void _registerRealFeatureDependencies() {
  if (!sl.isRegistered<SupabaseClient>()) {
    debugPrint('WARNING: SupabaseClient no registrado, usando repos mock');
    _registerMockDependencies();
    return;
  }
  final client = sl<SupabaseClient>();

  sl.registerLazySingleton<BusTrackingRemoteDataSource>(
    () => BusTrackingRemoteDataSourceImpl(client),
  );
  sl.registerLazySingleton<BusTrackingRepository>(
    () => BusTrackingRepositoryImpl(sl<BusTrackingRemoteDataSource>()),
  );

  sl.registerLazySingleton<EtaRemoteDataSource>(
    () => EtaRemoteDataSourceImpl(client),
  );
  sl.registerLazySingleton<EtaRepository>(
    () => EtaRepositoryImpl(sl<EtaRemoteDataSource>()),
  );

  sl.registerLazySingleton<TripRemoteDataSource>(
    () => TripRemoteDataSourceImpl(client),
  );
  sl.registerLazySingleton<ObdTelemetryDataSource>(
    () => ObdTelemetryDataSourceImpl(client),
  );
  sl.registerLazySingleton<TripRepository>(
    () => TripRepositoryImpl(sl<TripRemoteDataSource>(), sl<ObdTelemetryDataSource>()),
  );

  sl.registerLazySingleton<StopsRemoteDataSource>(
    () => StopsRemoteDataSourceImpl(client),
  );
  sl.registerLazySingleton<StopsRepository>(
    () => StopsRepositoryImpl(sl<StopsRemoteDataSource>()),
  );

  sl.registerLazySingleton<FleetRemoteDataSource>(
    () => FleetRemoteDataSourceImpl(client),
  );
  sl.registerLazySingleton<FleetRepository>(
    () => FleetRepositoryImpl(sl<FleetRemoteDataSource>()),
  );

  sl.registerLazySingleton<NetworkMonitorRemoteDataSource>(
    () => NetworkMonitorRemoteDataSourceImpl(client),
  );
  sl.registerLazySingleton<NetworkMonitorRepository>(
    () => NetworkMonitorRepositoryImpl(sl<NetworkMonitorRemoteDataSource>()),
  );

  sl.registerLazySingleton<ChatRemoteDataSource>(
    () => ChatRemoteDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(remote: sl<ChatRemoteDataSource>()),
  );
}

void _configureRiverpodOverrides() {
  _connectivityOverride = connectivityServiceProvider.overrideWith(
    (_) => sl<ConnectivityService>(),
  );

  _mqttOverride = mqttServiceProvider.overrideWith(
    (_) => sl<MqttService>(),
  );

  _wsOverride = webSocketServiceProvider.overrideWith(
    (_) => sl<WebSocketService>(),
  );

  _pushOverride = pushServiceProvider.overrideWith(
    (_) => Env.enableMockAuth
        ? _NoopPushService()
        : sl<PushService>(),
  );

  _paymentOverride = paymentGatewayServiceProvider.overrideWith(
    (_) => sl<PaymentGatewayService>(),
  );

  _deviceBindingOverride = deviceBindingServiceProvider.overrideWith(
    (_) => sl<DeviceBindingService>(),
  );

  _authRepositoryOverride = authRepositoryProvider.overrideWith(
    (_) => sl<AuthRepository>(),
  );

  _authSessionManagerOverride = authSessionManagerProvider.overrideWith(
    (_) => sl<AuthSessionManager>(),
  );

  _busTrackingOverride = busTrackingRepositoryProvider.overrideWith(
    (_) => sl<BusTrackingRepository>(),
  );
  _etaOverride = etaRepositoryProvider.overrideWith(
    (_) => sl<EtaRepository>(),
  );
  _tripOverride = tripRepositoryProvider.overrideWith(
    (_) => sl<TripRepository>(),
  );
  _stopsOverride = stopsRepositoryProvider.overrideWith(
    (_) => sl<StopsRepository>(),
  );
  _fleetOverride = fleetRepositoryProvider.overrideWith(
    (_) => sl<FleetRepository>(),
  );
  _networkMonitorOverride = networkMonitorRepositoryProvider.overrideWith(
    (_) => sl<NetworkMonitorRepository>(),
  );
}

void disposeDependencies() {
  disposeAuthStream();
  if (!Env.enableMockAuth) {
    sl<AuthSessionManager>().dispose();
  }
  sl<ConnectivityService>().dispose();
  sl<MqttService>().dispose();
  sl<WebSocketService>().dispose();
}

Override get connectivityOverride => _connectivityOverride;
Override get mqttOverride => _mqttOverride;
Override get wsOverride => _wsOverride;
Override get pushOverride => _pushOverride;
Override get paymentOverride => _paymentOverride;
Override get deviceBindingOverride => _deviceBindingOverride;
Override get authRepositoryOverride => _authRepositoryOverride;
Override get authSessionManagerOverride => _authSessionManagerOverride;
Override get busTrackingOverride => _busTrackingOverride;
Override get etaOverride => _etaOverride;
Override get tripOverride => _tripOverride;
Override get stopsOverride => _stopsOverride;
Override get fleetOverride => _fleetOverride;
Override get networkMonitorOverride => _networkMonitorOverride;

late final Override _connectivityOverride;
late final Override _mqttOverride;
late final Override _wsOverride;
late final Override _pushOverride;
late final Override _paymentOverride;
late final Override _deviceBindingOverride;
late final Override _authRepositoryOverride;
late final Override _authSessionManagerOverride;
late final Override _busTrackingOverride;
late final Override _etaOverride;
late final Override _tripOverride;
late final Override _stopsOverride;
late final Override _fleetOverride;
late final Override _networkMonitorOverride;

final pushServiceProvider = Provider<PushService>((_) {
  throw UnimplementedError(
    'Registra PushService en injection_container.dart',
  );
});

final paymentGatewayServiceProvider = Provider<PaymentGatewayService>((_) {
  throw UnimplementedError(
    'Registra PaymentGatewayService en injection_container.dart',
  );
});

final deviceBindingServiceProvider = Provider<DeviceBindingService>((_) {
  throw UnimplementedError(
    'Registra DeviceBindingService en injection_container.dart',
  );
});
