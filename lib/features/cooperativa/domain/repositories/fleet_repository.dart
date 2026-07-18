import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../shared/domain/entities/bus_entity.dart';
import '../../../../shared/domain/entities/route_entity.dart';
import '../../../../shared/domain/entities/stop_entity.dart';
import '../entities/driver_entity.dart';
import '../entities/fleet_health.dart';
import '../entities/route_performance.dart';

/// Repositorio de gestión de flota para la cooperativa.
abstract class FleetRepository {
  // ---- Fleet Health ----
  Future<Either<Failure, FleetHealth>> getFleetHealth(String cooperativaId);
  Stream<Either<Failure, FleetHealth>> watchFleetHealth(String cooperativaId);

  // ---- Drivers CRUD ----
  Future<Either<Failure, List<DriverEntity>>> getDrivers(String cooperativaId);
  Future<Either<Failure, void>> updateDriver(DriverEntity driver);
  Future<Either<Failure, void>> assignDriverToBus({
    required String driverId,
    required String busId,
  });

  // ---- Buses CRUD ----
  Future<Either<Failure, List<BusEntity>>> getBuses(String cooperativaId);
  Future<Either<Failure, void>> updateBus(BusEntity bus);
  Future<Either<Failure, void>> createBus({
    required String plate,
    required String cooperativaId,
    required int capacity,
    String? routeId,
  });

  // ---- Stops CRUD ----
  Future<Either<Failure, List<StopEntity>>> getStops(String routeId);
  Future<Either<Failure, void>> updateStop(StopEntity stop);
  Future<Either<Failure, void>> approveStopRequest(String requestId);
  Future<Either<Failure, void>> rejectStopRequest(String requestId);
  Future<Either<Failure, List<Map<String, dynamic>>>> getPendingStopRequests(
    String cooperativaId,
  );

  // ---- Routes CRUD ----
  Future<Either<Failure, List<RouteEntity>>> getRoutes(String cooperativaId);
  Future<Either<Failure, void>> updateRoute(RouteEntity route);
  Future<Either<Failure, void>> deleteRoute(String routeId);

  // ---- Reports ----
  Future<Either<Failure, List<RoutePerformance>>> getRoutePerformance(
    String cooperativaId,
  );
  Future<Either<Failure, List<Map<String, dynamic>>>> getTripHistory(
    String cooperativaId, {
    int limit = 50,
  });

  // ---- Driver creation ----
  Future<Either<Failure, void>> createDriver({
    required String cooperativaId,
    required String email,
    required String password,
    required String fullName,
    String? licenseNumber,
  });

  // ---- Driver deletion ----
  Future<Either<Failure, void>> deleteDriver(String driverId);
}
