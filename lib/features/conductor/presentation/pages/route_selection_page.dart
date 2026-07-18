import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../shared/domain/entities/route_entity.dart';
import '../providers/conductor_route_provider.dart';

class RouteSelectionPage extends ConsumerStatefulWidget {
  const RouteSelectionPage({super.key});
  @override
  ConsumerState<RouteSelectionPage> createState() => _RouteSelectionPageState();
}

class _RouteSelectionPageState extends ConsumerState<RouteSelectionPage> {
  RouteEntity? _selectedRoute;
  Map<String, dynamic>? _selectedBus;

  @override
  Widget build(BuildContext context) {
    final routesAsync = ref.watch(conductorRoutesProvider);
    final busesAsync = ref.watch(conductorBusesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Seleccionar ruta y bus', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: const Color(0xFF001B44),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Row(children: const [
            Icon(Icons.route, color: Color(0xFF001B44), size: 22),
            SizedBox(width: 8),
            Text('Ruta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF001B44), fontFamily: 'Inter')),
          ]),
          const SizedBox(height: 12),
          routesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Text('Error: $e', style: const TextStyle(color: Color(0xFFBA1A1A), fontFamily: 'Inter')),
            ),
            data: (routes) {
              if (routes.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: const Text('No hay rutas disponibles. La cooperativa debe crear rutas primero.', style: TextStyle(color: Color(0xFF434750), fontFamily: 'Inter')),
                );
              }
              return Column(
                children: routes.map((route) {
                  final isSelected = _selectedRoute?.id == route.id;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? const Color(0xFF001B44) : const Color(0xFFE0E0E0), width: isSelected ? 2 : 1),
                      boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF001B44).withAlpha(30), blurRadius: 8)] : null,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: const Color(0xFF001B44).withAlpha(20), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.route, color: Color(0xFF001B44), size: 22),
                      ),
                      title: Text(route.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
                      subtitle: Text('${route.stops.length} paradas', style: const TextStyle(fontSize: 13, color: Color(0xFF434750), fontFamily: 'Inter')),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF001B44)) : null,
                      onTap: () => setState(() {
                        _selectedRoute = route;
                        _selectedBus = null;
                      }),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          if (_selectedRoute != null) ...[
            const SizedBox(height: 24),
            Row(children: const [
              Icon(Icons.directions_bus, color: Color(0xFF001B44), size: 22),
              SizedBox(width: 8),
              Text('Bus', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF001B44), fontFamily: 'Inter')),
            ]),
            const SizedBox(height: 12),
            busesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Text('Error: $e', style: const TextStyle(color: Color(0xFFBA1A1A), fontFamily: 'Inter')),
              ),
              data: (buses) {
                if (buses.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: const Text('No hay buses disponibles.', style: TextStyle(color: Color(0xFF434750), fontFamily: 'Inter')),
                  );
                }
                return Column(
                  children: buses.map((bus) {
                    final isSelected = _selectedBus?['id'] == bus['id'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? const Color(0xFF001B44) : const Color(0xFFE0E0E0), width: isSelected ? 2 : 1),
                        boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF001B44).withAlpha(30), blurRadius: 8)] : null,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: const Color(0xFFFED000).withAlpha(30), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.directions_bus, color: Color(0xFF001B44), size: 22),
                        ),
                        title: Text(bus['plate'] as String? ?? 'Sin placa', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
                        subtitle: Text('Cap: ${bus['capacity'] ?? 40}', style: const TextStyle(fontSize: 13, color: Color(0xFF434750), fontFamily: 'Inter')),
                        trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF001B44)) : null,
                        onTap: () => setState(() => _selectedBus = bus),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedRoute == null || _selectedBus == null ? null : () => Navigator.pop(context, {
                'route': _selectedRoute,
                'bus': _selectedBus,
              }),
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: const Text('Confirmar selección', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFED000),
                foregroundColor: const Color(0xFF001B44),
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[500],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
