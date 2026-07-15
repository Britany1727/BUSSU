import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/cooperativa_status.dart';
import '../../domain/entities/municipal_overview.dart';
import '../../domain/entities/system_alert.dart';

/// Datasource remoto para el monitoreo de la red completa.
abstract class NetworkMonitorRemoteDataSource {
  Future<Map<String, dynamic>> fetchMunicipalOverview();
  Stream<Map<String, dynamic>> watchMunicipalOverview();

  Future<List<CooperativaStatus>> fetchCooperativasStatus();
  Future<List<Map<String, dynamic>>> fetchCooperativas();
  Future<void> upsertCooperativa(Map<String, dynamic> data);
  Future<void> removeCooperativa(String id);

  Future<List<SystemAlert>> fetchSystemAlerts();
  Stream<List<SystemAlert>> watchSystemAlerts();
  Future<void> insertAlert(Map<String, dynamic> data);
  Future<void> updateAlertStatus(String alertId, DateTime? resolvedAt);
  Future<void> removeAlert(String alertId);

  Future<List<Map<String, dynamic>>> fetchPremiumSubscriptions();
  Future<void> updateSubStatus(String id, String status);

  Future<List<Map<String, dynamic>>> fetchAllUsers();
  Future<void> updateRole(String userId, String role);

  Future<Map<String, dynamic>> fetchPublicReport();

  Future<String> createCooperativaWithAdmin({
    required String name,
    required String ruc,
    required String email,
    required String password,
  });
}

class NetworkMonitorRemoteDataSourceImpl
    implements NetworkMonitorRemoteDataSource {
  final SupabaseClient _client;

  NetworkMonitorRemoteDataSourceImpl(this._client);

  @override
  Future<Map<String, dynamic>> fetchMunicipalOverview() async {
    final coopResult = await _client.from('cooperativas').select('id');
    final busResult = await _client.from('buses').select('id');
    final liveResult = await _client.from('bus_live_position').select('id, passenger_count');

    final totalCooperativas = (coopResult as List<dynamic>).length;
    final totalBuses = (busResult as List<dynamic>).length;
    final activeList = liveResult as List<dynamic>;
    final totalPassengers = activeList.fold<int>(
      0,
      (s, b) => s + ((b as Map<String, dynamic>)['passenger_count'] as int? ?? 0),
    );

    return {
      'total_cooperativas': totalCooperativas,
      'total_buses': totalBuses,
      'total_active_buses': activeList.length,
      'total_drivers': 0,
      'total_passengers': totalPassengers,
      'active_alerts': 0,
      'system_health_pct':
          totalBuses > 0 ? activeList.length / totalBuses * 100 : 0,
    };
  }

  @override
  Stream<Map<String, dynamic>> watchMunicipalOverview() {
    return _client
        .from('bus_live_position')
        .stream(primaryKey: ['bus_id'])
        .asyncMap((_) => fetchMunicipalOverview());
  }

  @override
  Future<List<CooperativaStatus>> fetchCooperativasStatus() async {
    final response = await _client.from('cooperativas').select();
    return (response as List<dynamic>).map((c) {
      final data = c as Map<String, dynamic>;
      return CooperativaStatus(
        id: data['id'] as String,
        name: data['name'] as String,
        ruc: data['ruc'] as String?,
      );
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCooperativas() async {
    final response = await _client.from('cooperativas').select().order('name');
    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  }

  @override
  Future<void> upsertCooperativa(Map<String, dynamic> data) async {
    await _client.from('cooperativas').upsert(data);
  }

  @override
  Future<void> removeCooperativa(String id) async {
    await _client.from('cooperativas').delete().eq('id', id);
  }

  @override
  Future<List<SystemAlert>> fetchSystemAlerts() async {
    final response = await _client
        .from('system_alerts')
        .select()
        .order('created_at', ascending: false)
        .limit(50);

    return (response as List<dynamic>).map((a) {
      final data = a as Map<String, dynamic>;
      return SystemAlert(
        id: data['id'] as String,
        scope: data['scope'] as String? ?? 'system',
        severity: data['severity'] as String? ?? 'low',
        title: data['title'] as String? ?? '',
        description: data['description'] as String? ?? '',
        routeId: data['route_id'] as String?,
        createdAt: DateTime.parse(
            data['created_at'] as String? ?? DateTime.now().toIso8601String()),
        resolvedAt: data['resolved_at'] != null
            ? DateTime.parse(data['resolved_at'] as String)
            : null,
      );
    }).toList();
  }

  @override
  Stream<List<SystemAlert>> watchSystemAlerts() {
    return _client
        .from('system_alerts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(50)
        .asyncMap((_) => fetchSystemAlerts());
  }

  @override
  Future<void> insertAlert(Map<String, dynamic> data) async {
    await _client.from('system_alerts').insert(data);
  }

  @override
  Future<void> updateAlertStatus(String alertId, DateTime? resolvedAt) async {
    await _client
        .from('system_alerts')
        .update({'resolved_at': resolvedAt?.toIso8601String()})
        .eq('id', alertId);
  }

  @override
  Future<void> removeAlert(String alertId) async {
    await _client.from('system_alerts').delete().eq('id', alertId);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPremiumSubscriptions() async {
    final response = await _client
        .from('premium_subscriptions')
        .select('*, profiles(full_name, email)')
        .order('started_at', ascending: false)
        .limit(100);

    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  }

  @override
  Future<void> updateSubStatus(String id, String status) async {
    await _client
        .from('premium_subscriptions')
        .update({'status': status}).eq('id', id);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    final response = await _client
        .from('profiles')
        .select('id, full_name, email, role, is_premium, created_at')
        .order('created_at', ascending: false)
        .limit(200);

    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  }

  @override
  Future<void> updateRole(String userId, String role) async {
    await _client
        .from('profiles')
        .update({'role': role}).eq('id', userId);
  }

  @override
  Future<Map<String, dynamic>> fetchPublicReport() async {
    final overview = await fetchMunicipalOverview();
    final alertsResult = await _client.from('system_alerts').select('id');

    return {
      ...overview,
      'unresolved_alerts': (alertsResult as List<dynamic>).length,
      'generated_at': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<String> createCooperativaWithAdmin({
    required String name,
    required String ruc,
    required String email,
    required String password,
  }) async {
    final coopResult = await _client.from('cooperativas').insert({
      'name': name,
      'ruc': ruc,
      'status': 'active',
    }).select('id').single();

    final coopId = coopResult['id'] as String;

    final authResult = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name, 'role': 'cooperativa_admin'},
      emailRedirectTo: 'io.verve.bussu://login-callback',
    );

    if (authResult.user != null) {
      await _client.from('profiles').update({
        'cooperativa_id': coopId,
        'role': 'cooperativa_admin',
      }).eq('id', authResult.user!.id);
    }

    return coopId;
  }
}
