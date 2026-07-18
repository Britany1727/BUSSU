import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/result_mapper.dart';
import '../../domain/entities/cooperativa_status.dart';
import '../../domain/entities/municipal_overview.dart';
import '../../domain/entities/system_alert.dart';
import '../../domain/repositories/network_monitor_repository.dart';
import '../datasources/network_monitor_remote_datasource.dart';

class NetworkMonitorRepositoryImpl implements NetworkMonitorRepository {
  final NetworkMonitorRemoteDataSource _remote;

  NetworkMonitorRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, MunicipalOverview>> getMunicipalOverview() async {
    return ResultMapper.fromAsync(() async {
      final data = await _remote.fetchMunicipalOverview();
      return MunicipalOverview(
        totalCooperativas: data['total_cooperativas'] as int? ?? 0,
        totalBuses: data['total_buses'] as int? ?? 0,
        totalActiveBuses: data['total_active_buses'] as int? ?? 0,
        totalDrivers: data['total_drivers'] as int? ?? 0,
        totalPassengers: data['total_passengers'] as int? ?? 0,
        activeAlerts: data['active_alerts'] as int? ?? 0,
        systemHealthPct: (data['system_health_pct'] as num?)?.toDouble() ?? 0,
      );
    });
  }

  @override
  Stream<Either<Failure, MunicipalOverview>> watchMunicipalOverview() {
    return _remote.watchMunicipalOverview().transform(
      StreamTransformer<Map<String, dynamic>,
          Either<Failure, MunicipalOverview>>.fromHandlers(
        handleData: (data, sink) {
          sink.add(Right(MunicipalOverview(
            totalCooperativas: data['total_cooperativas'] as int? ?? 0,
            totalBuses: data['total_buses'] as int? ?? 0,
            totalActiveBuses: data['total_active_buses'] as int? ?? 0,
            totalDrivers: data['total_drivers'] as int? ?? 0,
            totalPassengers: data['total_passengers'] as int? ?? 0,
            activeAlerts: data['active_alerts'] as int? ?? 0,
            systemHealthPct:
                (data['system_health_pct'] as num?)?.toDouble() ?? 0,
          )));
        },
        handleError: (e, _, sink) =>
            sink.add(Left(ServerFailure(e.toString()))),
      ),
    );
  }

  @override
  Future<Either<Failure, List<CooperativaStatus>>>
      getAllCooperativasStatus() async {
    return ResultMapper.fromAsync(() => _remote.fetchCooperativasStatus());
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getCooperativas() async {
    return ResultMapper.fromAsync(() => _remote.fetchCooperativas());
  }

  @override
  Future<Either<Failure, void>> createCooperativa(
    Map<String, dynamic> data,
  ) async {
    return ResultMapper.fromAsync(() => _remote.upsertCooperativa(data));
  }

  @override
  Future<Either<Failure, void>> updateCooperativa(
    Map<String, dynamic> data,
  ) async {
    return ResultMapper.fromAsync(() => _remote.upsertCooperativa(data));
  }

  @override
  Future<Either<Failure, void>> deleteCooperativa(String id) async {
    return ResultMapper.fromAsync(() => _remote.removeCooperativa(id));
  }

  @override
  Future<Either<Failure, List<SystemAlert>>> getSystemAlerts() async {
    return ResultMapper.fromAsync(() => _remote.fetchSystemAlerts());
  }

  @override
  Stream<Either<Failure, List<SystemAlert>>> watchSystemAlerts() {
    return _remote.watchSystemAlerts().transform(
      StreamTransformer<List<SystemAlert>,
          Either<Failure, List<SystemAlert>>>.fromHandlers(
        handleData: (data, sink) => sink.add(Right(data)),
        handleError: (e, _, sink) =>
            sink.add(Left(ServerFailure(e.toString()))),
      ),
    );
  }

  @override
  Future<Either<Failure, void>> createAlert(SystemAlert alert) async {
    return ResultMapper.fromAsync(() => _remote.insertAlert({
          'scope': alert.scope,
          'severity': alert.severity,
          'title': alert.title,
          'description': alert.description,
          'route_id': alert.routeId,
          'created_by': alert.createdBy,
          if (alert.latitude != null) 'latitude': alert.latitude,
          if (alert.longitude != null) 'longitude': alert.longitude,
        }));
  }

  @override
  Future<Either<Failure, void>> resolveAlert(String alertId) async {
    return ResultMapper.fromAsync(
      () => _remote.updateAlertStatus(alertId, DateTime.now()),
    );
  }

  @override
  Future<Either<Failure, void>> deleteAlert(String alertId) async {
    return ResultMapper.fromAsync(() => _remote.removeAlert(alertId));
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getPremiumSubscriptions() async {
    return ResultMapper.fromAsync(() => _remote.fetchPremiumSubscriptions());
  }

  @override
  Future<Either<Failure, void>> updateSubscriptionStatus(
    String id,
    String status,
  ) async {
    return ResultMapper.fromAsync(() => _remote.updateSubStatus(id, status));
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getAllUsers() async {
    return ResultMapper.fromAsync(() => _remote.fetchAllUsers());
  }

  @override
  Future<Either<Failure, void>> updateUserRole(
    String userId,
    String role,
  ) async {
    return ResultMapper.fromAsync(() => _remote.updateRole(userId, role));
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> generatePublicReport() async {
    return ResultMapper.fromAsync(() => _remote.fetchPublicReport());
  }
}
