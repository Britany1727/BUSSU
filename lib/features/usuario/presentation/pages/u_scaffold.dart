import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_roles.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/auth/domain/entities/auth_user.dart';
import '../../../../shared/presentation/pages/unified_profile_page.dart';
import '../../../../shared/presentation/providers/location_provider.dart';
import 'map_page.dart';
import 'routes_page.dart';
import 'tickets_page.dart';
import 'alerts_page.dart';

class UScaffold extends ConsumerStatefulWidget {
  final int initialIndex;
  const UScaffold({super.key, this.initialIndex = 0});
  @override
  ConsumerState<UScaffold> createState() => UScaffoldState();
}

class UScaffoldState extends ConsumerState<UScaffold> {
  late int _index = widget.initialIndex;
  bool _permissionsRequested = false;

  static const _modules = [
    _Mod(Icons.map_outlined, Icons.map, 'Live'),
    _Mod(Icons.route_outlined, Icons.route, 'Rutas'),
    _Mod(Icons.confirmation_number_outlined, Icons.confirmation_number, 'Tickets'),
    _Mod(Icons.notifications_outlined, Icons.notifications, 'Alertas'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestPermissions());
  }

  Future<void> _requestPermissions() async {
    if (_permissionsRequested) return;
    _permissionsRequested = true;
    final service = ref.read(locationServiceProvider);
    final hasLoc = await service.hasPermission();
    if (!hasLoc) await service.requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_index < _modules.length ? _modules[_index].label : 'Perfil',
            style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF001B44),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => setState(() => _index = _modules.length),
            icon: const Icon(Icons.person_outline, color: Colors.white),
          ),
        ],
      ),
      drawer: _buildDrawer(user),
      body: IndexedStack(
        index: _index,
        children: const [
          MapPage(),
          RoutesPage(),
          TicketsPage(),
          AlertsPage(),
          UnifiedProfilePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        indicatorColor: const Color(0xFFFED000),
        destinations: [
          ..._modules.map((m) => NavigationDestination(
            icon: Icon(m.icon), selectedIcon: Icon(m.selectedIcon, color: const Color(0xFF001B44)), label: m.label,
          )),
          const NavigationDestination(icon: Icon(Icons.person_outlined), selectedIcon: Icon(Icons.person, color: Color(0xFF001B44)), label: 'Perfil'),
        ],
      ),
    );
  }

  Widget _buildDrawer(AppUser? user) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: Color(0xFF001B44)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(radius: 28, backgroundColor: Colors.white.withAlpha(30),
                    child: Text((user?.fullName ?? '?')[0].toUpperCase(),
                        style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w600))),
                const SizedBox(height: 10),
                Text(user?.fullName ?? 'Usuario', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                const SizedBox(height: 2),
                Text(user?.email ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Inter')),
              ]),
            ),
            ..._modules.asMap().entries.map((e) => _drawerItem(e.value.icon, e.value.label, e.key)),
            const Divider(),
            _drawerItem(Icons.person_outlined, 'Perfil', _modules.length),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
                  icon: const Icon(Icons.logout, size: 18, color: Color(0xFFBA1A1A)),
                  label: const Text('Cerrar sesion', style: TextStyle(color: Color(0xFFBA1A1A))),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFBA1A1A)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, int idx) {
    final selected = _index == idx;
    return ListTile(
      leading: Icon(icon, color: selected ? const Color(0xFF001B44) : const Color(0xFF434750)),
      title: Text(label, style: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: const Color(0xFF001B44), fontFamily: 'Inter')),
      selected: selected,
      selectedTileColor: const Color(0xFFFED000).withAlpha(20),
      onTap: () { setState(() => _index = idx); Navigator.pop(context); },
    );
  }

  void switchTo(int index) => setState(() => _index = index);
  void switchToLive() => setState(() => _index = 0);
}

class _Mod {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _Mod(this.icon, this.selectedIcon, this.label);
}
