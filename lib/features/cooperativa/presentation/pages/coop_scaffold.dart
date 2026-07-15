import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'coop_dashboard_page.dart';
import 'coop_stops_page.dart';
import 'coop_drivers_page.dart';
import 'coop_stop_requests_page.dart';
import 'coop_reports_page.dart';
import 'coop_chat_page.dart';
import '../../../../shared/presentation/pages/unified_profile_page.dart';

class CoopScaffold extends ConsumerStatefulWidget {
  const CoopScaffold({super.key});
  @override
  ConsumerState<CoopScaffold> createState() => _CoopScaffoldState();
}

class _CoopScaffoldState extends ConsumerState<CoopScaffold> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: IndexedStack(index: _idx, children: const [
        CoopDashboardPage(),
        CoopStopsPage(),
        CoopStopRequestsPage(),
        CoopDriversPage(),
        CoopReportsPage(),
        CoopChatPage(),
        UnifiedProfilePage(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        indicatorColor: const Color(0xFFFED000),
        height: 64,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: Color(0xFF001B44)), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.location_on_outlined), selectedIcon: Icon(Icons.location_on, color: Color(0xFF001B44)), label: 'Paradas'),
          NavigationDestination(icon: Icon(Icons.how_to_reg_outlined), selectedIcon: Icon(Icons.how_to_reg, color: Color(0xFF001B44)), label: 'Solicitudes'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people, color: Color(0xFF001B44)), label: 'Conductores'),
          NavigationDestination(icon: Icon(Icons.assessment_outlined), selectedIcon: Icon(Icons.assessment, color: Color(0xFF001B44)), label: 'Reportes'),
          NavigationDestination(icon: Icon(Icons.chat_outlined), selectedIcon: Icon(Icons.chat, color: Color(0xFF001B44)), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.person_outlined), selectedIcon: Icon(Icons.person, color: Color(0xFF001B44)), label: 'Profile'),
        ],
      ),
    );
  }
}
