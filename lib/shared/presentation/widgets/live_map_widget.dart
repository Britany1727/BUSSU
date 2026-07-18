import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/maps/marker_service.dart';
import '../../../core/maps/polyline_service.dart';
import '../../../core/maps/tile_provider.dart';
import '../../../core/maps/tile_cache_service.dart';
import '../../domain/entities/route_entity.dart';
import '../../domain/entities/stop_entity.dart';
import 'bus_marker_animator.dart';
import 'map/marker_manager.dart';
import 'map/polyline_cache.dart';

class LiveMapWidget extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final Map<String, BusPosition> buses;
  final RouteEntity? activeRoute;
  final List<StopEntity> stops;
  final void Function(StopEntity)? onStopTapped;
  final void Function(String busId)? onBusTapped;
  final List<Polyline> extraPolylines;
  final List<Marker> extraMarkers;
  final void Function(LatLng)? onMapTapped;
  final Stream<Map<String, BusPosition>>? busPositionStream;
  final Duration? pollingInterval;
  final TileCacheService? tileCache;
  final MapController? externalMapController;

  const LiveMapWidget({
    super.key,
    this.initialCenter = const LatLng(-12.0464, -77.0428),
    this.initialZoom = 14,
    this.buses = const {},
    this.activeRoute,
    this.stops = const [],
    this.onStopTapped,
    this.onBusTapped,
    this.extraPolylines = const [],
    this.extraMarkers = const [],
    this.onMapTapped,
    this.busPositionStream,
    this.pollingInterval,
    this.tileCache,
    this.externalMapController,
  });

  @override
  State<LiveMapWidget> createState() => _LiveMapWidgetState();
}

class BusPosition {
  final LatLng position;
  final double heading;
  final double occupancyPct;
  final double speedKmh;
  const BusPosition({required this.position, this.heading = 0, this.occupancyPct = 0, this.speedKmh = 0});
}

class _LiveMapWidgetState extends State<LiveMapWidget> with TickerProviderStateMixin {
  late final MapController _mapController = widget.externalMapController ?? MapController();
  final BusMarkerAnimator _animator = BusMarkerAnimator(const MarkerService());
  final PolylineService _polylineService = const PolylineService();
  final PolylineCache _polylineCache = PolylineCache();
  late final AnimationController _animationController;
  Timer? _pollTimer;
  StreamSubscription<Map<String, BusPosition>>? _streamSub;
  List<Marker> _busMarkers = [];
  List<Marker> _stopMarkers = [];
  List<Polyline> _routePolylines = [];
  bool _markersNeedUpdate = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: _animator.animationDuration)
      ..addListener(_onAnimationTick);
    _buildStopMarkers();
    _buildRoutePolylines();
    if (widget.busPositionStream != null) {
      _subscribeToRealtime(widget.busPositionStream!);
    } else if (widget.pollingInterval != null) {
      _pollTimer = Timer.periodic(widget.pollingInterval!, (_) => _refreshFromProps());
    } else {
      _refreshFromProps();
    }
  }

  @override
  void didUpdateWidget(LiveMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stops != widget.stops) _buildStopMarkers();
    if (oldWidget.activeRoute != widget.activeRoute || oldWidget.extraPolylines != widget.extraPolylines) _buildRoutePolylines();
    if (oldWidget.busPositionStream != widget.busPositionStream) {
      _streamSub?.cancel();
      if (widget.busPositionStream != null) _subscribeToRealtime(widget.busPositionStream!);
    }
    if (widget.busPositionStream == null && oldWidget.buses != widget.buses) _refreshFromProps();
  }

  void _buildStopMarkers() {
    _stopMarkers = widget.stops.map((stop) => Marker(
      point: LatLng(stop.latitude, stop.longitude), width: 36, height: 36,
      child: GestureDetector(
        onTap: () => widget.onStopTapped?.call(stop),
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: Colors.blue.shade700, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
          child: Center(child: Text('${stop.orderIndex}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
        ),
      ),
    )).toList();
    _markersNeedUpdate = true;
  }

  void _buildRoutePolylines() {
    _routePolylines = [];
    if (widget.activeRoute != null && widget.activeRoute!.polyline.isNotEmpty) {
      _routePolylines.add(_polylineCache.getOrCreateRoute(widget.activeRoute!.id, widget.activeRoute!.polyline));
    }
    _routePolylines.addAll(widget.extraPolylines);
  }

  void _subscribeToRealtime(Stream<Map<String, BusPosition>> stream) {
    _streamSub = stream.listen((busMap) => _updateBuses(busMap));
  }

  void _updateBuses(Map<String, BusPosition> busMap) {
    for (final entry in busMap.entries) {
      _animator.updateBusPosition(entry.key, entry.value.position, entry.value.heading, occupancyPct: entry.value.occupancyPct, speedKmh: entry.value.speedKmh);
    }
    for (final key in _animator.activeBusIds.toList()) {
      if (!busMap.containsKey(key)) _animator.removeBus(key);
    }
    _animationController.duration = _animator.animationDuration;
    _animationController.forward(from: 0);
  }

  void _refreshFromProps() => _updateBuses(widget.buses);

  void _onAnimationTick() {
    _animator.tick(_animationController.value);
    _rebuildBusMarkers();
  }

  void _rebuildBusMarkers() {
    final markers = <Marker>[];
    for (final busId in _animator.activeBusIds) {
      markers.add(_animator.createMarker(busId));
    }
    if (markers.length != _busMarkers.length || _animator.frameCount % 3 == 0) {
      setState(() => _busMarkers = markers);
    } else {
      _busMarkers = markers;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _streamSub?.cancel();
    _animationController.dispose();
    _animator.clear();
    _polylineCache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCache = widget.tileCache != null;
    return RepaintBoundary(
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: widget.initialCenter,
          initialZoom: widget.initialZoom,
          onTap: (tapPosition, point) => widget.onMapTapped?.call(point),
        ),
        children: [
          TileLayer(
            urlTemplate: OpenStreetMapConfig.defaultUrlTemplate,
            userAgentPackageName: OpenStreetMapConfig.defaultUserAgent,
          ),
          MarkerLayer(markers: [..._stopMarkers, ..._busMarkers, ...widget.extraMarkers]),
          PolylineLayer(polylines: _routePolylines),
        ],
      ),
    );
  }
}
