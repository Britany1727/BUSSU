import 'package:supabase_flutter/supabase_flutter.dart';

/// Datasource remoto para operaciones de ETA y rutas.
///
/// Centraliza todas las consultas a Supabase relacionadas con
/// cálculo de ETA, rutas y paradas que antes estaban acopladas
/// directamente en [EtaRepositoryImpl].
abstract class EtaRemoteDataSource {
  /// Obtiene la posición actual de un bus para cálculo de ETA.
  Future<Map<String, dynamic>?> fetchBusPosition(String busId);

  /// Obtiene los datos de una parada (distance_along_route, route_id).
  Future<Map<String, dynamic>?> fetchStopData(String stopId);

  /// Obtiene la polyline de una ruta.
  Future<List<List<double>>?> fetchRoutePolyline(String routeId);

  /// Obtiene todas las rutas con sus paradas.
  Future<List<Map<String, dynamic>>> fetchAvailableRoutes();

  /// Obtiene una ruta con sus buses activos.
  Future<Map<String, dynamic>?> fetchRouteWithBuses(String routeId);

  /// Stream de posición de bus en tiempo real.
  Stream<List<Map<String, dynamic>>> watchBusPosition(String busId);

  /// Obtiene las paradas de una ruta.
  Future<List<Map<String, dynamic>>> fetchRouteStops(String routeId);
}

class EtaRemoteDataSourceImpl implements EtaRemoteDataSource {
  final SupabaseClient _client;

  EtaRemoteDataSourceImpl(this._client);

  @override
  Future<Map<String, dynamic>?> fetchBusPosition(String busId) async {
    try {
      final result = await _client
          .from('bus_live_position')
          .select()
          .eq('bus_id', busId)
          .single();
      return result as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchStopData(String stopId) async {
    try {
      final result = await _client
          .from('stops')
          .select('distance_along_route, route_id')
          .eq('id', stopId)
          .single();
      return result as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<List<double>>?> fetchRoutePolyline(String routeId) async {
    try {
      final result = await _client.rpc('get_route_polyline', params: {
        'p_route_id': routeId,
      });

      final polylineData = result as List<dynamic>;
      return polylineData
          .map((p) => [
                (p as Map<String, dynamic>)['lat'] as double,
                p['lng'] as double,
              ])
          .toList();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAvailableRoutes() async {
    final response =
        await _client.from('routes_for_app').select('*, stops(*)').order('name');
    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>?> fetchRouteWithBuses(String routeId) async {
    try {
      final routeResult = await _client
          .from('routes_for_app')
          .select('*, stops(*)')
          .eq('id', routeId)
          .single();

      final busesResult = await _client
          .from('bus_live_position')
          .select()
          .eq('route_id', routeId);

      return {
        'route': routeResult,
        'buses': busesResult,
      };
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> watchBusPosition(String busId) {
    return _client
        .from('bus_live_position')
        .stream(primaryKey: ['bus_id'])
        .eq('bus_id', busId)
        .map((rows) => (rows as List<dynamic>).cast<Map<String, dynamic>>());
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRouteStops(String routeId) async {
    final response = await _client
        .from('stops')
        .select()
        .eq('route_id', routeId)
        .order('order_index');
    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  }
}
