import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../admin_municipal/domain/entities/system_alert.dart';
import '../../../admin_municipal/presentation/providers/system_alerts_provider.dart';

class AlertsPage extends ConsumerWidget {
  const AlertsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(systemAlertsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Alertas', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Color(0xFF001B44))), backgroundColor: const Color(0xFFF8F9FA), elevation: 0),
      body: alertsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF001B44))),
        error: (_, __) => const Center(child: Text('Error al cargar alertas')),
        data: (alerts) {
          if (alerts.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.notifications_none, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16), const Text('No hay alertas activas', style: TextStyle(fontFamily: 'Inter', fontSize: 16, color: Color(0xFF434750))),
            const SizedBox(height: 4), const Text('Te notificaremos cuando haya novedades', style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFFBDBDBD))),
          ]));
          final active = alerts.where((a) => !a.isResolved).toList();
          final resolved = alerts.where((a) => a.isResolved).toList();
          return ListView(padding: const EdgeInsets.all(16), children: [
            if (active.isNotEmpty) ...[
              Row(children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFBA1A1A), shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('Activas (${active.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
              ]),
              const SizedBox(height: 12),
              ...active.map((a) => _buildAlertCard(a)),
            ],
            if (resolved.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.green[300], shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('Resueltas (${resolved.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF434750), fontFamily: 'Inter')),
              ]),
              const SizedBox(height: 12),
              ...resolved.map((a) => _buildAlertCard(a)),
            ],
          ]);
        },
      ),
    );
  }

  Widget _buildAlertCard(SystemAlert a) {
    final color = a.severity == 'high' ? const Color(0xFFBA1A1A)
        : a.severity == 'medium' ? const Color(0xFFFED000)
        : const Color(0xFF2196F3);
    final IconData icon = a.severity == 'high' ? Icons.error_outline
        : a.severity == 'medium' ? Icons.warning_amber_outlined
        : Icons.info_outline;
    final scopeLabel = a.scope == 'route' ? 'Ruta' : a.scope == 'stop' ? 'Parada' : 'Sistema';
    final timeAgo = _timeAgo(a.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: a.isResolved ? Colors.white70 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: a.isResolved ? Colors.grey.shade300 : color, width: 4)),
        boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 8)],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: (a.isResolved ? Colors.green : color).withAlpha(20), borderRadius: BorderRadius.circular(8)),
            child: Icon(a.isResolved ? Icons.check_circle : icon, color: a.isResolved ? Colors.green : color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF001B44), fontFamily: 'Inter', decoration: a.isResolved ? TextDecoration.lineThrough : null)),
            const SizedBox(height: 2),
            Text(timeAgo, style: const TextStyle(fontSize: 11, color: Color(0xFFBDBDBD), fontFamily: 'Inter')),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: a.isResolved ? Colors.green.withAlpha(20) : color.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(scopeLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, fontFamily: 'Inter', color: a.isResolved ? Colors.green.shade700 : color)),
          ),
        ]),
        if (a.description.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(a.description, style: TextStyle(fontSize: 13, color: const Color(0xFF434750), fontFamily: 'Inter', decoration: a.isResolved ? TextDecoration.lineThrough : null), maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ]),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
