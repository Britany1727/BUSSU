import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/maps/polyline_service.dart';
import '../../../../core/maps/tile_provider.dart';
import '../../../../shared/domain/entities/route_entity.dart';
import '../../../../shared/domain/entities/stop_entity.dart';
import '../../domain/entities/favorite_entity.dart';
import '../providers/eta_provider.dart';
import '../providers/favorites_provider.dart';
import 'u_scaffold.dart';

class RoutesPage extends ConsumerStatefulWidget {
  const RoutesPage({super.key});
  @override
  ConsumerState<RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends ConsumerState<RoutesPage> {
  String? _expandedRouteId;
  final Set<String> _localFavorites = {};
  final PolylineService _polylineService = const PolylineService();
  final MapController _miniMapCtrl = MapController();
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final favs = ref.read(favoritesProvider).valueOrNull ?? [];
      setState(() => _localFavorites.addAll(favs.where((f) => f.type == FavoriteType.route).map((f) => f.itemId)));
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _isFav(String routeId) => _localFavorites.contains(routeId);
  void _toggleFav(String routeId, String name) {
    setState(() {
      if (_isFav(routeId)) { _localFavorites.remove(routeId); }
      else { _localFavorites.add(routeId); }
    });
  }

  void _selectRoute(String routeId, WidgetRef ref) {
    ref.read(selectedRouteIdProvider.notifier).state = routeId;
    final scaffold = context.findAncestorStateOfType<UScaffoldState>();
    scaffold?.switchToLive();
    if (_expandedRouteId == routeId) {
      setState(() => _expandedRouteId = null);
    } else {
      setState(() => _expandedRouteId = routeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routesAsync = ref.watch(availableRoutesProvider);
    final favorites = ref.watch(favoritesProvider);
    final selectedRouteId = ref.watch(selectedRouteIdProvider);
    final allRoutes = routesAsync.valueOrNull ?? [];

    final filteredRoutes = _searchQuery.isEmpty
        ? allRoutes
        : allRoutes.where((r) => r.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    final expandedRoute = _expandedRouteId != null
        ? allRoutes.where((r) => r.id == _expandedRouteId).firstOrNull
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Routes', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Color(0xFF001B44))),
        backgroundColor: const Color(0xFFF8F9FA), elevation: 0,
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (expandedRoute != null) ...[
          _buildMiniMap(expandedRoute),
          const SizedBox(height: 16),
        ],
        _buildSearchBar(),
        const SizedBox(height: 20),
        if (_searchQuery.isEmpty) ...[
          _buildSection('Favoritos', favorites.valueOrNull ?? [], selectedRouteId, ref),
          const SizedBox(height: 20),
        ],
        _buildSection(_searchQuery.isEmpty ? 'Todas las rutas' : 'Resultados', filteredRoutes, selectedRouteId, ref),
      ]),
    );
  }

  Widget _buildMiniMap(RouteEntity route) {
    final polyline = _polylineService.fromDoubleList(route.polyline);
    final startPoint = polyline.isNotEmpty ? polyline.first : const LatLng(0, 0);
    final endPoint = polyline.isNotEmpty ? polyline.last : const LatLng(0, 0);
    final distKm = _polylineDistance(route.polyline);
    final stops = route.stops;

    final markers = <Marker>[];
    if (polyline.isNotEmpty) {
      markers.add(Marker(
        point: startPoint, width: 40, height: 40,
        child: const Icon(Icons.trip_origin, color: Colors.green, size: 32),
      ));
      markers.add(Marker(
        point: endPoint, width: 40, height: 40,
        child: const Icon(Icons.location_on, color: Colors.red, size: 32),
      ));
    }
    for (final stop in stops) {
      markers.add(Marker(
        point: LatLng(stop.latitude, stop.longitude),
        width: 28, height: 28,
        child: Container(
          decoration: BoxDecoration(color: Colors.blue.shade700, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
          child: Center(child: Text('${stop.orderIndex}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
        ),
      ));
    }

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          child: SizedBox(
            height: 200,
            child: FlutterMap(
              mapController: _miniMapCtrl,
              options: MapOptions(
                initialCenter: polyline.isNotEmpty ? startPoint : const LatLng(-12.0464, -77.0428),
                initialZoom: 14,
              ),
              children: [
                TileLayer(urlTemplate: OpenStreetMapConfig.defaultUrlTemplate, userAgentPackageName: OpenStreetMapConfig.defaultUserAgent),
                if (polyline.isNotEmpty) PolylineLayer(polylines: [Polyline(points: polyline, color: const Color(0xFF001B44), strokeWidth: 4)]),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
        ),
        Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: Color(int.parse('FF${route.color.replaceAll('#', '')}', radix: 16)), shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(route.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF001B44), fontFamily: 'Inter'))),
            IconButton(onPressed: () => setState(() => _expandedRouteId = null), icon: const Icon(Icons.close, color: Color(0xFF434750)), iconSize: 20),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _infoChip(Icons.straighten, '${distKm.toStringAsFixed(1)} km'),
            const SizedBox(width: 12),
            _infoChip(Icons.place_outlined, '${stops.length} paradas'),
            const SizedBox(width: 12),
            _infoChip(Icons.trip_origin, 'Inicio'),
            const SizedBox(width: 12),
            _infoChip(Icons.flag, 'Fin'),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.location_on, size: 14, color: Colors.green),
            const SizedBox(width: 4),
            Expanded(child: Text('Inicio: ${startPoint.latitude.toStringAsFixed(4)}, ${startPoint.longitude.toStringAsFixed(4)}', style: const TextStyle(fontSize: 12, color: Color(0xFF434750), fontFamily: 'Inter'))),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.location_on, size: 14, color: Colors.red),
            const SizedBox(width: 4),
            Expanded(child: Text('Fin: ${endPoint.latitude.toStringAsFixed(4)}, ${endPoint.longitude.toStringAsFixed(4)}', style: const TextStyle(fontSize: 12, color: Color(0xFF434750), fontFamily: 'Inter'))),
          ]),
          if (stops.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(height: 90, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: stops.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, i) {
              final s = stops[i];
              return Container(
                width: 140, padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE8E8E8))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 20, height: 20, decoration: BoxDecoration(color: const Color(0xFF001B44).withAlpha(30), borderRadius: BorderRadius.circular(6)), child: Center(child: Text('${s.orderIndex}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF001B44))))),
                    const SizedBox(width: 6),
                    Expanded(child: Text(s.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter'), maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 4),
                  Text('${s.latitude.toStringAsFixed(3)}, ${s.longitude.toStringAsFixed(3)}', style: const TextStyle(fontSize: 10, color: Color(0xFF434750), fontFamily: 'Inter')),
                ]),
              );
            })),
          ],
        ])),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF001B44).withAlpha(10), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: const Color(0xFF001B44)), const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF001B44), fontFamily: 'Inter')),
    ]));
  }

  Widget _buildSearchBar() {
    return Row(children: [
      Expanded(child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 8, offset: Offset(0, 2))]), child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(hintText: '¿A dónde vas?', hintStyle: const TextStyle(color: Color(0xFF434750), fontSize: 14, fontFamily: 'Inter'), prefixIcon: const Icon(Icons.search, color: Color(0xFF001B44)), suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); }) : null, border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none), filled: true, fillColor: Colors.white,         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12))))),
      const SizedBox(width: 12),
      Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFFFED000), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.directions, color: Color(0xFF001B44))),
    ]);
  }

  Widget _buildSection(String title, List<dynamic> items, String? selectedRouteId, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
      const SizedBox(height: 8),
      ...items.map((item) {
        final isFavorite = title == 'Favoritos';
        final name = isFavorite ? (item as FavoriteEntity).name : (item as RouteEntity).name;
        final id = isFavorite ? (item as FavoriteEntity).itemId : (item as RouteEntity).id;
        final color = isFavorite ? '#001B44' : (item as RouteEntity).color;
        final polyline = isFavorite ? <List<double>>[] : (item as RouteEntity).polyline;
        final distKm = _polylineDistance(polyline);
        final stopsCount = isFavorite ? 0 : (item as RouteEntity).stops.length;
        final subtitle = isFavorite ? 'Favorito' : '$stopsCount paradas · ${distKm.toStringAsFixed(1)} km';
        final isExpanded = _expandedRouteId == id;
        final isSelected = selectedRouteId == id;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isExpanded ? const Color(0xFFFED000).withAlpha(20) : isSelected ? const Color(0xFFFED000).withAlpha(25) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 8, offset: Offset(0, 2))],
            border: isSelected ? Border.all(color: const Color(0xFFFED000), width: 1.5) : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _selectRoute(id, ref),
            child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
              Container(width: 4, height: 40, decoration: BoxDecoration(color: Color(int.parse('FF${color.replaceAll('#', '')}', radix: 16)), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF434750), fontFamily: 'Inter')),
              ])),
              if (!isFavorite) IconButton(onPressed: () => _toggleFav(id, name), icon: Icon(_isFav(id) ? Icons.star : Icons.star_border, color: _isFav(id) ? const Color(0xFFFED000) : const Color(0xFFBDBDBD), size: 22), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              Icon(isExpanded ? Icons.expand_less : Icons.chevron_right, color: const Color(0xFF434750)),
            ])),
          ),
        );
      }),
    ]);
  }
}

double _polylineDistance(List<List<double>> polyline) {
  if (polyline.length < 2) return 0;
  double d = 0;
  for (int i = 1; i < polyline.length; i++) {
    final dlat = polyline[i][0] - polyline[i - 1][0];
    final dlng = polyline[i][1] - polyline[i - 1][1];
    final latMid = (polyline[i][0] + polyline[i - 1][0]) / 2;
    const mPerLat = 111320.0;
    final mPerLng = 111320.0 * (latMid * 0.0174533).clamp(-1.0, 1.0).let((r) {
      double x = r, t = 1, s = 1;
      for (int j = 2; j <= 8; j += 2) { t *= -r * r; s += t / (j * (j - 1)); }
      return s;
    });
    final dx = dlat * mPerLat;
    final dy = dlng * mPerLng;
    d += (dx * dx + dy * dy).abs();
  }
  return d > 0 ? d / 1000 : 0;
}

extension _NumExt on num {
  double let(double Function(double) f) => f(toDouble());
}
