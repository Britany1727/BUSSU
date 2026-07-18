import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_roles.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/auth/domain/entities/auth_user.dart';
import '../../../../shared/presentation/pages/unified_profile_page.dart';
import '../providers/fleet_provider.dart';
import 'coop_stops_page.dart';
import 'routes_management_page.dart';
import 'coop_drivers_page.dart';
import 'coop_reports_page.dart';
import 'coop_chat_page.dart';

class CoopScaffold extends ConsumerStatefulWidget {
  const CoopScaffold({super.key});
  @override
  ConsumerState<CoopScaffold> createState() => _CoopScaffoldState();
}

class _CoopScaffoldState extends ConsumerState<CoopScaffold> {
  int _idx = 0;
  bool _coopDialogShown = false;

  static const _modules = [
    _Mod(Icons.location_on_outlined, Icons.location_on, 'Paradas'),
    _Mod(Icons.route_outlined, Icons.route, 'Rutas'),
    _Mod(Icons.people_outline, Icons.people, 'Conductores'),
    _Mod(Icons.assessment_outlined, Icons.assessment, 'Reportes'),
    _Mod(Icons.chat_outlined, Icons.chat, 'Chat'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkCoopId());
  }

  Future<void> _checkCoopId() async {
    final coopId = ref.read(currentCoopIdProvider);
    if (coopId.isEmpty && !_coopDialogShown) {
      _coopDialogShown = true;
      await _showCoopSelectionDialog();
    }
  }

  Future<void> _showCoopSelectionDialog() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('cooperativas')
          .select('id, name')
          .eq('status', 'active')
          .order('name');

      final cooperativas = (response as List<dynamic>).cast<Map<String, dynamic>>();
      if (cooperativas.isEmpty || !mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Selecciona tu Cooperativa',
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Color(0xFF001B44))),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: cooperativas.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final c = cooperativas[i];
                return ListTile(
                  leading: const Icon(Icons.directions_bus, color: Color(0xFF001B44)),
                  title: Text(c['name'] as String,
                      style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                  onTap: () async {
                    Navigator.pop(context);
                    await Supabase.instance.client
                        .from('profiles')
                        .update({'cooperativa_id': c['id']})
                        .eq('id', user.id);
                    if (mounted) {
                      ref.invalidate(currentUserProvider);
                      setState(() => _coopDialogShown = false);
                    }
                  },
                );
              },
            ),
          ),
        ),
      );
    } catch (_) {
      // Silent fail
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    if (_idx == -1) return _buildHomePage(user);

    return Scaffold(
      appBar: AppBar(
        title: Text(_idx < _modules.length ? _modules[_idx].label : 'Perfil',
            style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF001B44),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => setState(() => _idx = _modules.length),
            icon: const Icon(Icons.person_outline, color: Colors.white),
          ),
        ],
      ),
      drawer: _buildDrawer(user),
      body: IndexedStack(
        index: _idx,
        children: const [
          CoopStopsPage(),
          RoutesManagementPage(),
          CoopDriversPage(),
          CoopReportsPage(),
          UnifiedProfilePage(),
          CoopChatPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) {
          if (i < _modules.length) {
            setState(() => _idx = i);
          } else {
            setState(() => _idx = _modules.length);
          }
        },
        indicatorColor: const Color(0xFFFED000),
        height: 64,
        destinations: [
          ..._modules.take(4).map((m) => NavigationDestination(
            icon: Icon(m.icon), selectedIcon: Icon(m.selectedIcon, color: const Color(0xFF001B44)), label: m.label,
          )),
          const NavigationDestination(icon: Icon(Icons.person_outlined), selectedIcon: Icon(Icons.person, color: Color(0xFF001B44)), label: 'Perfil'),
        ],
      ),
    );
  }

  Widget _buildHomePage(AppUser? user) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cooperativa', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF001B44),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => setState(() => _idx = _modules.length),
            icon: const Icon(Icons.person_outline, color: Colors.white),
          ),
        ],
      ),
      drawer: _buildDrawer(user),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Text('Bienvenido, ${user?.fullName ?? 'Cooperativa'}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF001B44), fontFamily: 'Inter')),
              const SizedBox(height: 6),
              const Text('Selecciona una opcion', style: TextStyle(fontSize: 14, color: Color(0xFF434750), fontFamily: 'Inter')),
              const SizedBox(height: 24),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildHomeCard(
                              icon: Icons.map_outlined,
                              title: 'Mapa y Paradas',
                              subtitle: 'Ver mapa de buses y gestionar paradas del sistema',
                              color: const Color(0xFF001B44),
                              onTap: () => setState(() => _idx = 0),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildHomeCard(
                              icon: Icons.route_outlined,
                              title: 'Rutas',
                              subtitle: 'Crear y gestionar rutas del sistema',
                              color: const Color(0xFF1565C0),
                              onTap: () => setState(() => _idx = 1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildHomeCard(
                              icon: Icons.how_to_reg_outlined,
                              title: 'Solicitudes',
                              subtitle: 'Revisar y aprobar solicitudes de nuevas paradas',
                              color: const Color(0xFF2E7D32),
                              onTap: () => setState(() => _idx = 0),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildHomeCard(
                              icon: Icons.people_outline,
                              title: 'Conductores',
                              subtitle: 'Gestionar conductores y asignar buses',
                              color: const Color(0xFF6A1B9A),
                              onTap: () => setState(() => _idx = 2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 12)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color, fontFamily: 'Inter')),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF434750), fontFamily: 'Inter', height: 1.4)),
          ],
        ),
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
                Text(user?.fullName ?? 'Cooperativa', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                const SizedBox(height: 2),
                Text(user?.email ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Inter')),
              ]),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined, color: Color(0xFF001B44)),
              title: const Text('Inicio', style: TextStyle(fontFamily: 'Inter', color: Color(0xFF001B44))),
              onTap: () { setState(() => _idx = -1); Navigator.pop(context); },
            ),
            const Divider(),
            ..._modules.sublist(0, 4).asMap().entries.map((e) => _drawerItem(e.value.icon, e.value.label, e.key)),
            const Divider(),
            _drawerItem(Icons.person_outlined, 'Perfil', _modules.length - 1),
            _drawerItem(Icons.chat_outlined, 'Chat', _modules.length),
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
    final selected = _idx == idx;
    return ListTile(
      leading: Icon(icon, color: selected ? const Color(0xFF001B44) : const Color(0xFF434750)),
      title: Text(label, style: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: const Color(0xFF001B44), fontFamily: 'Inter')),
      selected: selected,
      selectedTileColor: const Color(0xFFFED000).withAlpha(20),
      onTap: () { setState(() => _idx = idx); Navigator.pop(context); },
    );
  }
}

class _Mod {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _Mod(this.icon, this.selectedIcon, this.label);
}
