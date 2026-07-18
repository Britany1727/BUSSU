import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/maps/marker_service.dart';
import '../../../../core/maps/tile_provider.dart';
import '../../../../shared/presentation/providers/location_provider.dart';
import '../providers/trip_provider.dart';

class StopRequestPage extends ConsumerStatefulWidget {
  const StopRequestPage({super.key});
  @override
  ConsumerState<StopRequestPage> createState() => _StopRequestPageState();
}

class _StopRequestPageState extends ConsumerState<StopRequestPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  LatLng? _position;
  bool _hasBench = false;
  bool _sending = false;
  final MapController _mapCtrl = MapController();
  final MarkerService _markerService = const MarkerService();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descCtrl = TextEditingController();
  }

  @override
  void dispose() { _nameCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _position == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona una ubicación y escribe un nombre')));
      return;
    }
    setState(() => _sending = true);
    final uc = ref.read(requestNewStopUseCaseProvider);
    final driverId = ref.read(driverIdProvider);
    final result = await uc.execute(driverId: driverId, lat: _position!.latitude, lng: _position!.longitude, reason: '${_nameCtrl.text}\n${_descCtrl.text}\nBanca: ${_hasBench ? "si" : "no"}');
    if (!mounted) return;
    setState(() => _sending = false);
    result.fold(
      (_) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al enviar solicitud'), backgroundColor: Color(0xFFBA1A1A))),
      (_) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud enviada a stop_requests'), backgroundColor: Color(0xFF001B44))); _nameCtrl.clear(); _descCtrl.clear(); setState(() { _position = null; _hasBench = false; }); },
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    if (_position != null) {
      markers.add(_markerService.createRequestMarker(id: 'selected', point: _position!, title: 'Nueva parada', subtitle: _nameCtrl.text));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Solicitar parada', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Color(0xFF001B44))), backgroundColor: const Color(0xFFF8F9FA), elevation: 0),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SizedBox(
          height: 240,
          child: ClipRRect(borderRadius: BorderRadius.circular(14), child: FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(initialCenter: const LatLng(-12.0464, -77.0428), initialZoom: 15, onTap: (_, p) => setState(() => _position = p)),
            children: [
              TileLayer(urlTemplate: OpenStreetMapConfig.defaultUrlTemplate, userAgentPackageName: OpenStreetMapConfig.defaultUserAgent),
              MarkerLayer(markers: markers),
            ],
          )),
        ),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: ElevatedButton.icon(onPressed: () async { final service = ref.read(locationServiceProvider); final loc = await service.getCurrentLocation(); loc.fold((f) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message.toString()), backgroundColor: const Color(0xFFBA1A1A))); }, (location) { final pos = LatLng(location.latitude, location.longitude); setState(() => _position = pos); _mapCtrl.move(pos, 15); }); }, icon: const Icon(Icons.my_location, size: 18), label: const Text('Mi ubicación'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF001B44), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))]),
        const SizedBox(height: 20),
        TextFormField(controller: _nameCtrl, decoration: InputDecoration(labelText: 'Nombre de la parada', hintText: 'Ej: Av. La Marina cdra 5', labelStyle: const TextStyle(color: Color(0xFF001B44), fontFamily: 'Inter'), hintStyle: TextStyle(color: Colors.grey[400], fontFamily: 'Inter'), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF001B44))))),
        const SizedBox(height: 14),
        TextFormField(controller: _descCtrl, maxLines: 3, decoration: InputDecoration(labelText: 'Descripción', hintText: 'Referencias, tipo de pavimento, etc.', labelStyle: const TextStyle(color: Color(0xFF001B44), fontFamily: 'Inter'), hintStyle: TextStyle(color: Colors.grey[400], fontFamily: 'Inter'), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF001B44))))),
        const SizedBox(height: 14),
        SwitchListTile(title: const Text('Cuenta con banca', style: TextStyle(fontFamily: 'Inter', color: Color(0xFF001B44))), value: _hasBench, onChanged: (v) => setState(() => _hasBench = v), activeColor: const Color(0xFF001B44), dense: true, contentPadding: EdgeInsets.zero),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _sending ? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFED000), foregroundColor: const Color(0xFF001B44), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Inter')), child: Text(_sending ? 'Enviando...' : 'Enviar solicitud'))),
      ]),
    );
  }
}
