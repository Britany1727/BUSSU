import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Datasource de telemetría OBD del bus.
///
/// En producción, este datasource interactúa con el servicio puente
/// MQTT→Supabase. La telemetría real la genera el firmware del ESP32.
/// Este datasource publica comandos y confirma que el hardware está
/// transmitiendo correctamente.
abstract class ObdTelemetryDataSource {
  /// Publica telemetría del bus.
  Future<void> publishTelemetry({
    required String busId,
    required double lat,
    required double lng,
    required double speedKmh,
    required double heading,
  });

  /// Verifica el estado de conexión del hardware del bus.
  Future<BusHardwareStatus> checkHardwareStatus(String busId);

  /// Stream del estado del hardware del bus.
  Stream<BusHardwareStatus> watchHardwareStatus(String busId);
}

/// Estado del hardware del bus.
class BusHardwareStatus {
  final String busId;
  final bool isOnline;
  final bool isGpsLocked;
  final bool isObdConnected;
  final DateTime lastTelemetryAt;

  const BusHardwareStatus({
    required this.busId,
    this.isOnline = false,
    this.isGpsLocked = false,
    this.isObdConnected = false,
    required this.lastTelemetryAt,
  });

  bool get isFullyOperational =>
      isOnline && isGpsLocked && isObdConnected;
}

class ObdTelemetryDataSourceImpl implements ObdTelemetryDataSource {
  final SupabaseClient _client;

  ObdTelemetryDataSourceImpl(this._client);

  @override
  Future<void> publishTelemetry({
    required String busId,
    required double lat,
    required double lng,
    required double speedKmh,
    required double heading,
  }) async {
    await _client.rpc('update_bus_position', params: {
      'p_bus_id': busId,
      'p_lat': lat,
      'p_lng': lng,
      'p_speed': speedKmh,
      'p_heading': heading,
      'p_passenger_count': 0,
    });

    await _client.rpc('insert_telemetry_history', params: {
      'p_bus_id': busId,
      'p_lat': lat,
      'p_lng': lng,
      'p_speed': speedKmh,
      'p_passenger_count': 0,
    });
  }

  @override
  Future<BusHardwareStatus> checkHardwareStatus(String busId) async {
    try {
      final response = await _client
          .from('bus_live_position')
          .select('updated_at')
          .eq('bus_id', busId)
          .single();

      final updatedAt = response['updated_at'] as String?;
      final lastTelemetry = updatedAt != null
          ? DateTime.parse(updatedAt)
          : DateTime(2000);

      final isOnline = DateTime.now().difference(lastTelemetry).inSeconds < 30;

      return BusHardwareStatus(
        busId: busId,
        isOnline: isOnline,
        isGpsLocked: isOnline,
        isObdConnected: isOnline,
        lastTelemetryAt: lastTelemetry,
      );
    } catch (_) {
      return BusHardwareStatus(
        busId: busId,
        lastTelemetryAt: DateTime(2000),
      );
    }
  }

  @override
  Stream<BusHardwareStatus> watchHardwareStatus(String busId) {
    return _client
        .from('bus_live_position')
        .stream(primaryKey: ['bus_id'])
        .eq('bus_id', busId)
        .map((rows) {
      if (rows.isEmpty) {
        return BusHardwareStatus(
          busId: busId,
          lastTelemetryAt: DateTime(2000),
        );
      }
      final row = rows.first as Map<String, dynamic>;
      final updatedAt = row['updated_at'] as String?;
      return BusHardwareStatus(
        busId: busId,
        isOnline: true,
        isGpsLocked: true,
        isObdConnected: true,
        lastTelemetryAt: updatedAt != null
            ? DateTime.parse(updatedAt)
            : DateTime.now(),
      );
    });
  }
}
