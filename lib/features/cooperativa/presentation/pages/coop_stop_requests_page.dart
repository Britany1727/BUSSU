import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/fleet_provider.dart';

class CoopStopRequestsPage extends ConsumerStatefulWidget {
  const CoopStopRequestsPage({super.key});
  @override
  ConsumerState<CoopStopRequestsPage> createState() => _CoopStopRequestsPageState();
}

class _CoopStopRequestsPageState extends ConsumerState<CoopStopRequestsPage> {
  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(pendingStopRequestsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Solicitudes de Parada', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Color(0xFF001B44))),
        backgroundColor: const Color(0xFFF8F9FA), elevation: 0,
      ),
      body: requests.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF001B44))),
        error: (_, __) => const Center(child: Text('Error al cargar solicitudes', style: TextStyle(fontFamily: 'Inter'))),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(40),
              child: Text('No hay solicitudes pendientes', style: TextStyle(fontFamily: 'Inter', color: Color(0xFF434750), fontSize: 16)),
            ));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final req = list[i];
              final driver = req['drivers'] as Map<String, dynamic>? ?? {};
              final driverProfile = driver['profiles'] as Map<String, dynamic>? ?? {};
              final driverName = driverProfile['full_name'] as String? ?? 'Conductor';
              final lat = (req['proposed_lat'] as num?)?.toDouble() ?? 0;
              final lng = (req['proposed_lng'] as num?)?.toDouble() ?? 0;
              final justification = req['justification'] as String? ?? '';
              final requestId = req['id'] as String? ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 4)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF001B44),
                        child: Text(driverName.isNotEmpty ? driverName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(driverName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
                          const Text('Solicitud de parada', style: TextStyle(fontSize: 12, color: Color(0xFF434750), fontFamily: 'Inter')),
                        ],
                      )),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFFED000).withAlpha(30), borderRadius: BorderRadius.circular(6)),
                        child: const Text('Pendiente', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF001B44), fontFamily: 'Inter')),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.location_on, size: 14, color: Color(0xFF001B44)),
                      const SizedBox(width: 4),
                      Text('${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}', style: const TextStyle(fontSize: 13, color: Color(0xFF434750), fontFamily: 'Inter')),
                    ]),
                    if (justification.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Motivo: $justification', style: const TextStyle(fontSize: 13, color: Color(0xFF434750), fontFamily: 'Inter')),
                    ],
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () => _reject(requestId),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Rechazar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFBA1A1A),
                          side: const BorderSide(color: Color(0xFFBA1A1A)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: ElevatedButton.icon(
                        onPressed: () => _approve(requestId),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Aprobar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      )),
                    ]),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _approve(String requestId) async {
    final repo = ref.read(fleetRepositoryProvider);
    await repo.approveStopRequest(requestId);
    ref.invalidate(pendingStopRequestsProvider);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud aprobada'), backgroundColor: Colors.green));
  }

  void _reject(String requestId) async {
    final repo = ref.read(fleetRepositoryProvider);
    await repo.rejectStopRequest(requestId);
    ref.invalidate(pendingStopRequestsProvider);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud rechazada'), backgroundColor: Color(0xFFBA1A1A)));
  }
}
