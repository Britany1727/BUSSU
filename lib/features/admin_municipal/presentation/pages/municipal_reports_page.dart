import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/system_alerts_provider.dart';

class MunicipalReportsPage extends ConsumerWidget {
  const MunicipalReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(publicReportProvider);
    final cooperativas = ref.watch(cooperativasStatusProvider);

    return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Reporte Público Municipal', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                report.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('No disponible'),
                  data: (data) => data == null
                      ? const Text('No disponible')
                      : Column(children: [
                          _Row(label: 'Cooperativas activas', value: '${data['total_cooperativas'] ?? 0}'),
                          _Row(label: 'Buses totales', value: '${data['total_buses'] ?? 0}'),
                          _Row(label: 'Buses activos', value: '${data['total_active_buses'] ?? 0}'),
                          _Row(label: 'Pasajeros', value: '${data['total_passengers'] ?? 0}'),
                          _Row(label: 'Alertas sin resolver', value: '${data['unresolved_alerts'] ?? 0}'),
                          _Row(label: 'Salud del sistema', value: '${data['fleet_health_pct'] ?? 0}%'),
                        ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Text('Desglose por Cooperativa', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          cooperativas.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('Error'),
            data: (list) => Column(
              children: list.map((c) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.name, style: Theme.of(context).textTheme.titleSmall),
                      Text('${c.totalBuses} buses · ${c.totalDrivers} conductores', style: Theme.of(context).textTheme.bodySmall),
                    ])),
                    Column(children: [
                      Text('${c.fleetActivityPct.round()}%', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.primary)),
                      Text('activo', style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  ]),
                ),
              )).toList(),
            ),
          ),
        ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  const _Row({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
