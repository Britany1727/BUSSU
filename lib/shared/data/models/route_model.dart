import '../../domain/entities/route_entity.dart';
import '../../domain/entities/stop_entity.dart';
import 'stop_model.dart';

/// Modelo de ruta con capacidades de serialización.
class RouteModel extends RouteEntity {
  const RouteModel({
    required super.id,
    super.cooperativaId,
    required super.name,
    super.color = '#001B44',
    super.polyline = const [],
    super.stops = const [],
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    final stopsJson = json['stops'] as List<dynamic>? ?? [];
    final stops = stopsJson
        .map((s) => StopModel.fromJson(s as Map<String, dynamic>))
        .toList();

    final polylineJson = (json['polyline_formatted'] ?? json['polyline']) as List<dynamic>?;
    final polyline = polylineJson
            ?.map((p) => [
                  (p as Map<String, dynamic>)['lat'] as double,
                  (p as Map<String, dynamic>)['lng'] as double,
                ])
            .toList() ??
        [];

    return RouteModel(
      id: json['id'] as String,
      cooperativaId: json['cooperativa_id'] as String?,
      name: json['name'] as String,
      color: json['color'] as String? ?? '#001B44',
      polyline: polyline,
      stops: stops,
    );
  }

  RouteEntity toEntity() => RouteEntity(
        id: id,
        cooperativaId: cooperativaId,
        name: name,
        color: color,
        polyline: polyline,
        stops: stops.map((s) => (s as StopModel).toEntity()).toList(),
      );
}
