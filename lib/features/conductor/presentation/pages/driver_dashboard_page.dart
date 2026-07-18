import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../shared/presentation/providers/location_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/trip_provider.dart';

class DriverDashboardPage extends ConsumerStatefulWidget {
  const DriverDashboardPage({super.key});
  @override
  ConsumerState<DriverDashboardPage> createState() => _DriverDashboardPageState();
}

class _DriverDashboardPageState extends ConsumerState<DriverDashboardPage> {
  int _passengerCount = 0;

  void _startTrip() async {
    final service = ref.read(locationServiceProvider);
    final permission = await service.hasPermission();
    if (!permission) {
      final granted = await service.requestPermission();
      if (!granted) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Se requiere permiso de ubicación para iniciar el viaje'), backgroundColor: Color(0xFFBA1A1A)));
        return;
      }
    }
    final result = await service.getCurrentLocation();
    result.fold(
      (f) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message.toString()), backgroundColor: const Color(0xFFBA1A1A))); },
      (loc) {
        if (!mounted) return;
        final latLng = LatLng(loc.latitude, loc.longitude);
        ref.read(driverLocationProvider.notifier).state = latLng;
        ref.read(tripActiveProvider.notifier).state = true;
        final driverId = ref.read(driverIdProvider);
        ref.read(startTripUseCaseProvider).execute(driverId: driverId, busId: 'bus-123', routeId: 'route-a');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Viaje iniciado — presiona "Iniciar ruta" para activar GPS'), backgroundColor: Color(0xFF001B44)));
      },
    );
  }

  void _endTrip() {
    ref.read(tripActiveProvider.notifier).state = false;
    ref.read(driverLocationProvider.notifier).state = null;
    ref.read(endTripUseCaseProvider).execute('current-trip');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Viaje finalizado — recursos liberados'), backgroundColor: Color(0xFF001B44)));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final active = ref.watch(tripActiveProvider);

    String greeting() {
      final h = DateTime.now().hour;
      if (h < 12) return 'Buenos días';
      if (h < 18) return 'Buenas tardes';
      return 'Buenas noches';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const SizedBox(height: 32),
        Center(child: CircleAvatar(radius: 52, backgroundColor: const Color(0xFF001B44), child: Text((user?.fullName ?? 'C')[0].toUpperCase(), style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.w600, fontFamily: 'Inter')))),
        const SizedBox(height: 16),
        Text('${greeting()}, ${user?.fullName ?? "Conductor"}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF001B44), fontFamily: 'Inter')),
        const SizedBox(height: 8),
        Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFFED000).withAlpha(30), borderRadius: BorderRadius.circular(8)), child: const Text('Bus ABC-123', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')))),
        const SizedBox(height: 32),
        Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 8)]), child: Column(children: [
          Icon(active ? Icons.directions_bus : Icons.local_parking, size: 48, color: active ? const Color(0xFF001B44) : Colors.grey),
          const SizedBox(height: 12),
          Text(active ? 'Viaje en curso' : 'Listo para iniciar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: active ? const Color(0xFF001B44) : const Color(0xFF434750), fontFamily: 'Inter')),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: active ? _endTrip : _startTrip,
            style: ElevatedButton.styleFrom(backgroundColor: active ? const Color(0xFFBA1A1A) : const Color(0xFF001B44), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
            child: Text(active ? 'Finalizar viaje' : 'Iniciar viaje'),
          )),
        ])),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 8)]), child: Column(children: [
          const Text('Conteo de pasajeros', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton.filled(onPressed: () => setState(() => _passengerCount = (_passengerCount - 1).clamp(0, 40)), icon: const Icon(Icons.remove), style: IconButton.styleFrom(backgroundColor: const Color(0xFF001B44).withAlpha(20), foregroundColor: const Color(0xFF001B44))),
            const SizedBox(width: 24),
            Text('$_passengerCount', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: Color(0xFF001B44), fontFamily: 'Inter')),
            const SizedBox(width: 24),
            IconButton.filled(onPressed: () => setState(() => _passengerCount = (_passengerCount + 1).clamp(0, 40)), icon: const Icon(Icons.add), style: IconButton.styleFrom(backgroundColor: const Color(0xFF001B44).withAlpha(20), foregroundColor: const Color(0xFF001B44))),
          ]),
          const SizedBox(height: 8),
          Text('/ 40 capacidad', style: const TextStyle(fontSize: 14, color: Color(0xFF434750), fontFamily: 'Inter')),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _passengerCount / 40, minHeight: 6, backgroundColor: Colors.grey[200], valueColor: const AlwaysStoppedAnimation(Color(0xFFFED000)))),
        ])),
      ]),
    );
  }
}
