import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/security/output_sanitizer.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/domain/entities/route_entity.dart';
import '../../../../shared/domain/entities/stop_entity.dart';
import '../../../usuario/presentation/providers/directions_provider.dart';
import '../providers/fleet_provider.dart';

class RoutesManagementPage extends ConsumerStatefulWidget {
  const RoutesManagementPage({super.key});
  @override
  ConsumerState<RoutesManagementPage> createState() => _RoutesManagementPageState();
}

class _RoutesManagementPageState extends ConsumerState<RoutesManagementPage> {
  final _nameCtrl = TextEditingController();
  final _slatCtrl = TextEditingController();
  final _slngCtrl = TextEditingController();
  final _elatCtrl = TextEditingController();
  final _elngCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose(); _slatCtrl.dispose(); _slngCtrl.dispose();
    _elatCtrl.dispose(); _elngCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coopId = ref.watch(currentCoopIdProvider);
    final routesAsync = ref.watch(routesProvider(coopId));

    return Stack(
      children: [
        routesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (routes) => routes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.route_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No hay rutas creadas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF434750), fontFamily: 'Inter')),
                      const SizedBox(height: 8),
                      const Text('Presiona + para crear una ruta', style: TextStyle(fontSize: 13, color: Color(0xFF434750), fontFamily: 'Inter')),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: routes.length,
                  itemBuilder: (_, i) {
                    final r = routes[i];
                    final distKm = _polylineDistance(r.polyline);
                    final colorVal = int.parse('FF${r.color.replaceAll('#', '')}', radix: 16);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: Container(
                          width: 12, height: 12,
                          decoration: BoxDecoration(
                            color: Color(colorVal),
                            shape: BoxShape.circle)),
                        title: Text(r.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter', color: Color(0xFF001B44))),
                        subtitle: Text('${r.stops.length} paradas · ${distKm.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 12, fontFamily: 'Inter', color: Color(0xFF434750))),
                        trailing: PopupMenuButton(
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Text('Editar nombre')),
                            const PopupMenuItem(value: 'stops', child: Text('Gestionar paradas')),
                            const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Color(0xFFBA1A1A)))),
                          ],
                          onSelected: (action) {
                            if (action == 'edit') _showEditDialog(r);
                            if (action == 'stops') _showStopsManager(r);
                            if (action == 'delete') _confirmDeleteRoute(r, coopId);
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
        Positioned(
          right: 16, bottom: 16,
          child: FloatingActionButton(
            onPressed: () => _showCreateDialog(),
            backgroundColor: const Color(0xFF001B44),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  double _polylineDistance(List<List<double>> polyline) {
    if (polyline.length < 2) return 0;
    double d = 0;
    for (int i = 1; i < polyline.length; i++) {
      final dlat = polyline[i][0] - polyline[i - 1][0];
      final dlng = polyline[i][1] - polyline[i - 1][1];
      final latMid = (polyline[i][0] + polyline[i - 1][0]) / 2;
      const mPerLat = 111320.0;
      final mPerLng = 111320.0 * cos(latMid * pi / 180);
      final dx = dlat * mPerLat;
      final dy = dlng * mPerLng;
      d += sqrt(dx * dx + dy * dy);
    }
    return d / 1000;
  }

  void _showCreateDialog() {
    _nameCtrl.clear(); _slatCtrl.clear(); _slngCtrl.clear();
    _elatCtrl.clear(); _elngCtrl.clear();
    _slatCtrl.text = '-12.0464'; _slngCtrl.text = '-77.0428';
    _elatCtrl.text = '-12.0430'; _elngCtrl.text = '-77.0370';

    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Nueva Ruta'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nombre de la ruta')),
        const SizedBox(height: 12),
        const Text('Coordenadas de inicio', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Row(children: [
          Expanded(child: TextField(controller: _slatCtrl, decoration: const InputDecoration(labelText: 'Lat', isDense: true), keyboardType: TextInputType.number)),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _slngCtrl, decoration: const InputDecoration(labelText: 'Lng', isDense: true), keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 12),
        const Text('Coordenadas de fin', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Row(children: [
          Expanded(child: TextField(controller: _elatCtrl, decoration: const InputDecoration(labelText: 'Lat', isDense: true), keyboardType: TextInputType.number)),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _elngCtrl, decoration: const InputDecoration(labelText: 'Lng', isDense: true), keyboardType: TextInputType.number)),
        ]),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () async {
          final name = OutputSanitizer.sanitizeName(_nameCtrl.text);
          final nameError = Validators.validateRequired(name, 'Nombre');
          if (nameError != null) return;

          final slat = double.tryParse(_slatCtrl.text) ?? 0;
          final slng = double.tryParse(_slngCtrl.text) ?? 0;
          final elat = double.tryParse(_elatCtrl.text) ?? 0;
          final elng = double.tryParse(_elngCtrl.text) ?? 0;

          final directions = await ref.read(directionsProvider((
            slat: slat, slng: slng, elat: elat, elng: elng,
          )).future);

          if (!mounted) return;
          Navigator.pop(context);

          final repo = ref.read(fleetRepositoryProvider);
          final coopId = ref.read(currentCoopIdProvider);

          final result = await repo.updateRoute(RouteEntity(
            id: '',
            cooperativaId: coopId,
            name: name,
            polyline: directions?.polyline ?? [],
          ));
          ref.invalidate(routesProvider(coopId));
          if (mounted) {
            result.fold(
              (failure) => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error al crear ruta: ${failure.message}'), backgroundColor: const Color(0xFFBA1A1A))),
              (_) => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(directions != null
                  ? 'Ruta creada: ${(directions.distanceMeters / 1000).toStringAsFixed(1)} km'
                  : 'Ruta creada sin geometria ORS'), backgroundColor: const Color(0xFF001B44))),
            );
          }
        }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF001B44), foregroundColor: Colors.white), child: const Text('Crear')),
      ],
    ));
  }

  void _showEditDialog(RouteEntity route) {
    _nameCtrl.text = route.name;
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Editar Ruta'),
      content: TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () async {
          final name = OutputSanitizer.sanitizeName(_nameCtrl.text);
          final nameError = Validators.validateRequired(name, 'Nombre');
          if (nameError != null) return;
          Navigator.pop(context);
          final result = await ref.read(fleetRepositoryProvider).updateRoute(route.copyWith(name: name));
          ref.invalidate(routesProvider(ref.read(currentCoopIdProvider)));
          if (mounted) {
            result.fold(
              (failure) => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: ${failure.message}'), backgroundColor: const Color(0xFFBA1A1A))),
              (_) => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nombre actualizado'), backgroundColor: Color(0xFF001B44))),
            );
          }
        }, child: const Text('Guardar')),
      ],
    ));
  }

  void _showStopsManager(RouteEntity route) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _StopsManagerPage(routeId: route.id, routeName: route.name),
    ));
  }

  void _confirmDeleteRoute(RouteEntity route, String coopId) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Eliminar ruta'),
      content: Text('¿Eliminar la ruta "${route.name}"? Esta accion no se puede deshacer.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            await ref.read(fleetRepositoryProvider).deleteRoute(route.id);
            ref.invalidate(routesProvider(coopId));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Ruta "${route.name}" eliminada'), backgroundColor: const Color(0xFFBA1A1A)));
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBA1A1A), foregroundColor: Colors.white),
          child: const Text('Eliminar'),
        ),
      ],
    ));
  }
}

class _StopsManagerPage extends ConsumerStatefulWidget {
  final String routeId;
  final String routeName;
  const _StopsManagerPage({required this.routeId, required this.routeName});

  @override
  ConsumerState<_StopsManagerPage> createState() => _StopsManagerPageState();
}

class _StopsManagerPageState extends ConsumerState<_StopsManagerPage> {
  List<StopEntity> _stops = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStops();
  }

  Future<void> _loadStops() async {
    setState(() => _loading = true);
    try {
      final response = await Supabase.instance.client
          .from('stops')
          .select()
          .eq('route_id', widget.routeId)
          .order('order_index');
      _stops = (response as List<dynamic>).map((s) => StopEntity(
        id: s['id'] as String,
        routeId: s['route_id'] as String?,
        name: s['name'] as String,
        latitude: (s['lat'] as num?)?.toDouble() ?? 0,
        longitude: (s['lng'] as num?)?.toDouble() ?? 0,
        orderIndex: s['order_index'] as int,
      )).toList();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Paradas - ${widget.routeName}', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF001B44),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stops.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.place_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No hay paradas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF434750))),
                      const SizedBox(height: 8),
                      const Text('Presiona + para agregar una parada', style: TextStyle(fontSize: 13, color: Color(0xFF434750))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _stops.length,
                  itemBuilder: (_, i) {
                    final s = _stops[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF001B44),
                          child: Text('${s.orderIndex}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                        title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                        subtitle: Text('${s.latitude.toStringAsFixed(4)}, ${s.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 12, fontFamily: 'Inter')),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFBA1A1A)),
                          onPressed: () => _deleteStop(s),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addStopDialog(),
        backgroundColor: const Color(0xFF001B44),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _addStopDialog() {
    final nameCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    latCtrl.text = '-12.0464';
    lngCtrl.text = '-77.0428';

    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Nueva Parada'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre de la parada')),
        const SizedBox(height: 12),
        TextField(controller: latCtrl, decoration: const InputDecoration(labelText: 'Latitud'), keyboardType: TextInputType.number),
        const SizedBox(height: 8),
        TextField(controller: lngCtrl, decoration: const InputDecoration(labelText: 'Longitud'), keyboardType: TextInputType.number),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () async {
          final name = OutputSanitizer.sanitizeName(nameCtrl.text);
          if (name.isEmpty) return;
          final lat = double.tryParse(latCtrl.text);
          final lng = double.tryParse(lngCtrl.text);
          if (lat == null || lng == null) return;
          Navigator.pop(context);

          final nextOrder = _stops.length + 1;
          await Supabase.instance.client.from('stops').insert({
            'route_id': widget.routeId,
            'name': name,
            'location': 'POINT($lng $lat)',
            'order_index': nextOrder,
          });
          await _loadStops();
        }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF001B44), foregroundColor: Colors.white),
            child: const Text('Agregar')),
      ],
    ));
  }

  Future<void> _deleteStop(StopEntity stop) async {
    await Supabase.instance.client.from('stops').delete().eq('id', stop.id);
    await _loadStops();
  }
}
