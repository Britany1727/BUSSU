import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../features/admin_municipal/domain/entities/cooperativa_status.dart';
import '../../../../features/admin_municipal/domain/entities/municipal_overview.dart';
import '../../../../features/admin_municipal/domain/entities/system_alert.dart';
import '../../../../features/admin_municipal/domain/repositories/network_monitor_repository.dart';
import '../../../../features/cooperativa/domain/entities/driver_entity.dart';
import '../../../../features/cooperativa/domain/entities/fleet_health.dart';
import '../../../../features/cooperativa/domain/entities/route_performance.dart';
import '../../../../features/cooperativa/domain/repositories/fleet_repository.dart';
import '../../../../features/conductor/domain/entities/trip_entity.dart';
import '../../../../features/conductor/domain/repositories/stops_repository.dart';
import '../../../../features/conductor/domain/repositories/trip_repository.dart';
import '../../../../features/usuario/domain/repositories/bus_tracking_repository.dart';
import '../../../../features/usuario/domain/repositories/eta_repository.dart';
import '../../../../shared/domain/entities/bus_entity.dart';
import '../../../../shared/domain/entities/route_entity.dart';
import '../../../../shared/domain/entities/stop_entity.dart';
import '../../../core/error/failures.dart';

// ─── Usuario ────────────────────────────────────────────────────────

class MockBusTrackingRepository implements BusTrackingRepository {
  @override
  Stream<Either<Failure, BusEntity>> watchBusPosition(String busId) =>
      Stream.value(const Right(BusEntity(id: 'mock', plate: 'ABC-123')));

  @override
  Stream<Either<Failure, List<BusEntity>>> watchRouteBuses(String routeId) =>
      Stream.value(const Right([]));

  @override
  Future<Either<Failure, BusEntity>> getBusPosition(String busId) async =>
      const Right(BusEntity(id: 'mock', plate: 'ABC-123'));

  @override
  Future<Either<Failure, List<StopEntity>>> getRouteStops(
          String routeId) async =>
      const Right([]);
}

class MockEtaRepository implements EtaRepository {
  @override
  Future<Either<Failure, Duration>> calculateEta(
          {required String busId, required String stopId}) async =>
      const Right(Duration.zero);

  @override
  Stream<Either<Failure, Map<String, Duration>>> watchEtas(
          {required String busId, required String routeId}) =>
      Stream.value(const Right({}));

  @override
  Future<Either<Failure, List<RouteEntity>>> getAvailableRoutes() async =>
      const Right([]);

  @override
  Future<Either<Failure, RouteWithBuses>> getRouteWithBuses(
          String routeId) async =>
      const Left(ServerFailure('Mock: sin datos'));
}

// ─── Conductor ──────────────────────────────────────────────────────

class MockTripRepository implements TripRepository {
  @override
  Future<Either<Failure, TripEntity>> startTrip(
          {required String busId,
          required String routeId,
          required String driverId}) async =>
      const Right(TripEntity(
          id: 'mock', busId: '', routeId: '', driverId: ''));

  @override
  Future<Either<Failure, void>> endTrip(String tripId) async =>
      const Right(null);

  @override
  Future<Either<Failure, TripEntity?>> getActiveTrip(
          String driverId) async =>
      const Right(null);

  @override
  Stream<Either<Failure, TripEntity>> watchActiveTrip(String driverId) =>
      Stream.value(
          const Left(ValidationFailure('Mock: no hay viaje activo')));

  @override
  Future<Either<Failure, void>> publishTelemetry(
          {required String busId,
          required double lat,
          required double lng,
          required double speedKmh,
          required double heading}) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> updatePassengerCount(
          {required String busId, required int count}) async =>
      const Right(null);

  @override
  Future<Either<Failure, List<TripEntity>>> getTripHistory(
          String driverId) async =>
      const Right([]);
}

class MockStopsRepository implements StopsRepository {
  @override
  Future<Either<Failure, void>> requestNewStop(
          {required String driverId,
          required double lat,
          required double lng,
          required String reason}) async =>
      const Right(null);

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getRouteStops(
          String routeId) async =>
      const Right([]);
}

// ─── Cooperativa ────────────────────────────────────────────────────

class MockFleetRepository implements FleetRepository {
  @override
  Future<Either<Failure, FleetHealth>> getFleetHealth(
          String cooperativaId) async =>
      const Right(FleetHealth());

  @override
  Stream<Either<Failure, FleetHealth>> watchFleetHealth(
          String cooperativaId) =>
      Stream.value(const Right(FleetHealth()));

  @override
  Future<Either<Failure, List<DriverEntity>>> getDrivers(
          String cooperativaId) async =>
      const Right([]);

  @override
  Future<Either<Failure, void>> updateDriver(DriverEntity driver) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> assignDriverToBus(
          {required String driverId, required String busId}) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> createDriver({
          required String cooperativaId,
          required String email,
          required String password,
          required String fullName,
          String? licenseNumber}) async =>
      const Right(null);

  @override
  Future<Either<Failure, List<BusEntity>>> getBuses(
          String cooperativaId) async =>
      const Right([]);

  @override
  Future<Either<Failure, void>> updateBus(BusEntity bus) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> createBus(
          {required String plate,
          required String cooperativaId,
          required int capacity,
          String? routeId}) async =>
      const Right(null);

  @override
  Future<Either<Failure, List<StopEntity>>> getStops(String routeId) async =>
      const Right([]);

  @override
  Future<Either<Failure, void>> updateStop(StopEntity stop) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> approveStopRequest(
          String requestId) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> rejectStopRequest(
          String requestId) async =>
      const Right(null);

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getPendingStopRequests(
          String cooperativaId) async =>
      const Right([]);

  @override
  Future<Either<Failure, List<RouteEntity>>> getRoutes(
          String cooperativaId) async =>
      const Right([]);

  @override
  Future<Either<Failure, void>> updateRoute(RouteEntity route) async =>
      const Right(null);

  @override
  Future<Either<Failure, List<RoutePerformance>>> getRoutePerformance(
          String cooperativaId) async =>
      const Right([]);

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getTripHistory(
          String cooperativaId,
          {int limit = 50}) async =>
      const Right([]);
}

// ─── Admin Municipal ────────────────────────────────────────────────

class MockNetworkMonitorRepository implements NetworkMonitorRepository {
  @override
  Future<Either<Failure, MunicipalOverview>> getMunicipalOverview() async =>
      const Right(MunicipalOverview());

  @override
  Stream<Either<Failure, MunicipalOverview>> watchMunicipalOverview() =>
      Stream.value(const Right(MunicipalOverview()));

  @override
  Future<Either<Failure, List<CooperativaStatus>>>
      getAllCooperativasStatus() async => const Right([]);

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>>
      getCooperativas() async => const Right([]);

  @override
  Future<Either<Failure, void>> createCooperativa(
          Map<String, dynamic> data) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> updateCooperativa(
          Map<String, dynamic> data) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> deleteCooperativa(String id) async =>
      const Right(null);

  @override
  Future<Either<Failure, List<SystemAlert>>> getSystemAlerts() async =>
      const Right([]);

  @override
  Stream<Either<Failure, List<SystemAlert>>> watchSystemAlerts() =>
      Stream.value(const Right([]));

  @override
  Future<Either<Failure, void>> createAlert(SystemAlert alert) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> resolveAlert(String alertId) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> deleteAlert(String alertId) async =>
      const Right(null);

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>>
      getPremiumSubscriptions() async => const Right([]);

  @override
  Future<Either<Failure, void>> updateSubscriptionStatus(
          String id, String status) async =>
      const Right(null);

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getAllUsers() async =>
      const Right([]);

  @override
  Future<Either<Failure, void>> updateUserRole(
          String userId, String role) async =>
      const Right(null);

  @override
  Future<Either<Failure, Map<String, dynamic>>> generatePublicReport() async =>
      const Right({});
}
