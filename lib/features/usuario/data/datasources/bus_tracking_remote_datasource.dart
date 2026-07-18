import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../shared/data/models/bus_model.dart';

/// Datasource remoto de seguimiento de buses usando Supabase Realtime.
abstract class BusTrackingRemoteDataSource {
  /// Stream de posición en tiempo real para un bus.
  Stream<List<BusModel>> watchBusPosition(String busId);

  /// Stream de posición en tiempo real para todos los buses de una ruta.
  Stream<List<BusModel>> watchRouteBuses(String routeId);

  /// Obtiene la posición actual (snapshot) de un bus.
  Future<BusModel?> getBusPosition(String busId);

  /// Obtiene las paradas de una ruta.
  Future<List<Map<String, dynamic>>> getRouteStops(String routeId);
}

class BusTrackingRemoteDataSourceImpl
    implements BusTrackingRemoteDataSource {
  final SupabaseClient _client;

  BusTrackingRemoteDataSourceImpl(this._client);

  @override
  Stream<List<BusModel>> watchBusPosition(String busId) {
    final channel = _client.channel('bus_tracking_$busId');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'bus_live_position',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'bus_id',
        value: busId,
      ),
      callback: (payload) {
        // Stream manejado internamente
      },
    ).subscribe();

    final stream = _client
        .from('bus_live_position')
        .stream(primaryKey: ['bus_id'])
        .eq('bus_id', busId)
        .map((rows) => rows
            .map((row) => BusModel.fromRealtime(row as Map<String, dynamic>))
            .toList());

    return stream;
  }

  @override
  Stream<List<BusModel>> watchRouteBuses(String routeId) {
    return _client
        .from('bus_live_position')
        .stream(primaryKey: ['bus_id'])
        .map((rows) => rows
            .map((row) => BusModel.fromRealtime(row as Map<String, dynamic>))
            .where((bus) => bus.routeId == routeId)
            .toList());
  }

  @override
  Future<BusModel?> getBusPosition(String busId) async {
    try {
      final response = await _client
          .from('bus_live_position')
          .select('*, buses!inner(plate, cooperativa_id)')
          .eq('bus_id', busId)
          .single();

      final data = response as Map<String, dynamic>;
      final busData = data['buses'] as Map<String, dynamic>? ?? {};

      return BusModel.fromRealtime({
        ...data,
        'plate': busData['plate'] ?? '',
        'cooperativa_id': busData['cooperativa_id'],
      });
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getRouteStops(String routeId) async {
    try {
      final response = await _client
          .from('stops')
          .select()
          .eq('route_id', routeId)
          .order('order_index');

      return (response as List<dynamic>)
          .map((r) => r as Map<String, dynamic>)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
