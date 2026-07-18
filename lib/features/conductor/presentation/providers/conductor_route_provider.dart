import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/domain/entities/route_entity.dart';
import '../../../../shared/domain/entities/stop_entity.dart';

final conductorRoutesProvider = FutureProvider<List<RouteEntity>>((ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return [];

  final profile = await client.from('profiles').select('cooperativa_id').eq('id', user.id).maybeSingle();
  final cooperativaId = profile?['cooperativa_id'] as String?;
  if (cooperativaId == null) return [];

  final routesData = await client.from('routes').select('id, name, color, cooperativa_id').eq('cooperativa_id', cooperativaId).eq('is_active', true).order('name');

  final routes = <RouteEntity>[];
  for (final r in routesData) {
    final routeId = r['id'] as String;
    final stopsData = await client.from('stops').select('id, name, order_index, lat, lng').eq('route_id', routeId).order('order_index');

    final stops = (stopsData as List).map((s) => StopEntity(
      id: s['id'] as String,
      routeId: routeId,
      name: s['name'] as String,
      latitude: (s['lat'] as num?)?.toDouble() ?? -12.0464,
      longitude: (s['lng'] as num?)?.toDouble() ?? -77.0428,
      orderIndex: s['order_index'] as int? ?? 0,
    )).toList();

    routes.add(RouteEntity(
      id: routeId,
      cooperativaId: cooperativaId,
      name: r['name'] as String,
      color: r['color'] as String? ?? '#001B44',
      stops: stops,
      polyline: stops.map((s) => [s.latitude, s.longitude]).toList(),
    ));
  }
  return routes;
});

final conductorBusesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return [];

  final profile = await client.from('profiles').select('cooperativa_id').eq('id', user.id).maybeSingle();
  final cooperativaId = profile?['cooperativa_id'] as String?;
  if (cooperativaId == null) return [];

  final buses = await client.from('buses').select('id, plate, route_id, capacity').eq('cooperativa_id', cooperativaId).order('plate');
  return (buses as List).cast<Map<String, dynamic>>();
});

final selectedRouteProvider = StateProvider<RouteEntity?>((ref) => null);
final selectedBusProvider = StateProvider<Map<String, dynamic>?>((ref) => null);
