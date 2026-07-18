import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/maps/marker_service.dart';
import '../../../../core/maps/tile_provider.dart';
import '../../../../shared/domain/entities/stop_entity.dart';
import '../../../../shared/presentation/providers/location_provider.dart';
import '../../../../shared/presentation/widgets/live_map_widget.dart';
import '../providers/fleet_provider.dart';

class CoopStopsPage extends ConsumerStatefulWidget {
  const CoopStopsPage({super.key});
  @override
  ConsumerState<CoopStopsPage> createState() => _CoopStopsPageState();
}

class _CoopStopsPageState extends ConsumerState<CoopStopsPage> {
  int _tabIdx = 0;
  late final TextEditingController _nameCtrl;
  LatLng? _newStopPos;
  int? _editingIdx;
  int? _movingIdx;
  final MarkerService _markerService = const MarkerService();
  final MapController _reqMapCtrl = MapController();
  final MapController _mainMapCtrl = MapController();

  final List<Map<String, dynamic>> _stopsList = [
    {'name': 'Plaza de Armas', 'route': 'Ruta A', 'order': '1', 'lat': -12.045, 'lng': -77.031},
    {'name': 'Jr. de la Union', 'route': 'Ruta A', 'order': '2', 'lat': -12.046, 'lng': -77.032},
    {'name': 'Parque Universitario', 'route': 'Ruta A', 'order': '3', 'lat': -12.047, 'lng': -77.033},
    {'name': 'Parque Kennedy', 'route': 'Ruta B', 'order': '1', 'lat': -12.048, 'lng': -77.034},
    {'name': 'Larcomar', 'route': 'Ruta B', 'order': '2', 'lat': -12.049, 'lng': -77.035},
  ];

  @override
  void initState() { super.initState(); _nameCtrl = TextEditingController(); }
  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  List<StopEntity> _buildStops() => _stopsList.map((s) => StopEntity(
    id: s['order'].toString(), name: s['name'] as String,
    latitude: (s['lat'] as num).toDouble(), longitude: (s['lng'] as num).toDouble(),
    orderIndex: int.tryParse(s['order'].toString()) ?? 0,
  )).toList();

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingStopRequestsProvider);
    final stops = _buildStops();
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Row(children: [
        const Text('Paradas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF001B44), fontFamily: 'Inter')),
        const Spacer(),
        Container(decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [
          _buildTabBtn(0, 'Mapa'), _buildTabBtn(1, 'Solicitudes'),
        ])),
      ])),
      const SizedBox(height: 8),
      Expanded(child: _tabIdx == 0 ? _buildMapView(stops) : _buildRequestsView()),
    ]);
  }

  Widget _buildTabBtn(int idx, String label) {
    final active = _tabIdx == idx;
    return GestureDetector(onTap: () => setState(() { _tabIdx = idx; _movingIdx = null; _editingIdx = null; }), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: active ? const Color(0xFF001B44) : Colors.transparent, borderRadius: BorderRadius.circular(8)), child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter', color: active ? Colors.white : const Color(0xFF434750)))));
  }

  Widget _buildMapView(List<StopEntity> stops) {
    final pinMarkers = _newStopPos != null ? [_markerService.createRequestMarker(id: 'new', point: _newStopPos!, title: 'Nueva')] : <Marker>[];

    return Column(children: [
      Expanded(child: Stack(children: [
        LiveMapWidget(
          initialCenter: const LatLng(-12.0464, -77.0428), initialZoom: 14,
          stops: stops,
          extraMarkers: pinMarkers,
          externalMapController: _mainMapCtrl,
          onMapTapped: (pos) {
            if (_movingIdx != null) {
              setState(() { _stopsList[_movingIdx!]['lat'] = pos.latitude; _stopsList[_movingIdx!]['lng'] = pos.longitude; _movingIdx = null; });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parada movida'), backgroundColor: Color(0xFF001B44)));
            } else {
              setState(() => _newStopPos = pos);
            }
          },
        ),
        Positioned(right: 12, bottom: 12, child: FloatingActionButton.small(
          onPressed: () async {
            final svc = ref.read(locationServiceProvider);
            final loc = await svc.getCurrentLocation();
            loc.fold((f) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message), backgroundColor: const Color(0xFFBA1A1A)));
            }, (l) {
              final pos = LatLng(l.latitude, l.longitude);
              _mainMapCtrl.move(pos, 15);
            });
          },
          backgroundColor: Colors.white,
          child: const Icon(Icons.my_location, color: Color(0xFF001B44)),
        )),
      ])),
      if (_movingIdx != null) Container(width: double.infinity, color: Colors.orange.shade100, padding: const EdgeInsets.all(10), child: const Row(children: [Icon(Icons.touch_app, size: 18), SizedBox(width: 8), Text('Toca el mapa para mover la parada', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))])),
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'Nombre de la nueva parada', hintStyle: TextStyle(fontSize: 13, fontFamily: 'Inter'), border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Color(0xFFE0E0E0))), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)))),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: _editingIdx != null ? _saveEdit : _addStop, style: ElevatedButton.styleFrom(backgroundColor: _editingIdx != null ? const Color(0xFF001B44) : const Color(0xFFFED000), foregroundColor: _editingIdx != null ? Colors.white : const Color(0xFF001B44), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: Text(_editingIdx != null ? 'Guardar' : 'Agregar', style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter'))),
      ])),
      SizedBox(height: 160, child: _buildStopList()),
    ]);
  }

  Widget _buildStopList() {
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: List.generate(_stopsList.length, (i) {
      final s = _stopsList[i];
      final isEditing = _editingIdx == i;
      final isMoving = _movingIdx == i;
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: isMoving ? Colors.orange.shade50 : isEditing ? Colors.blue.shade50 : Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 4)]),
        child: Row(children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(color: const Color(0xFF001B44).withAlpha(20), borderRadius: BorderRadius.circular(8)), child: Center(child: Text(s['order'].toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF001B44))))),
          const SizedBox(width: 12),
          Expanded(child: Text(s['name'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Inter', color: Color(0xFF001B44)))),
          IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF434750)), onPressed: () => setState(() { _editingIdx = i; _nameCtrl.text = s['name'] as String; _movingIdx = null; })),
          IconButton(icon: Icon(Icons.open_with, size: 18, color: isMoving ? Colors.orange : const Color(0xFF434750)), onPressed: () => setState(() { _movingIdx = isMoving ? null : i; _editingIdx = null; })),
          IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFBA1A1A)), onPressed: () => _confirmDelete(i)),
        ]),
      );
    }));
  }

  void _addStop() {
    if (_newStopPos == null || _nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Toca el mapa y escribe un nombre'), backgroundColor: Color(0xFFBA1A1A)));
      return;
    }
    setState(() {
      _stopsList.add({'name': _nameCtrl.text.trim(), 'route': 'Nueva', 'order': (_stopsList.length + 1).toString(), 'lat': _newStopPos!.latitude, 'lng': _newStopPos!.longitude});
      _nameCtrl.clear(); _newStopPos = null; _editingIdx = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parada agregada'), backgroundColor: Color(0xFF001B44)));
  }

  void _saveEdit() {
    if (_editingIdx == null) return;
    setState(() {
      _stopsList[_editingIdx!]['name'] = _nameCtrl.text.trim();
      _nameCtrl.clear(); _editingIdx = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parada actualizada'), backgroundColor: Color(0xFF001B44)));
  }

  void _confirmDelete(int idx) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Eliminar parada'),
      content: Text('¿Eliminar ${_stopsList[idx]['name']}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () { setState(() => _stopsList.removeAt(idx)); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parada eliminada'), backgroundColor: Color(0xFFBA1A1A))); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBA1A1A), foregroundColor: Colors.white), child: const Text('Eliminar')),
      ],
    ));
  }

  Widget _buildRequestsView() {
    final pendingAsync = ref.watch(pendingStopRequestsProvider);
    return pendingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (requests) {
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.how_to_reg_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('No hay solicitudes pendientes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF434750), fontFamily: 'Inter')),
              ],
            ),
          );
        }
        final reqMarkers = requests.map((r) {
          final lat = (r['proposed_lat'] as num?)?.toDouble() ?? 0;
          final lng = (r['proposed_lng'] as num?)?.toDouble() ?? 0;
          final driver = r['drivers'] as Map<String, dynamic>?;
          final profile = driver?['profiles'] as Map<String, dynamic>?;
          return _markerService.createRequestMarker(
            id: 'req_${r['id']}', point: LatLng(lat, lng),
            title: profile?['full_name'] ?? 'Conductor',
            subtitle: r['justification'] as String? ?? '',
          );
        }).toList();
        final cards = requests.map((r) {
          final driver = r['drivers'] as Map<String, dynamic>?;
          final profile = driver?['profiles'] as Map<String, dynamic>?;
          final lat = (r['proposed_lat'] as num?)?.toDouble() ?? 0;
          final lng = (r['proposed_lng'] as num?)?.toDouble() ?? 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.location_on, size: 18, color: Color(0xFF001B44)),
                      const SizedBox(width: 6),
                      Expanded(child: Text('${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter'))),
                    ]),
                    Text('Conductor: ${profile?['full_name'] ?? 'Desconocido'}', style: const TextStyle(fontSize: 13, fontFamily: 'Inter', color: Color(0xFF434750))),
                    Text('Motivo: ${r['justification'] ?? ''}', style: const TextStyle(fontSize: 13, fontFamily: 'Inter', color: Color(0xFF434750))),
                    Text('Fecha: ${r['created_at']?.toString().substring(0, 10) ?? ''}', style: const TextStyle(fontSize: 12, fontFamily: 'Inter', color: Color(0xFF434750))),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: OutlinedButton(
                        onPressed: () async {
                          await ref.read(fleetRepositoryProvider).rejectStopRequest(r['id'] as String);
                          ref.invalidate(pendingStopRequestsProvider);
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud rechazada'), backgroundColor: Color(0xFFBA1A1A)));
                        },
                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFBA1A1A), side: const BorderSide(color: Color(0xFFBA1A1A)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: const Text('Rechazar', style: TextStyle(fontFamily: 'Inter')),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: ElevatedButton(
                        onPressed: () async {
                          await ref.read(fleetRepositoryProvider).approveStopRequest(r['id'] as String);
                          ref.invalidate(pendingStopRequestsProvider);
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud aprobada'), backgroundColor: Color(0xFF2E7D32)));
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: const Text('Aprobar', style: TextStyle(fontFamily: 'Inter')),
                      )),
                    ]),
                  ],
                ),
              ),
            ),
          );
        }).toList();
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            SizedBox(
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: FlutterMap(
                  mapController: _reqMapCtrl,
                  options: const MapOptions(initialCenter: LatLng(-12.0464, -77.0428), initialZoom: 14),
                  children: [
                    TileLayer(urlTemplate: OpenStreetMapConfig.defaultUrlTemplate, userAgentPackageName: OpenStreetMapConfig.defaultUserAgent),
                    MarkerLayer(markers: reqMarkers),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Solicitudes pendientes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
            ...cards,
          ],
        );
      },
    );
  }
}
