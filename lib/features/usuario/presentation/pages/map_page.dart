import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/maps/polyline_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../shared/presentation/providers/location_provider.dart';
import '../../../../shared/domain/entities/bus_entity.dart';
import '../../../../shared/domain/entities/route_entity.dart';
import '../../../../shared/domain/entities/stop_entity.dart';
import '../../../../shared/presentation/widgets/live_map_widget.dart';
import '../../domain/entities/favorite_entity.dart';
import '../../domain/repositories/eta_repository.dart';
import '../providers/eta_provider.dart';
import '../providers/favorites_provider.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});
  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  bool _showStops = false;
  LatLng? _myLocation;
  final PolylineService _polylineService = const PolylineService();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  StreamSubscription<LocationData>? _gpsSub;
  final MapController _mapCtrl = MapController();
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _initGpsTracking();
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _initGpsTracking() async {
    final service = ref.read(locationServiceProvider);
    final hasPermission = await service.hasPermission();
    if (!hasPermission) {
      await service.requestPermission();
    }
    _gpsSub?.cancel();
    _gpsSub = service.onLocationChanged.listen((loc) {
      if (!mounted) return;
      final newPos = LatLng(loc.latitude, loc.longitude);
      setState(() => _myLocation = newPos);
      if (_mapReady) {
        _mapCtrl.move(newPos, _mapCtrl.camera.zoom);
      }
    });
  }

  void _centerOnUser() {
    if (_myLocation != null && _mapReady) {
      _mapCtrl.move(_myLocation!, 16);
    } else {
      _initGpsTracking();
    }
  }

  @override
  Widget build(BuildContext context) {
    final routesAsync = ref.watch(availableRoutesProvider);
    final selectedRouteId = ref.watch(selectedRouteIdProvider);
    final routeWithBuses = ref.watch(routeWithBusesProvider(selectedRouteId ?? ''));
    final favoritesAsync = ref.watch(favoritesProvider);

    final allRoutes = routesAsync.valueOrNull ?? [];
    final favoriteIds = favoritesAsync.valueOrNull?.where((f) => f.type == FavoriteType.route).map((f) => f.itemId).toSet() ?? {};
    final stops = routeWithBuses.valueOrNull?.route.stops ?? [];
    final buses = _extractBusPositions(routeWithBuses.valueOrNull);
    final favoritePolylines = allRoutes.where((r) => favoriteIds.contains(r.id)).map((r) => _polylineService.createFavoriteRoutePolyline(id: r.id, points: _polylineService.fromDoubleList(r.polyline))).toList();
    final allStops = allRoutes.expand((r) => r.stops).toList();

    final userMarker = _myLocation != null ? [
      Marker(point: _myLocation!, width: 30, height: 30, child: Container(
        decoration: BoxDecoration(color: Colors.blue.withAlpha(200), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)]),
        child: const Icon(Icons.my_location, color: Colors.white, size: 16),
      )),
    ] : <Marker>[];

    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        onPressed: _centerOnUser,
        backgroundColor: Colors.white,
        child: const Icon(Icons.my_location, color: Color(0xFF001B44)),
      ),
      body: Stack(children: [
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: _myLocation ?? const LatLng(-12.0464, -77.0428),
            initialZoom: 14,
            onMapReady: () => setState(() => _mapReady = true),
          ),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.verve.bussu'),
            PolylineLayer(polylines: [
              ..._buildRoutePolylines(allRoutes),
              ...favoritePolylines,
            ]),
            MarkerLayer(markers: [
              ..._buildStopMarkers(_showStops ? allStops : stops),
              ...userMarker,
            ]),
          ],
        ),
        Positioned(top: 56, left: 16, right: 72, child: _buildSearchBar()),
        Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomSheet(allStops, allRoutes)),
      ]),
    );
  }

  List<Polyline> _buildRoutePolylines(List<RouteEntity> routes) {
    return routes.map((r) {
      final points = _polylineService.fromDoubleList(r.polyline);
      return Polyline(points: points, color: const Color(0xFF001B44).withAlpha(120), strokeWidth: 4);
    }).toList();
  }

  List<Marker> _buildStopMarkers(List<StopEntity> stops) {
    return stops.map((stop) => Marker(
      point: LatLng(stop.latitude, stop.longitude),
      width: 36,
      height: 36,
      child: GestureDetector(
        onTap: () => _showStopInfo(stop),
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: const Color(0xFF1565C0), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
          child: Center(child: Text('${stop.orderIndex}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
        ),
      ),
    )).toList();
  }

  void _showStopInfo(StopEntity stop) {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 16),
      Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFF1565C0), borderRadius: BorderRadius.circular(10)), child: Center(child: Text('${stop.orderIndex}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)))), const SizedBox(width: 12), Expanded(child: Text(stop.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF001B44), fontFamily: 'Inter')))]),
      const SizedBox(height: 16),
      _infoRow(Icons.location_on, '${stop.latitude.toStringAsFixed(5)}, ${stop.longitude.toStringAsFixed(5)}'),
      const SizedBox(height: 8),
      _infoRow(Icons.alt_route, 'Parada #${stop.orderIndex}'),
      if (stop.distanceAlongRoute != null) ...[const SizedBox(height: 8), _infoRow(Icons.straighten, '${(stop.distanceAlongRoute! / 1000).toStringAsFixed(2)} km desde inicio')],
    ])));
  }

  Widget _infoRow(IconData icon, String text) => Row(children: [Icon(icon, size: 18, color: const Color(0xFF434750)), const SizedBox(width: 8), Text(text, style: const TextStyle(fontSize: 14, color: Color(0xFF434750), fontFamily: 'Inter'))]);

  Widget _buildSearchBar() {
    return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 12, offset: Offset(0, 4))]), child: TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _searchQuery = v),
      decoration: InputDecoration(hintText: 'Buscar destino o ruta...', hintStyle: const TextStyle(color: Color(0xFF434750), fontSize: 14), prefixIcon: const Icon(Icons.search, color: Color(0xFF001B44)), suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); }) : null, border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12))));
  }

  Widget _buildBottomSheet(List<StopEntity> allStops, List<RouteEntity> allRoutes) {
    final favoritesAsync = ref.watch(favoritesProvider);
    final favRoutes = favoritesAsync.valueOrNull?.where((f) => f.type == FavoriteType.route).toList() ?? [];
    return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 16, offset: Offset(0, -4))]), padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 12),
      if (favRoutes.isNotEmpty) ...[
        const Text('Rutas Favoritas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
        const SizedBox(height: 8),
        SizedBox(height: 50, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: favRoutes.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, i) {
          final fav = favRoutes[i]; final selected = ref.watch(selectedRouteIdProvider) == fav.itemId;
          final chipColor = selected ? const Color(0xFF001B44) : const Color(0xFFFED000).withAlpha(30);
          final textColor = selected ? Colors.white : const Color(0xFF001B44);
          return GestureDetector(onTap: () => ref.read(selectedRouteIdProvider.notifier).state = fav.itemId, child: Chip(avatar: const Icon(Icons.star, size: 16, color: Color(0xFFFED000)), label: Text(fav.name, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: textColor, fontFamily: 'Inter')), backgroundColor: chipColor));
        })),
        const SizedBox(height: 12),
      ],
      if (allStops.isNotEmpty) SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => setState(() => _showStops = !_showStops), icon: Icon(_showStops ? Icons.visibility_off : Icons.place_outlined, size: 18), label: Text(_showStops ? 'Ocultar paradas' : 'Ver todas las paradas (${allStops.length})'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF001B44), side: const BorderSide(color: Color(0xFF001B44)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)))),
    ]));
  }

  Map<String, BusPosition> _extractBusPositions(RouteWithBuses? r) {
    if (r == null) return {};
    final buses = <String, BusPosition>{};
    for (final BusEntity bus in r.activeBuses) {
      if (bus.latitude != null && bus.longitude != null) {
        buses[bus.id] = BusPosition(position: LatLng(bus.latitude!, bus.longitude!), heading: bus.heading ?? 0, occupancyPct: bus.occupancyPct);
      }
    }
    return buses;
  }
}
