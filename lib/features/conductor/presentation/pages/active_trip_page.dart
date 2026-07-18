import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/maps/marker_service.dart';
import '../../../../core/maps/tile_provider.dart';
import '../../../../core/notifications/local_notification_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../shared/domain/entities/route_entity.dart';
import '../../../../shared/domain/entities/stop_entity.dart';
import '../../../../shared/presentation/providers/location_provider.dart';
import '../../../admin_municipal/domain/entities/system_alert.dart';
import '../../../admin_municipal/presentation/providers/system_alerts_provider.dart';
import '../providers/conductor_route_provider.dart';
import '../providers/trip_provider.dart';
import 'route_selection_page.dart';

class ActiveTripPage extends ConsumerStatefulWidget {
  const ActiveTripPage({super.key});
  @override
  ConsumerState<ActiveTripPage> createState() => _ActiveTripPageState();
}

class _ActiveTripPageState extends ConsumerState<ActiveTripPage> {
  int _passengerCount = 0;
  bool _routeStarted = false;
  LatLng? _stopRequestPin;
  final _reasonCtrl = TextEditingController();
  final MarkerService _markerService = const MarkerService();
  StreamSubscription<LocationData>? _locationSub;
  LatLng? _myLocation;
  final MapController _mapCtrl = MapController();
  bool _mapReady = false;

  RouteEntity? _selectedRoute;
  Map<String, dynamic>? _selectedBus;
  String? _selectedBusId;
  String? _selectedRouteId;

  final Set<String> _notifiedStops = {};
  final LocalNotificationService _notifService = LocalNotificationService();

  @override
  void initState() {
    super.initState();
    _initGps();
    _notifService.initialize();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _initGps() async {
    final service = ref.read(locationServiceProvider);
    final hasPermission = await service.hasPermission();
    if (!hasPermission) await service.requestPermission();
    _locationSub?.cancel();
    _locationSub = service.onLocationChanged.listen((loc) {
      if (!mounted) return;
      final latLng = LatLng(loc.latitude, loc.longitude);
      setState(() => _myLocation = latLng);
      ref.read(driverLocationProvider.notifier).state = latLng;
      if (_routeStarted) {
        ref.read(publishTelemetryUseCaseProvider).execute(
          busId: _selectedBusId ?? 'unknown', lat: loc.latitude, lng: loc.longitude,
          speedKmh: loc.speed ?? 0, heading: loc.heading ?? 0,
        );
        _checkStopProximity(latLng);
      }
    });
  }

  void _checkStopProximity(LatLng driverPos) {
    if (_selectedRoute == null) return;
    const proximityThreshold = 80.0;

    for (final stop in _selectedRoute!.stops) {
      if (_notifiedStops.contains(stop.id)) continue;
      final stopPos = LatLng(stop.latitude, stop.longitude);
      final distance = Distance().call(driverPos, stopPos);
      if (distance <= proximityThreshold) {
        _notifiedStops.add(stop.id);
        _notifService.showProximityNotification(
          stopId: stop.hashCode,
          routeName: _selectedRoute!.name,
          stopName: stop.name,
          distanceMeters: distance.round(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Bus ${_selectedRoute!.name} se acerca a ${stop.name} (${distance.round()}m)'),
            backgroundColor: const Color(0xFF001B44),
            duration: const Duration(seconds: 3),
          ));
        }
      }
    }
  }

  Future<void> _selectRouteAndBus() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const RouteSelectionPage()),
    );
    if (result != null) {
      final route = result['route'] as RouteEntity;
      final bus = result['bus'] as Map<String, dynamic>;
      setState(() {
        _selectedRoute = route;
        _selectedBus = bus;
        _selectedBusId = bus['id'] as String;
        _selectedRouteId = route.id;
      });
      ref.read(selectedRouteProvider.notifier).state = route;
      ref.read(selectedBusProvider.notifier).state = bus;
    }
  }

  void _startTrip() {
    if (_myLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Esperando ubicación GPS...'),
        backgroundColor: Color(0xFF001B44),
      ));
      return;
    }
    if (_selectedRoute == null || _selectedBus == null) {
      _selectRouteAndBus();
      return;
    }
    ref.read(driverLocationProvider.notifier).state = _myLocation;
    ref.read(tripActiveProvider.notifier).state = true;
    final driverId = ref.read(driverIdProvider);
    ref.read(startTripUseCaseProvider).execute(
      driverId: driverId,
      busId: _selectedBusId!,
      routeId: _selectedRouteId!,
    );
    setState(() => _routeStarted = true);
    _notifiedStops.clear();
    if (_mapReady) _mapCtrl.move(_myLocation!, 16);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Viaje iniciado en ${_selectedRoute!.name} — GPS activo'),
      backgroundColor: const Color(0xFF001B44),
    ));
  }

  void _endTrip() {
    _locationSub?.cancel();
    _locationSub = null;
    ref.read(tripActiveProvider.notifier).state = false;
    ref.read(driverLocationProvider.notifier).state = null;
    ref.read(endTripUseCaseProvider).execute('current-trip');
    ref.read(selectedRouteProvider.notifier).state = null;
    ref.read(selectedBusProvider.notifier).state = null;
    setState(() {
      _routeStarted = false;
      _stopRequestPin = null;
      _passengerCount = 0;
      _selectedRoute = null;
      _selectedBus = null;
      _selectedBusId = null;
      _selectedRouteId = null;
      _notifiedStops.clear();
    });
    _initGps();
  }

  void _sendStopRequest() {
    if (_stopRequestPin == null) return;
    _reasonCtrl.clear();
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 16),
      const Text('Solicitar nueva parada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF001B44), fontFamily: 'Inter')),
      const SizedBox(height: 12),
      Row(children: [const Icon(Icons.location_on, size: 18, color: Color(0xFF001B44)), const SizedBox(width: 8), Expanded(child: Text('${_stopRequestPin!.latitude.toStringAsFixed(5)}, ${_stopRequestPin!.longitude.toStringAsFixed(5)}', style: const TextStyle(fontSize: 14, color: Color(0xFF001B44), fontFamily: 'Inter')))]),
      const SizedBox(height: 16),
      TextField(controller: _reasonCtrl, maxLines: 3, decoration: InputDecoration(labelText: 'Motivo de la solicitud', labelStyle: const TextStyle(fontFamily: 'Inter'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF001B44))))),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
        Navigator.pop(context);
        final uc = ref.read(requestNewStopUseCaseProvider);
        final driverId = ref.read(driverIdProvider);
        uc.execute(driverId: driverId, lat: _stopRequestPin!.latitude, lng: _stopRequestPin!.longitude, reason: _reasonCtrl.text.isNotEmpty ? _reasonCtrl.text : 'Solicitud');
        ref.read(networkMonitorRepositoryProvider).createAlert(SystemAlert(id: '', scope: 'stop_request', severity: 'low', title: 'Solicitud de parada', description: 'Conductor solicita parada en ${_stopRequestPin!.latitude.toStringAsFixed(5)}, ${_stopRequestPin!.longitude.toStringAsFixed(5)}', createdBy: driverId, latitude: _stopRequestPin!.latitude, longitude: _stopRequestPin!.longitude, createdAt: DateTime.now()));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud enviada a la cooperativa'), backgroundColor: Color(0xFF001B44)));
        setState(() => _stopRequestPin = null);
      }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF001B44), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: const Text('Enviar solicitud', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Inter')))),
      const SizedBox(height: 12),
    ])));
  }

  void _reportIncident() {
    final incidentCtrl = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 16),
      const Row(children: [Icon(Icons.warning_amber, color: Color(0xFFBA1A1A), size: 22), SizedBox(width: 8), Text('Reportar incidente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF001B44), fontFamily: 'Inter'))]),
      const SizedBox(height: 16),
      TextField(controller: incidentCtrl, maxLines: 3, decoration: InputDecoration(labelText: 'Descripción', labelStyle: const TextStyle(fontFamily: 'Inter'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF001B44))))),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () { Navigator.pop(context); ref.read(networkMonitorRepositoryProvider).createAlert(SystemAlert(id: '', scope: 'stop', severity: 'medium', title: 'Incidente - Conductor', description: incidentCtrl.text, createdBy: 'conductor', createdAt: DateTime.now())); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incidente reportado'), backgroundColor: Color(0xFFBA1A1A))); }, icon: const Icon(Icons.send, size: 18), label: const Text('Enviar reporte'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBA1A1A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
      const SizedBox(height: 12),
    ])));
  }

  void _centerOnUser() {
    if (_myLocation != null && _mapReady) {
      _mapCtrl.move(_myLocation!, 16);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapCenter = _myLocation ?? const LatLng(-12.0464, -77.0428);
    final extraMarkers = <Marker>[];
    if (_stopRequestPin != null) extraMarkers.add(_markerService.createRequestMarker(id: 'stop_req', point: _stopRequestPin!, title: 'Solicitud'));
    if (_myLocation != null) {
      extraMarkers.add(Marker(point: _myLocation!, width: 36, height: 36, child: Container(
        decoration: BoxDecoration(color: Colors.blue.withAlpha(220), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)]),
        child: const Icon(Icons.navigation, color: Colors.white, size: 20),
      )));
    }

    final routePolylines = <Polyline>[];
    if (_selectedRoute != null && _selectedRoute!.polyline.isNotEmpty) {
      final points = _selectedRoute!.polyline.map((p) => LatLng(p[0], p[1])).toList();
      routePolylines.add(Polyline(points: points, color: const Color(0xFF001B44), strokeWidth: 5));
    }

    final stopMarkers = _selectedRoute != null ? _selectedRoute!.stops.map((stop) {
      final isNotified = _notifiedStops.contains(stop.id);
      return Marker(
        point: LatLng(stop.latitude, stop.longitude), width: 40, height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: isNotified ? Colors.green.shade700 : Colors.blue.shade700,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(child: Text('${stop.orderIndex}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
        ),
      );
    }).toList() : <Marker>[];

    return Scaffold(
      body: Stack(children: [
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: mapCenter,
            initialZoom: 15,
            onTap: (tapPos, point) {
              if (_routeStarted) setState(() => _stopRequestPin = point);
            },
            onMapReady: () => _mapReady = true,
          ),
          children: [
            TileLayer(urlTemplate: OpenStreetMapConfig.defaultUrlTemplate, userAgentPackageName: OpenStreetMapConfig.defaultUserAgent),
            PolylineLayer(polylines: routePolylines),
            MarkerLayer(markers: [...stopMarkers, ...extraMarkers]),
          ],
        ),
        Positioned(top: 56, left: 16, right: 16, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 8)]), child: Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _routeStarted ? const Color(0xFFFED000) : Colors.grey[300]!, borderRadius: BorderRadius.circular(8)), child: Text(_routeStarted ? 'En Ruta' : 'Detenido', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _routeStarted ? const Color(0xFF001B44) : const Color(0xFF434750), fontFamily: 'Inter'))),
          const SizedBox(width: 12),
          Expanded(child: Text(
            _routeStarted ? 'Ruta: ${_selectedRoute?.name ?? ''}' : (_selectedRoute != null ? 'Ruta: ${_selectedRoute!.name} — pulsa Iniciar' : 'Sin ruta seleccionada'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter'),
            overflow: TextOverflow.ellipsis,
          )),
          IconButton(onPressed: _reportIncident, icon: const Icon(Icons.warning_amber, color: Color(0xFFBA1A1A), size: 22)),
        ]))),
        if (!_routeStarted) Positioned.fill(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_selectedRoute == null)
            ElevatedButton.icon(
              onPressed: _selectRouteAndBus,
              icon: const Icon(Icons.route, size: 24),
              label: const Text('Seleccionar ruta y bus'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFED000), foregroundColor: const Color(0xFF001B44), padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
            ),
          if (_selectedRoute != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withAlpha(230), borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                Text('Ruta: ${_selectedRoute!.name}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
                Text('Bus: ${_selectedBus?['plate'] ?? ''}  •  ${_selectedRoute!.stops.length} paradas', style: const TextStyle(fontSize: 12, color: Color(0xFF434750), fontFamily: 'Inter')),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _selectRouteAndBus,
                  child: const Text('Cambiar ruta', style: TextStyle(fontSize: 12, color: Color(0xFF001B44), fontFamily: 'Inter', decoration: TextDecoration.underline)),
                ),
              ]),
            ),
            ElevatedButton.icon(
              onPressed: _startTrip,
              icon: const Icon(Icons.play_circle, size: 28),
              label: const Text('Iniciar viaje'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF001B44), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
            ),
          ],
          const SizedBox(height: 8),
          if (_myLocation != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withAlpha(200), borderRadius: BorderRadius.circular(8)),
              child: Text('Ubicación: ${_myLocation!.latitude.toStringAsFixed(5)}, ${_myLocation!.longitude.toStringAsFixed(5)}', style: const TextStyle(fontSize: 11, color: Color(0xFF434750), fontFamily: 'Inter')),
            ),
        ]))),
        Positioned(right: 16, bottom: _routeStarted ? 260 : 20, child: FloatingActionButton.small(onPressed: _centerOnUser, backgroundColor: Colors.white, child: const Icon(Icons.my_location, color: Color(0xFF001B44)))),
        if (_routeStarted) Positioned(bottom: 0, left: 0, right: 0, child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 16, offset: Offset(0, -4))]), padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Row(children: [
            if (_stopRequestPin != null) ...[
              Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), decoration: BoxDecoration(color: Colors.green.withAlpha(20), borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Nueva parada en:', style: TextStyle(fontSize: 11, color: Color(0xFF434750), fontFamily: 'Inter')), Text('${_stopRequestPin!.latitude.toStringAsFixed(5)}, ${_stopRequestPin!.longitude.toStringAsFixed(5)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter'))]))),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _sendStopRequest, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF001B44), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), child: const Text('Solicitar')),
            ] else ...[
              const Text('Toca el mapa para solicitar una parada', style: TextStyle(fontSize: 12, color: Color(0xFF434750), fontFamily: 'Inter')),
            ],
          ]),
          const SizedBox(height: 16),
          const Text('Pasajeros a bordo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF434750), fontFamily: 'Inter')),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton.filled(onPressed: () => setState(() => _passengerCount = (_passengerCount - 1).clamp(0, 40)), icon: const Icon(Icons.remove), style: IconButton.styleFrom(backgroundColor: const Color(0xFF001B44).withAlpha(20), foregroundColor: const Color(0xFF001B44))),
            const SizedBox(width: 24),
            Text('$_passengerCount', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: Color(0xFF001B44), fontFamily: 'Inter')),
            const SizedBox(width: 24),
            IconButton.filled(onPressed: () => setState(() => _passengerCount = (_passengerCount + 1).clamp(0, 40)), icon: const Icon(Icons.add), style: IconButton.styleFrom(backgroundColor: const Color(0xFF001B44).withAlpha(20), foregroundColor: const Color(0xFF001B44))),
          ]),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _passengerCount / 40, minHeight: 6, backgroundColor: Colors.grey[200], valueColor: const AlwaysStoppedAnimation(Color(0xFFFED000)))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _endTrip, icon: const Icon(Icons.stop_circle, size: 18), label: const Text('Finalizar viaje'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF001B44), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
        ]))),
      ]),
    );
  }
}
