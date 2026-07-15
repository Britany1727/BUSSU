import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/result_mapper.dart';
import '../../../../shared/data/models/bus_model.dart';
import '../../../../shared/data/models/route_model.dart';
import '../../../../shared/data/models/stop_model.dart';
import '../../../../shared/domain/entities/bus_entity.dart';
import '../../../../shared/domain/entities/route_entity.dart';
import '../../../../shared/domain/entities/stop_entity.dart';
import '../../domain/entities/driver_entity.dart';
import '../../domain/entities/fleet_health.dart';
import '../../domain/entities/route_performance.dart';
import '../../domain/repositories/fleet_repository.dart';
import '../datasources/fleet_remote_datasource.dart';

/// Implementación del repositorio de flota.
class FleetRepositoryImpl implements FleetRepository {
  final FleetRemoteDataSource _remote;

  FleetRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, FleetHealth>> getFleetHealth(
    String cooperativaId,
  ) async {
    return ResultMapper.fromAsync(
      () => _remote.fetchFleetHealth(cooperativaId),
    );
  }

  @override
  Stream<Either<Failure, FleetHealth>> watchFleetHealth(
    String cooperativaId,
  ) {
    return _remote.watchFleetHealth(cooperativaId).transform(
      StreamTransformer<FleetHealth, Either<Failure, FleetHealth>>.fromHandlers(
        handleData: (data, sink) => sink.add(Right(data)),
        handleError: (err, _, sink) =>
            sink.add(Left(ServerFailure(err.toString()))),
      ),
    );
  }

  @override
  Future<Either<Failure, List<DriverEntity>>> getDrivers(
    String cooperativaId,
  ) async {
    return ResultMapper.fromAsync(() => _remote.fetchDrivers(cooperativaId));
  }

  @override
  Future<Either<Failure, void>> updateDriver(DriverEntity driver) async {
    return ResultMapper.fromAsync(() async {
      await _remote.updateDriver({
        'id': driver.id,
        'license_number': driver.licenseNumber,
        'assigned_bus_id': driver.assignedBusId,
      });
    });
  }

  @override
  Future<Either<Failure, void>> assignDriverToBus({
    required String driverId,
    required String busId,
  }) async {
    return ResultMapper.fromAsync(
      () => _remote.assignDriverToBus(driverId, busId),
    );
  }

  @override
  Future<Either<Failure, List<BusEntity>>> getBuses(
    String cooperativaId,
  ) async {
    return ResultMapper.fromAsync(() async {
      final data = await _remote.fetchBuses(cooperativaId);
      return data.map((b) {
        final model = BusModel(
          id: b['id'] as String,
          plate: b['plate'] as String,
          cooperativaId: b['cooperativa_id'] as String?,
          routeId: b['route_id'] as String?,
          capacity: b['capacity'] as int? ?? 40,
          hardwareDeviceId: b['hardware_device_id'] as String?,
        );
        return model.toEntity();
      }).toList();
    });
  }

  @override
  Future<Either<Failure, void>> updateBus(BusEntity bus) async {
    return ResultMapper.fromAsync(() async {
      await _remote.upsertBus({
        'id': bus.id,
        'plate': bus.plate,
        'cooperativa_id': bus.cooperativaId,
        'route_id': bus.routeId,
        'capacity': bus.capacity,
      });
    });
  }

  @override
  Future<Either<Failure, void>> createBus({
    required String plate,
    required String cooperativaId,
    required int capacity,
    String? routeId,
  }) async {
    return ResultMapper.fromAsync(() async {
      await _remote.upsertBus({
        'plate': plate,
        'cooperativa_id': cooperativaId,
        'capacity': capacity,
        'route_id': routeId,
      });
    });
  }

  @override
  Future<Either<Failure, List<StopEntity>>> getStops(String routeId) async {
    return ResultMapper.fromAsync(() async {
      final data = await _remote.fetchStops(routeId);
      return data.map((s) => StopModel.fromJson(s).toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, void>> updateStop(StopEntity stop) async {
    return ResultMapper.fromAsync(() async {
      await _remote.upsertStop({
        'id': stop.id,
        'route_id': stop.routeId,
        'name': stop.name,
        'lat': stop.latitude,
        'lng': stop.longitude,
        'order_index': stop.orderIndex,
      });
    });
  }

  @override
  Future<Either<Failure, void>> approveStopRequest(String requestId) async {
    return ResultMapper.fromAsync(
      () => _remote.updateStopRequestStatus(requestId, 'approved'),
    );
  }

  @override
  Future<Either<Failure, void>> rejectStopRequest(String requestId) async {
    return ResultMapper.fromAsync(
      () => _remote.updateStopRequestStatus(requestId, 'rejected'),
    );
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getPendingStopRequests(
    String cooperativaId,
  ) async {
    return ResultMapper.fromAsync(
      () => _remote.fetchPendingStopRequests(cooperativaId),
    );
  }

  @override
  Future<Either<Failure, List<RouteEntity>>> getRoutes(
    String cooperativaId,
  ) async {
    return ResultMapper.fromAsync(() async {
      final data = await _remote.fetchRoutes(cooperativaId);
      return data.map((r) => RouteModel.fromJson(r).toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, void>> updateRoute(RouteEntity route) async {
    return ResultMapper.fromAsync(() async {
      await _remote.upsertRoute({
        'id': route.id,
        'cooperativa_id': route.cooperativaId,
        'name': route.name,
        'color': route.color,
        'polyline': route.polyline
            .map((p) => {'lat': p[0], 'lng': p[1]})
            .toList(),
      });
    });
  }

  @override
  Future<Either<Failure, List<RoutePerformance>>> getRoutePerformance(
    String cooperativaId,
  ) async {
    return ResultMapper.fromAsync(() async {
      final data = await _remote.fetchRoutePerformance(cooperativaId);
      return data.map((r) {
        return RoutePerformance(
          routeId: r['route_id'] as String? ?? '',
          routeName: r['route_name'] as String? ?? '',
          totalTrips: r['total_trips'] as int? ?? 0,
          completedTrips: r['completed_trips'] as int? ?? 0,
          averageOccupancy:
              (r['avg_occupancy'] as num?)?.toDouble() ?? 0,
          averageSpeedKmh: (r['avg_speed'] as num?)?.toDouble() ?? 0,
          totalPassengers: r['total_passengers'] as int? ?? 0,
        );
      }).toList();
    });
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getTripHistory(
    String cooperativaId, {
    int limit = 50,
  }) async {
    return ResultMapper.fromAsync(
      () => _remote.fetchTripHistory(cooperativaId, limit: limit),
    );
  }

  @override
  Future<Either<Failure, void>> createDriver({
    required String cooperativaId,
    required String email,
    required String password,
    required String fullName,
    String? licenseNumber,
  }) async {
    return ResultMapper.fromAsync(() => _remote.createDriver(
      cooperativaId: cooperativaId,
      email: email,
      password: password,
      fullName: fullName,
      licenseNumber: licenseNumber,
    ));
  }
}
