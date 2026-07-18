import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/system_alerts_provider.dart';
import '../../domain/entities/municipal_overview.dart';
import '../../domain/entities/cooperativa_status.dart';
import '../../domain/entities/system_alert.dart';

class AdminOverviewPage extends ConsumerWidget {
  final void Function(int index)? onNavigate;
  const AdminOverviewPage({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(municipalOverviewProvider);
    final coopAsync = ref.watch(cooperativasStatusProvider);
    final alertsAsync = ref.watch(systemAlertsProvider);

    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Overview Municipal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF001B44), fontFamily: 'Inter')),
      const SizedBox(height: 16),
      overview.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF001B44))),
        error: (e, _) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error: $e'))),
        data: (MunicipalOverview o) => _buildMetrics(o),
      ),
      const SizedBox(height: 16),
      _buildQuickLinks(context),
      const SizedBox(height: 16),
      _buildCooperativasSummary(coopAsync),
      const SizedBox(height: 16),
      _buildAlertsSummary(alertsAsync),
      const SizedBox(height: 80),
    ]);
  }

  Widget _buildMetrics(MunicipalOverview o) => Column(children: [
    Row(children: [
      _metricCard(Icons.business, '${o.totalCooperativas}', 'Cooperativas', const Color(0xFF001B44)),
      const SizedBox(width: 10),
      _metricCard(Icons.directions_bus, '${o.totalBuses}', 'Buses', const Color(0xFF001B44)),
    ]),
    const SizedBox(height: 10),
    Row(children: [
      _metricCard(Icons.people, '${o.totalDrivers}', 'Conductores', const Color(0xFF001B44)),
      const SizedBox(width: 10),
      _metricCard(Icons.warning_amber, '${o.activeAlerts}', 'Alertas', const Color(0xFFBA1A1A)),
    ]),
  ]);

  Widget _metricCard(IconData icon, String value, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 8)]),
      child: Column(children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color, fontFamily: 'Inter')),
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF434750), fontFamily: 'Inter')),
      ]),
    ),
  );

  Widget _buildQuickLinks(BuildContext ctx) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 8)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Accesos Rápidos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
      const SizedBox(height: 12),
      _linkTile(Icons.business, 'Cooperativas', 'Crear y gestionar cooperativas', () => onNavigate?.call(1)),
      _linkTile(Icons.workspace_premium, 'Premium', 'Administrar suscripciones', () => onNavigate?.call(5)),
      _linkTile(Icons.group, 'Usuarios', 'Gestionar roles y permisos', () => onNavigate?.call(2)),
      _linkTile(Icons.warning_amber, 'Alertas', 'Incidentes del sistema', () => onNavigate?.call(3)),
      _linkTile(Icons.assessment, 'Reportes', 'Reportes municipales', () => onNavigate?.call(6)),
      _linkTile(Icons.settings, 'Configuración', 'Parámetros del sistema', () => onNavigate?.call(8)),
    ]),
  );

  Widget _linkTile(IconData icon, String title, String sub, VoidCallback? onTap) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: ListTile(
      leading: Icon(icon, color: const Color(0xFF001B44)),
      title: Text(title, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Color(0xFF001B44))),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12, fontFamily: 'Inter', color: Color(0xFF434750))),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF434750)),
      dense: true,
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    ),
  );

  Widget _buildCooperativasSummary(AsyncValue<List<CooperativaStatus>> coopAsync) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.business, color: Color(0xFF001B44), size: 20),
          const SizedBox(width: 8),
          const Text('Cooperativas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
        ]),
        const SizedBox(height: 12),
        coopAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF001B44))),
          error: (e, _) => Text('Error: $e'),
          data: (List<CooperativaStatus> coops) {
            if (coops.isEmpty) return const Text('Sin cooperativas', style: TextStyle(color: Color(0xFF434750), fontFamily: 'Inter'));
            return Column(children: coops.take(5).map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                CircleAvatar(radius: 16, backgroundColor: const Color(0xFF001B44), child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
                  Text('${c.activeBuses}/${c.totalBuses} buses · ${c.totalDrivers} conductores', style: const TextStyle(fontSize: 12, color: Color(0xFF434750), fontFamily: 'Inter')),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: (c.activeBuses > 0 ? Colors.green : Colors.grey).withAlpha(20), borderRadius: BorderRadius.circular(6)),
                  child: Text(c.activeBuses > 0 ? 'Activo' : 'Inactivo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, fontFamily: 'Inter', color: c.activeBuses > 0 ? const Color(0xFF1B7A2B) : const Color(0xFF434750))),
                ),
              ]),
            )).toList());
          },
        ),
      ]),
    );
  }

  Widget _buildAlertsSummary(AsyncValue<List<SystemAlert>> alertsAsync) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.warning_amber, color: Color(0xFFBA1A1A), size: 20),
          const SizedBox(width: 8),
          const Text('Alertas Recientes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
        ]),
        const SizedBox(height: 12),
        alertsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF001B44))),
          error: (e, _) => Text('Error: $e'),
          data: (List<SystemAlert> alertList) {
            if (alertList.isEmpty) return const Text('Sin alertas activas', style: TextStyle(color: Color(0xFF434750), fontFamily: 'Inter'));
            return Column(children: alertList.take(5).map((a) {
              Color sevColor;
              if (a.severity == 'high') sevColor = const Color(0xFFBA1A1A);
              else if (a.severity == 'medium') sevColor = const Color(0xFFFED000);
              else sevColor = Colors.blue;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(width: 4, height: 36, decoration: BoxDecoration(color: sevColor, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
                    Text(a.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF434750), fontFamily: 'Inter')),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: a.isResolved ? Colors.green.withAlpha(20) : const Color(0xFFBA1A1A).withAlpha(20), borderRadius: BorderRadius.circular(4)),
                    child: Text(a.isResolved ? 'Resuelto' : 'Pendiente', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'Inter', color: a.isResolved ? const Color(0xFF1B7A2B) : const Color(0xFFBA1A1A))),
                  ),
                ]),
              );
            }).toList());
          },
        ),
      ]),
    );
  }
}
