import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_overview_page.dart';
import 'cooperativas_crud_page.dart';
import 'user_management_page.dart';
import 'incidents_page.dart';
import 'premium_management_page.dart';
import 'municipal_reports_page.dart';
import 'municipal_notifications_page.dart';
import 'municipal_config_page.dart';
import 'admin_chat_page.dart';
import '../../../../shared/presentation/pages/unified_profile_page.dart';

class AdminScaffold extends ConsumerStatefulWidget {
  const AdminScaffold({super.key});
  @override
  ConsumerState<AdminScaffold> createState() => _AdminScaffoldState();
}

class _AdminScaffoldState extends ConsumerState<AdminScaffold> {
  int _idx = 0;

  static List<Widget> _pages(int idx, void Function(int) onNavigate) => [
    AdminOverviewPage(onNavigate: onNavigate),
    const CooperativasCrudPage(),
    const UserManagementPage(),
    const IncidentsPage(),
    const AdminChatPage(),
    const PremiumManagementPage(),
    const MunicipalReportsPage(),
    const MunicipalNotificationsPage(),
    const MunicipalConfigPage(),
    const UnifiedProfilePage(),
  ];

  static const _titles = [
    'Overview',
    'Cooperativas',
    'Usuarios',
    'Alertas',
    'Chat',
    'Premium',
    'Reportes',
    'Notificaciones',
    'Configuración',
    'Perfil',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(_titles[_idx],
            style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                color: Color(0xFF001B44))),
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        actions: [
          Builder(builder: (ctx) => IconButton(
            icon: const Icon(Icons.person_outline, color: Color(0xFF001B44)),
            onPressed: () => setState(() => _idx = 9),
          )),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF001B44),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.account_balance, color: Color(0xFFFED000), size: 36),
                    SizedBox(height: 8),
                    Text('Admin Municipal',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter')),
                    Text('Panel de control',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontFamily: 'Inter')),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _drawerItem(0, Icons.dashboard_outlined, 'Overview'),
              _drawerItem(1, Icons.business_outlined, 'Cooperativas'),
              _drawerItem(2, Icons.group_outlined, 'Usuarios'),
              _drawerItem(3, Icons.warning_amber_outlined, 'Alertas'),
              _drawerItem(4, Icons.chat_outlined, 'Chat'),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _drawerItem(5, Icons.workspace_premium_outlined, 'Premium'),
              _drawerItem(6, Icons.assessment_outlined, 'Reportes'),
              _drawerItem(7, Icons.notifications_outlined, 'Notificaciones'),
              _drawerItem(8, Icons.settings_outlined, 'Configuración'),
              const Spacer(),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _drawerItem(9, Icons.person_outlined, 'Perfil'),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: _pages(_idx, (i) => setState(() => _idx = i))[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx < 5 ? _idx : -1,
        onDestinationSelected: (i) => setState(() => _idx = i),
        indicatorColor: const Color(0xFFFED000),
        height: 64,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: Color(0xFF001B44)), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.business_outlined), selectedIcon: Icon(Icons.business, color: Color(0xFF001B44)), label: 'Coops'),
          NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group, color: Color(0xFF001B44)), label: 'Usuarios'),
          NavigationDestination(icon: Icon(Icons.warning_amber_outlined), selectedIcon: Icon(Icons.warning_amber, color: Color(0xFF001B44)), label: 'Alertas'),
          NavigationDestination(icon: Icon(Icons.chat_outlined), selectedIcon: Icon(Icons.chat, color: Color(0xFF001B44)), label: 'Chat'),
        ],
      ),
      floatingActionButton: _idx < 5
          ? FloatingActionButton.small(
              onPressed: () => Scaffold.of(context).openDrawer(),
              backgroundColor: const Color(0xFF001B44),
              child: const Icon(Icons.menu, color: Colors.white, size: 20),
            )
          : null,
    );
  }

  Widget _drawerItem(int index, IconData icon, String label) {
    final selected = _idx == index;
    return ListTile(
      leading: Icon(icon, color: selected ? const Color(0xFF001B44) : const Color(0xFF434750), size: 22),
      title: Text(label, style: TextStyle(
        fontFamily: 'Inter',
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        color: selected ? const Color(0xFF001B44) : const Color(0xFF434750),
        fontSize: 14,
      )),
      selected: selected,
      selectedTileColor: const Color(0xFFFED000).withAlpha(30),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: () {
        Navigator.pop(context);
        setState(() => _idx = index);
      },
    );
  }
}
