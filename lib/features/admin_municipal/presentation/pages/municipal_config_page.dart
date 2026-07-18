import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final geofenceRadiusProvider = StateProvider<double>((ref) => 30);
final telemetryIntervalProvider = StateProvider<int>((ref) => 5);
final busTimeoutProvider = StateProvider<int>((ref) => 30);
final etaSmoothingProvider = StateProvider<int>((ref) => 6);
final maxBusesProvider = StateProvider<int>((ref) => 200);
final maxDriversProvider = StateProvider<int>((ref) => 500);
final retentionDaysProvider = StateProvider<int>((ref) => 90);

class MunicipalConfigPage extends ConsumerWidget {
  const MunicipalConfigPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(padding: const EdgeInsets.all(16), children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 8)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Parámetros del Sistema', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
          const SizedBox(height: 12),
          _ConfigTile(label: 'Radio de geocerca', value: '${ref.watch(geofenceRadiusProvider).round()} m'),
          _ConfigTile(label: 'Intervalo de telemetría', value: '${ref.watch(telemetryIntervalProvider)} s'),
          _ConfigTile(label: 'Timeout de bus inactivo', value: '${ref.watch(busTimeoutProvider)} s'),
          _ConfigTile(label: 'Ventana suavizado ETA', value: '${ref.watch(etaSmoothingProvider)} lecturas'),
        ])),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 8)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Límites del Sistema', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
          const SizedBox(height: 12),
          _ConfigTile(label: 'Máx. buses por cooperativa', value: '${ref.watch(maxBusesProvider)}'),
          _ConfigTile(label: 'Máx. conductores', value: '${ref.watch(maxDriversProvider)}'),
          _ConfigTile(label: 'Retención de telemetría', value: '${ref.watch(retentionDaysProvider)} días'),
        ])),
      ],
    );
  }
}

class _ConfigTile extends StatelessWidget {
  final String label, value;
  const _ConfigTile({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF001B44), fontFamily: 'Inter')),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
    ]));
  }
}
