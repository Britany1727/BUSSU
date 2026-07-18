import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/system_alerts_provider.dart';

class PremiumManagementPage extends ConsumerStatefulWidget {
  const PremiumManagementPage({super.key});
  @override
  ConsumerState<PremiumManagementPage> createState() => _PremiumManagementPageState();
}

class _PremiumManagementPageState extends ConsumerState<PremiumManagementPage> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final subsAsync = ref.watch(premiumSubscriptionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: subsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF001B44))),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(fontFamily: 'Inter'))),
        data: (subs) {
          final active = subs.where((s) => s['status'] == 'active').length;
          final expired = subs.where((s) => s['status'] == 'expired').length;
          final suspended = subs.where((s) => s['status'] == 'suspended').length;
          final filtered = _filter == 'all' ? subs : subs.where((s) => s['status'] == _filter).toList();

          return ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFF001B44), borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                const Icon(Icons.workspace_premium, color: Color(0xFFFED000), size: 32),
                const SizedBox(height: 8),
                Text('${subs.length}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Inter')),
                const Text('Usuarios Premium totales', style: TextStyle(fontSize: 14, color: Colors.white70, fontFamily: 'Inter')),
              ]),
            ),
            const SizedBox(height: 16),
            Row(children: [
              _summaryCard('Activos', '$active', Colors.green), const SizedBox(width: 10),
              _summaryCard('Expirados', '$expired', Colors.orange), const SizedBox(width: 10),
              _summaryCard('Suspendidos', '$suspended', const Color(0xFFBA1A1A)),
            ]),
            const SizedBox(height: 16),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              _filterChip('Todos', 'all'), const SizedBox(width: 8),
              _filterChip('Activos', 'active'), const SizedBox(width: 8),
              _filterChip('Expirados', 'expired'), const SizedBox(width: 8),
              _filterChip('Suspendidos', 'suspended'),
            ])),
            const SizedBox(height: 16),
            const Text('Usuarios Premium', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
            const SizedBox(height: 12),
            if (filtered.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('Sin suscripciones en este filtro', style: TextStyle(fontFamily: 'Inter', color: Color(0xFF434750))))),
            ...filtered.map((s) => _buildSubCard(s)),
            const SizedBox(height: 80),
          ]);
        },
      ),
    );
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 8)]),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color, fontFamily: 'Inter')),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF434750), fontFamily: 'Inter')),
      ]),
    ));
  }

  Widget _filterChip(String label, String value) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF001B44) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? const Color(0xFF001B44) : const Color(0xFFE0E0E0)),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFamily: 'Inter',
            color: active ? Colors.white : const Color(0xFF434750))),
      ),
    );
  }

  Widget _buildSubCard(Map<String, dynamic> s) {
    final profile = s['profiles'] as Map<String, dynamic>? ?? {};
    final name = profile['full_name'] as String? ?? 'Usuario';
    final email = profile['email'] as String? ?? '';
    final status = s['status'] as String? ?? 'active';
    final id = s['id'] as String? ?? '';

    final statusColor = status == 'active'
        ? Colors.green
        : status == 'suspended'
            ? const Color(0xFFBA1A1A)
            : Colors.orange;
    final statusText = status == 'active'
        ? 'Activo'
        : status == 'suspended'
            ? 'Suspendido'
            : 'Expirado';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 4)]),
      child: Row(children: [
        CircleAvatar(radius: 20, backgroundColor: const Color(0xFF001B44),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter'))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
          Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF434750), fontFamily: 'Inter'), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: statusColor.withAlpha(20), borderRadius: BorderRadius.circular(6)),
          child: Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Inter', color: statusColor)),
        ),
        const SizedBox(width: 8),
        if (status == 'active')
          IconButton(
            icon: const Icon(Icons.pause_circle_outline, size: 18, color: Color(0xFFBA1A1A)),
            onPressed: () => _updateStatus(id, 'suspended'),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            tooltip: 'Suspender',
          ),
        if (status != 'active')
          IconButton(
            icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
            onPressed: () => _updateStatus(id, 'active'),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            tooltip: 'Activar',
          ),
      ]),
    );
  }

  void _updateStatus(String id, String status) async {
    if (id.isEmpty) return;
    final repo = ref.read(networkMonitorRepositoryProvider);
    final result = await repo.updateSubscriptionStatus(id, status);
    if (!mounted) return;
    ref.invalidate(premiumSubscriptionsProvider);
    result.fold(
      (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${f.message}'), backgroundColor: const Color(0xFFBA1A1A))),
      (_) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == 'active' ? 'Premium activado' : 'Premium suspendido'),
          backgroundColor: status == 'active' ? Colors.green : const Color(0xFF001B44))),
    );
  }
}
