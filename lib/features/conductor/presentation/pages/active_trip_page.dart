import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/maps/marker_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../shared/domain/entities/route_entity.dart';
import '../../../../shared/domain/entities/stop_entity.dart';
import '../../../../shared/presentation/providers/location_provider.dart';
import '../../../../shared/presentation/widgets/live_map_widget.dart';
import '../../../admin_municipal/presentation/providers/system_alerts_provider.dart';
import '../../../admin_municipal/domain/entities/system_alert.dart';
import '../providers/trip_provider.dart';
import 'driver_dashboard_page.dart';

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

  final RouteEntity _mockRoute = RouteEntity(
    id: 'route-a', name: 'Ruta A - Centro',
    polyline: const [[-12.0464, -77.0428], [-12.0450, -77.0410], [-12.0440, -77.0390], [-12.0430, -77.0370]],
    stops: [
      const StopEntity(id: 's1', name: 'Plaza de Armas', latitude: -12.0464, longitude: -77.0428, orderIndex: 1),
      const StopEntity(id: 's2', name: 'Jr. de la Union', latitude: -12.0452, longitude: -77.0410, orderIndex: 2),
      const StopEntity(id: 's3', name: 'Parque Universitario', latitude: -12.0440, longitude: -77.0390, orderIndex: 3),
    ],
  );

  @override
  void dispose() {
    _locationSub?.cancel();
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _startRouteTracking() async {
    final service = ref.read(locationServiceProvider);
    final permission = await service.hasPermission();
    if (!permission) {
      final granted = await service.requestPermission();
      if (!granted) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Se requiere permiso de ubicación para iniciar la ruta'),
          backgroundColor: Color(0xFFBA1A1A),
        ));
        return;
      }
    }
    final result = await service.getCurrentLocation();
    result.fold(
      (f) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(f.message.toString()),
          backgroundColor: const Color(0xFFBA1A1A),
        ));
      },
      (loc) {
        if (!mounted) return;
        final latLng = LatLng(loc.latitude, loc.longitude);
        ref.read(driverLocationProvider.notifier).state = latLng;
        _startPublishingLocation(service);
        setState(() => _routeStarted = true);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ruta iniciada — ubicación en tiempo real activada'),
          backgroundColor: Color(0xFF001B44),
        ));
      },
    );
  }

  void _startPublishingLocation(LocationService service) {
    _locationSub?.cancel();
    _locationSub = service.onLocationChanged.listen((loc) {
      if (!mounted) return;
      final latLng = LatLng(loc.latitude, loc.longitude);
      ref.read(driverLocationProvider.notifier).state = latLng;
      ref.read(publishTelemetryUseCaseProvider).execute(
        busId: 'bus-123', lat: loc.latitude, lng: loc.longitude,
        speedKmh: loc.speed ?? 0, heading: loc.heading ?? 0,
      );
    });
  }

  void _confirmPassengerChange(int newCount) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Confirmar cambio', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
      content: Text('¿Cambiar conteo de $_passengerCount a $newCount pasajeros?', style: const TextStyle(fontFamily: 'Inter')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () { setState(() => _passengerCount = newCount); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF001B44)), child: const Text('Confirmar')),
      ],
    ));
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
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { Navigator.pop(context); final uc = ref.read(requestNewStopUseCaseProvider); uc.execute(driverId: 'current-driver', lat: _stopRequestPin!.latitude, lng: _stopRequestPin!.longitude, reason: _reasonCtrl.text.isNotEmpty ? _reasonCtrl.text : 'Solicitud'); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud enviada'), backgroundColor: Color(0xFF001B44))); setState(() => _stopRequestPin = null); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF001B44), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: const Text('Enviar solicitud', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Inter')))),
      const SizedBox(height: 12),
    ])));
  }

  void _reportIncident() {
    if (!_routeStarted) return;
    final incidentCtrl = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 16),
      const Row(children: [Icon(Icons.warning_amber, color: Color(0xFFBA1A1A), size: 22), SizedBox(width: 8), Text('Reportar incidente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF001B44), fontFamily: 'Inter'))]),
      const SizedBox(height: 16),
      TextField(controller: incidentCtrl, maxLines: 3, decoration: InputDecoration(labelText: 'Descripción', labelStyle: const TextStyle(fontFamily: 'Inter'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF001B44))))),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () { Navigator.pop(context); final repo = ref.read(networkMonitorRepositoryProvider); repo.createAlert(SystemAlert(id: '', scope: 'stop', severity: 'medium', title: 'Incidente', description: incidentCtrl.text, createdBy: 'conductor', createdAt: DateTime.now())); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incidente reportado'), backgroundColor: Color(0xFFBA1A1A))); }, icon: const Icon(Icons.send, size: 18), label: const Text('Enviar reporte'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBA1A1A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
      const SizedBox(height: 12),
    ])));
  }

  void _endTrip() {
    _locationSub?.cancel();
    _locationSub = null;
    ref.read(tripActiveProvider.notifier).state = false;
    ref.read(driverLocationProvider.notifier).state = null;
    ref.read(endTripUseCaseProvider).execute('current-trip');
  }

  @override
  Widget build(BuildContext context) {
    final hasActive = ref.watch(hasActiveTripProvider);
    if (!hasActive) return const DriverDashboardPage();

    final driverLoc = ref.watch(driverLocationProvider);
    final extraMarkers = <Marker>[];
    if (_stopRequestPin != null) extraMarkers.add(_markerService.createRequestMarker(id: 'stop_req', point: _stopRequestPin!, title: 'Solicitud'));
    if (driverLoc != null) {
      extraMarkers.add(Marker(point: driverLoc, width: 36, height: 36, child: Container(
        decoration: BoxDecoration(color: Colors.blue.withAlpha(220), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)]),
        child: const Icon(Icons.navigation, color: Colors.white, size: 20),
      )));
    }

    final mapCenter = driverLoc ?? const LatLng(-12.0464, -77.0428);

    return Scaffold(
      body: Stack(children: [
        LiveMapWidget(initialCenter: mapCenter, initialZoom: 15, activeRoute: _routeStarted ? _mockRoute : null, stops: _routeStarted ? _mockRoute.stops : [], extraMarkers: extraMarkers, onMapTapped: (pos) { if (_routeStarted) setState(() => _stopRequestPin = pos); }),
        Positioned(top: 56, left: 16, right: 16, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 8)]), child: Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _routeStarted ? const Color(0xFFFED000) : Colors.grey[300]!, borderRadius: BorderRadius.circular(8)), child: Text(_routeStarted ? 'En Ruta' : 'Detenido', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _routeStarted ? const Color(0xFF001B44) : const Color(0xFF434750), fontFamily: 'Inter'))),
          const SizedBox(width: 12),
          const Expanded(child: Text('Próxima: Plaza de Armas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter'))),
          IconButton(onPressed: _routeStarted ? _reportIncident : null, icon: Icon(Icons.warning_amber, color: _routeStarted ? const Color(0xFFBA1A1A) : Colors.grey, size: 22)),
        ]))),
        if (!_routeStarted) Positioned.fill(child: Center(child: ElevatedButton.icon(onPressed: _startRouteTracking, icon: const Icon(Icons.play_circle, size: 28), label: const Text('Iniciar ruta'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF001B44), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Inter'))))),
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
            IconButton.filled(onPressed: () => _confirmPassengerChange((_passengerCount - 1).clamp(0, 40)), icon: const Icon(Icons.remove), style: IconButton.styleFrom(backgroundColor: const Color(0xFF001B44).withAlpha(20), foregroundColor: const Color(0xFF001B44))),
            const SizedBox(width: 24),
            Text('$_passengerCount', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: Color(0xFF001B44), fontFamily: 'Inter')),
            const SizedBox(width: 24),
            IconButton.filled(onPressed: () => _confirmPassengerChange((_passengerCount + 1).clamp(0, 40)), icon: const Icon(Icons.add), style: IconButton.styleFrom(backgroundColor: const Color(0xFF001B44).withAlpha(20), foregroundColor: const Color(0xFF001B44))),
          ]),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _passengerCount / 40, minHeight: 6, backgroundColor: Colors.grey[200], valueColor: const AlwaysStoppedAnimation(Color(0xFFFED000)))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _endTrip, icon: const Icon(Icons.stop_circle, size: 18), label: const Text('Finalizar viaje'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF001B44), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
        ]))),
      ]),
    );
  }
}
