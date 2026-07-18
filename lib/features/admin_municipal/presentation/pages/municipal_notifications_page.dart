import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final systemAlertsEnabledProvider = StateProvider<bool>((ref) => true);
final autoReportsEnabledProvider = StateProvider<bool>((ref) => false);
final newCoopNotifyProvider = StateProvider<bool>((ref) => true);

class MunicipalNotificationsPage extends ConsumerWidget {
  const MunicipalNotificationsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(padding: const EdgeInsets.all(16), children: [
        Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 8)]), child: Column(children: [
          SwitchListTile(title: const Text('Alertas del sistema', style: TextStyle(fontFamily: 'Inter', color: Color(0xFF001B44))), subtitle: const Text('Notificar incidentes', style: TextStyle(fontFamily: 'Inter')), value: ref.watch(systemAlertsEnabledProvider), onChanged: (v) => ref.read(systemAlertsEnabledProvider.notifier).state = v),
          SwitchListTile(title: const Text('Reportes automáticos', style: TextStyle(fontFamily: 'Inter', color: Color(0xFF001B44))), subtitle: const Text('Semanal a cooperativas', style: TextStyle(fontFamily: 'Inter')), value: ref.watch(autoReportsEnabledProvider), onChanged: (v) => ref.read(autoReportsEnabledProvider.notifier).state = v),
          SwitchListTile(title: const Text('Nuevos registros', style: TextStyle(fontFamily: 'Inter', color: Color(0xFF001B44))), subtitle: const Text('Alertar nueva cooperativa', style: TextStyle(fontFamily: 'Inter')), value: ref.watch(newCoopNotifyProvider), onChanged: (v) => ref.read(newCoopNotifyProvider.notifier).state = v),
        ])),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 8)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Webhooks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
          const SizedBox(height: 8),
          ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.check, color: Colors.green, size: 18)), title: const Text('bus_arrival_push'), subtitle: const Text('bus_stop_events → Edge Function'), contentPadding: EdgeInsets.zero),
          ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFFFFF8E1), child: Icon(Icons.warning_amber, color: Color(0xFFFED000), size: 18)), title: const Text('trip_started_notify'), subtitle: const Text('trips INSERT → Edge Function'), contentPadding: EdgeInsets.zero),
        ])),
      ],
    );
  }
}
