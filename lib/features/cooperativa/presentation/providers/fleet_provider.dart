import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/domain/entities/bus_entity.dart';
import '../../../../shared/domain/entities/route_entity.dart';
import '../../../../shared/domain/entities/stop_entity.dart';
import '../../domain/entities/driver_entity.dart';
import '../../domain/entities/fleet_health.dart';
import '../../domain/entities/route_performance.dart';
import '../../domain/repositories/fleet_repository.dart';
import '../../domain/usecases/assign_driver_usecase.dart';
import '../../domain/usecases/get_fleet_health_usecase.dart';
import '../../domain/usecases/get_route_performance_usecase.dart';

/// ID de cooperativa actual (se obtiene del perfil del usuario autenticado).
final currentCoopIdProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.cooperativaId ?? '';
});

final fleetRepositoryProvider = Provider<FleetRepository>((_) {
  throw UnimplementedError('Registra en injection_container');
});

final getFleetHealthUseCaseProvider =
    Provider<GetFleetHealthUseCase>((ref) {
  return GetFleetHealthUseCase(ref.watch(fleetRepositoryProvider));
});

final getRoutePerformanceUseCaseProvider =
    Provider<GetRoutePerformanceUseCase>((ref) {
  return GetRoutePerformanceUseCase(ref.watch(fleetRepositoryProvider));
});

final assignDriverUseCaseProvider = Provider<AssignDriverUseCase>((ref) {
  return AssignDriverUseCase(ref.watch(fleetRepositoryProvider));
});

// ---- Streams y Futures ----

final fleetHealthProvider =
    StreamProvider<FleetHealth>((ref) {
  final coopId = ref.watch(currentCoopIdProvider);
  if (coopId.isEmpty) return const Stream.empty();
  final repo = ref.watch(fleetRepositoryProvider);
  return repo.watchFleetHealth(coopId)
      .where((e) => e.isRight())
      .map((e) => e.fold((_) => const FleetHealth(), (health) => health))
      .distinct();
});

final driversProvider =
    FutureProvider.family<List<DriverEntity>, String>((ref, coopId) async {
  final repo = ref.watch(fleetRepositoryProvider);
  final result = await repo.getDrivers(coopId);
  return result.fold((_) => [], (d) => d);
});

final busesProvider =
    FutureProvider.family<List<BusEntity>, String>((ref, coopId) async {
  final repo = ref.watch(fleetRepositoryProvider);
  final result = await repo.getBuses(coopId);
  return result.fold((_) => [], (b) => b);
});

final routesProvider =
    FutureProvider.family<List<RouteEntity>, String>((ref, coopId) async {
  final repo = ref.watch(fleetRepositoryProvider);
  final result = await repo.getRoutes(coopId);
  return result.fold((_) => [], (r) => r);
});

final routePerformanceProvider =
    FutureProvider<List<RoutePerformance>>((ref) async {
  final coopId = ref.watch(currentCoopIdProvider);
  final useCase = ref.watch(getRoutePerformanceUseCaseProvider);
  final result = await useCase.execute(coopId);
  return result.fold((_) => [], (p) => p);
});

final pendingStopRequestsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final coopId = ref.watch(currentCoopIdProvider);
  final repo = ref.watch(fleetRepositoryProvider);
  final result = await repo.getPendingStopRequests(coopId);
  return result.fold((_) => [], (r) => r);
});
