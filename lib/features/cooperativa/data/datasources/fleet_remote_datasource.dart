import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/driver_entity.dart';
import '../../domain/entities/fleet_health.dart';

/// Datasource remoto de gestión de flota vía Supabase.
abstract class FleetRemoteDataSource {
  // Drivers
  Future<List<DriverEntity>> fetchDrivers(String cooperativaId);
  Future<void> updateDriver(Map<String, dynamic> data);
  Future<void> assignDriverToBus(String driverId, String busId);

  // Buses
  Future<List<Map<String, dynamic>>> fetchBuses(String cooperativaId);
  Future<void> upsertBus(Map<String, dynamic> data);

  // Stops
  Future<List<Map<String, dynamic>>> fetchStops(String routeId);
  Future<void> upsertStop(Map<String, dynamic> data);
  Future<void> updateStopRequestStatus(String requestId, String status);
  Future<List<Map<String, dynamic>>> fetchPendingStopRequests(
    String cooperativaId,
  );

  // Routes
  Future<List<Map<String, dynamic>>> fetchRoutes(String cooperativaId);
  Future<void> upsertRoute(Map<String, dynamic> data);
  Future<void> deleteRoute(String routeId);

  // Fleet Health
  Future<FleetHealth> fetchFleetHealth(String cooperativaId);
  Stream<FleetHealth> watchFleetHealth(String cooperativaId);

  // Reports
  Future<List<Map<String, dynamic>>> fetchRoutePerformance(String cooperativaId);
  Future<List<Map<String, dynamic>>> fetchTripHistory(
    String cooperativaId, {
    int limit = 50,
  });

  // Driver creation
  Future<void> createDriver({
    required String cooperativaId,
    required String email,
    required String password,
    required String fullName,
    String? licenseNumber,
  });

  // Driver deletion
  Future<void> deleteDriver(String driverId);
}

class FleetRemoteDataSourceImpl implements FleetRemoteDataSource {
  final SupabaseClient _client;

  FleetRemoteDataSourceImpl(this._client);

  // ---- Optimización: select solo columnas necesarias ----

  @override
  Future<List<DriverEntity>> fetchDrivers(String cooperativaId) async {
    final response = await _client
        .from('drivers')
        .select('id, is_active, created_at, profiles(full_name, email), license_number, assigned_bus_id, buses(plate)')
        .eq('cooperativa_id', cooperativaId)
        .order('created_at');

    return (response as List<dynamic>).map((d) {
      final data = d as Map<String, dynamic>;
      final profile = data['profiles'] as Map<String, dynamic>? ?? {};
      final bus = data['buses'] as Map<String, dynamic>? ?? {};
      return DriverEntity(
        id: data['id'] as String,
        fullName: profile['full_name'] as String? ?? '',
        email: profile['email'] as String? ?? '',
        licenseNumber: data['license_number'] as String?,
        assignedBusId: data['assigned_bus_id'] as String?,
        assignedBusPlate: bus['plate'] as String?,
        isActive: data['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(data['created_at'] as String? ??
            DateTime.now().toIso8601String()),
      );
    }).toList();
  }

  @override
  Future<void> updateDriver(Map<String, dynamic> data) async {
    await _client.from('drivers').upsert(data);
  }

  @override
  Future<void> assignDriverToBus(String driverId, String busId) async {
    await _client.from('drivers').update({
      'assigned_bus_id': busId,
    }).eq('id', driverId);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchBuses(String cooperativaId) async {
    final response = await _client
        .from('buses')
        .select('id, plate, cooperativa_id, route_id, capacity, hardware_device_id')
        .eq('cooperativa_id', cooperativaId)
        .order('plate');

    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  }

  @override
  Future<void> upsertBus(Map<String, dynamic> data) async {
    await _client.from('buses').upsert(data);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchStops(String routeId) async {
    final response = await _client
        .from('stops')
        .select()
        .eq('route_id', routeId)
        .order('order_index');

    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  }

  @override
  Future<void> upsertStop(Map<String, dynamic> data) async {
    await _client.from('stops').upsert(data);
  }

  @override
  Future<void> updateStopRequestStatus(String requestId, String status) async {
    await _client.from('stop_requests').update({
      'status': status,
    }).eq('id', requestId);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPendingStopRequests(
    String cooperativaId,
  ) async {
    final response = await _client
        .from('stop_requests')
        .select('*, drivers!inner(*)')
        .eq('status', 'pending')
        .filter('drivers.cooperativa_id', 'eq', cooperativaId)
        .order('created_at');

    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRoutes(String cooperativaId) async {
    final response = await _client
        .from('routes_for_app')
        .select('*, stops(*)')
        .eq('cooperativa_id', cooperativaId)
        .order('name');

    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  }

  @override
  Future<void> upsertRoute(Map<String, dynamic> data) async {
    await _client.from('routes').upsert(data);
  }

  @override
  Future<void> deleteRoute(String routeId) async {
    await _client.from('stops').delete().eq('route_id', routeId);
    await _client.from('routes').delete().eq('id', routeId);
  }

  @override
  Future<FleetHealth> fetchFleetHealth(String cooperativaId) async {
    // A05 FIX: Usar fleet_health_view (un solo query) en lugar de iterar cada bus
    final response = await _client
        .from('fleet_health_view')
        .select()
        .eq('cooperativa_id', cooperativaId)
        .maybeSingle();

    if (response == null) {
      return const FleetHealth();
    }

    final data = response as Map<String, dynamic>;
    return FleetHealth(
      totalBuses: data['total_buses'] as int? ?? 0,
      activeBuses: data['active_buses'] as int? ?? 0,
      inactiveBuses:
          (data['total_buses'] as int? ?? 0) - (data['active_buses'] as int? ?? 0),
      averageOccupancy:
          (data['avg_occupancy'] as num?)?.toDouble() ?? 0,
      totalPassengers: data['total_passengers'] as int? ?? 0,
      totalDrivers: data['total_drivers'] as int? ?? 0,
    );
  }

  @override
  Stream<FleetHealth> watchFleetHealth(String cooperativaId) {
    return _client
        .from('bus_live_position')
        .stream(primaryKey: ['bus_id'])
        .asyncMap((_) => fetchFleetHealth(cooperativaId));
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRoutePerformance(
    String cooperativaId,
  ) async {
    final response = await _client.rpc('get_route_performance', params: {
      'coop_id': cooperativaId,
    });

    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTripHistory(
    String cooperativaId, {
    int limit = 50,
  }) async {
    final response = await _client
        .from('trips')
        .select('*, buses!inner(*), routes!inner(name)')
        .filter('buses.cooperativa_id', 'eq', cooperativaId)
        .order('started_at', ascending: false)
        .limit(limit);

    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  }

  @override
  Future<void> createDriver({
    required String cooperativaId,
    required String email,
    required String password,
    required String fullName,
    String? licenseNumber,
  }) async {
    final authResult = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'role': 'conductor'},
      emailRedirectTo: 'io.verve.bussu://login-callback',
    );

    if (authResult.user != null) {
      await _client.from('drivers').insert({
        'id': authResult.user!.id,
        'cooperativa_id': cooperativaId,
        'license_number': licenseNumber,
        'is_active': true,
      });

      await _client.from('profiles').update({
        'cooperativa_id': cooperativaId,
      }).eq('id', authResult.user!.id);
    }
  }

  @override
  Future<void> deleteDriver(String driverId) async {
    await _client.from('drivers').delete().eq('id', driverId);
  }
}
