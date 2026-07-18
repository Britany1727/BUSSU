import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin_municipal/presentation/pages/admin_scaffold.dart';
import '../../features/admin_municipal/presentation/pages/cooperativas_crud_page.dart';
import '../../features/admin_municipal/presentation/pages/incidents_page.dart';
import '../../features/admin_municipal/presentation/pages/municipal_config_page.dart';
import '../../features/admin_municipal/presentation/pages/municipal_notifications_page.dart';
import '../../features/admin_municipal/presentation/pages/municipal_overview_page.dart';
import '../../features/admin_municipal/presentation/pages/municipal_reports_page.dart';
import '../../features/admin_municipal/presentation/pages/premium_management_page.dart';
import '../../features/admin_municipal/presentation/pages/user_management_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/permissions_request_page.dart';
import '../../features/chat/presentation/pages/chat_page.dart';
import '../../features/conductor/presentation/pages/active_trip_page.dart';
import '../../features/conductor/presentation/pages/c_scaffold.dart';
import '../../features/conductor/presentation/pages/bus_status_page.dart';
import '../../features/conductor/presentation/pages/conductor_alerts_page.dart';
import '../../features/conductor/presentation/pages/driver_dashboard_page.dart';
import '../../features/conductor/presentation/pages/occupancy_page.dart';
import '../../features/conductor/presentation/pages/trip_history_page.dart'
    as conductor_history;
import '../../features/cooperativa/presentation/pages/buses_management_page.dart';
import '../../features/cooperativa/presentation/pages/coop_alerts_page.dart';
import '../../features/cooperativa/presentation/pages/coop_analytics_page.dart';
import '../../features/cooperativa/presentation/pages/coop_trip_history_page.dart';
import '../../features/cooperativa/presentation/pages/coop_scaffold.dart';
import '../../features/cooperativa/presentation/pages/fleet_dashboard_page.dart';
import '../../features/cooperativa/presentation/pages/reports_page.dart';
import '../../features/cooperativa/presentation/pages/routes_management_page.dart';
import '../../features/usuario/presentation/pages/alerts_page.dart';
import '../../features/usuario/presentation/pages/u_scaffold.dart';
import '../../features/usuario/presentation/pages/favorites_page.dart';
import '../../features/usuario/presentation/pages/map_page.dart';
import '../../features/usuario/presentation/pages/premium_upgrade_page.dart';
import '../../shared/presentation/pages/unified_profile_page.dart';
import '../../features/usuario/presentation/pages/routes_page.dart';
import '../../features/usuario/presentation/pages/tickets_page.dart';
import '../../features/usuario/presentation/pages/trip_history_page.dart';
import '../constants/app_roles.dart';
import '../services/permission_service.dart';
import 'role_guard.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final permissionService = PermissionService();

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    redirect: (context, state) async {
      final isLoggedIn = authState.valueOrNull != null;
      final isLoginRoute = state.matchedLocation == '/login';
      final isPermissionsRoute = state.matchedLocation == '/permissions';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) {
        final hasPermissions = await permissionService.areAllPermissionsGranted();
        if (!hasPermissions) return '/permissions';
        return authState.valueOrNull!.pathPrefix;
      }
      if (isLoggedIn && !isPermissionsRoute) {
        final hasPermissions = await permissionService.areAllPermissionsGranted();
        if (!hasPermissions) return '/permissions';
      }
      if (isLoggedIn && isPermissionsRoute) {
        final hasPermissions = await permissionService.areAllPermissionsGranted();
        if (hasPermissions) return authState.valueOrNull!.pathPrefix;
      }

      if (isLoggedIn) {
        final role = authState.valueOrNull!;
        final currentPath = state.matchedLocation;
        switch (role) {
          case UserRole.usuario:
            if (!currentPath.startsWith('/usuario') && currentPath != '/chat' && !isPermissionsRoute) {
              return '/usuario';
            }
          case UserRole.conductor:
            if (!currentPath.startsWith('/conductor') && currentPath != '/chat' && !isPermissionsRoute) {
              return '/conductor';
            }
          case UserRole.cooperativaAdmin:
            if (!currentPath.startsWith('/cooperativa') && currentPath != '/chat' && !isPermissionsRoute) {
              return '/cooperativa';
            }
          case UserRole.municipalAdmin:
            if (!currentPath.startsWith('/admin') && currentPath != '/chat' && !isPermissionsRoute) {
              return '/admin';
            }
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/permissions',
        name: 'permissions',
        builder: (context, state) => const PermissionsRequestPage(),
      ),
      GoRoute(
        path: '/usuario',
        name: 'usuario',
        builder: (context, state) => const UScaffold(),
      ),
      GoRoute(
        path: '/usuario/map',
        name: 'usuario-map',
        builder: (context, state) => const MapPage(),
      ),
      GoRoute(
        path: '/usuario/routes',
        name: 'usuario-routes',
        builder: (context, state) => const RoutesPage(),
      ),
      GoRoute(
        path: '/usuario/tickets',
        name: 'usuario-tickets',
        builder: (context, state) => const TicketsPage(),
      ),
      GoRoute(
        path: '/usuario/alerts',
        name: 'usuario-alerts',
        builder: (context, state) => const AlertsPage(),
      ),
      GoRoute(
        path: '/usuario/premium',
        name: 'usuario-premium',
        builder: (context, state) => const PremiumUpgradePage(),
      ),
      GoRoute(
        path: '/usuario/favorites',
        name: 'usuario-favorites',
        builder: (context, state) => const FavoritesPage(),
      ),
      GoRoute(
        path: '/usuario/history',
        name: 'usuario-history',
        builder: (context, state) => const TripHistoryPage(),
      ),
      GoRoute(
        path: '/usuario/profile',
        name: 'usuario-profile',
        builder: (context, state) => const UnifiedProfilePage(),
      ),
      GoRoute(
        path: '/conductor',
        name: 'conductor',
        builder: (context, state) => const CScaffold(),
      ),
      GoRoute(
        path: '/conductor/dashboard',
        name: 'conductor-dashboard',
        builder: (context, state) => const DriverDashboardPage(),
      ),
      GoRoute(
        path: '/conductor/active-trip',
        name: 'conductor-active-trip',
        builder: (context, state) => const ActiveTripPage(),
      ),
      GoRoute(
        path: '/conductor/occupancy',
        name: 'conductor-occupancy',
        builder: (context, state) => const OccupancyPage(),
      ),
      GoRoute(
        path: '/conductor/bus-status',
        name: 'conductor-bus-status',
        builder: (context, state) => const BusStatusPage(),
      ),
      GoRoute(
        path: '/conductor/alerts',
        name: 'conductor-alerts',
        builder: (context, state) => const ConductorAlertsPage(),
      ),
      GoRoute(
        path: '/conductor/history',
        name: 'conductor-history',
        builder: (context, state) => const conductor_history.DriverTripHistoryPage(),
      ),
      GoRoute(
        path: '/cooperativa',
        name: 'cooperativa',
        builder: (context, state) => const CoopScaffold(),
      ),
      GoRoute(
        path: '/cooperativa/dashboard',
        name: 'cooperativa-dashboard',
        builder: (context, state) => const FleetDashboardPage(),
      ),
      GoRoute(
        path: '/cooperativa/reports',
        name: 'cooperativa-reports',
        builder: (context, state) => const ReportsPage(),
      ),
      GoRoute(
        path: '/cooperativa/buses',
        name: 'cooperativa-buses',
        builder: (context, state) => const BusesManagementPage(),
      ),
      GoRoute(
        path: '/cooperativa/routes',
        name: 'cooperativa-routes',
        builder: (context, state) => const RoutesManagementPage(),
      ),
      GoRoute(
        path: '/cooperativa/analytics',
        name: 'cooperativa-analytics',
        builder: (context, state) => const CoopAnalyticsPage(),
      ),
      GoRoute(
        path: '/cooperativa/history',
        name: 'cooperativa-history',
        builder: (context, state) => const CoopTripHistoryPage(),
      ),
      GoRoute(
        path: '/cooperativa/alerts',
        name: 'cooperativa-alerts',
        builder: (context, state) => const CoopAlertsPage(),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminScaffold(),
      ),
      GoRoute(
        path: '/admin/overview',
        name: 'admin-overview',
        builder: (context, state) => const MunicipalOverviewPage(),
      ),
      GoRoute(
        path: '/admin/incidents',
        name: 'admin-incidents',
        builder: (context, state) => const IncidentsPage(),
      ),
      GoRoute(
        path: '/admin/cooperativas',
        name: 'admin-cooperativas',
        builder: (context, state) => const CooperativasCrudPage(),
      ),
      GoRoute(
        path: '/admin/premium',
        name: 'admin-premium',
        builder: (context, state) => const PremiumManagementPage(),
      ),
      GoRoute(
        path: '/admin/users',
        name: 'admin-users',
        builder: (context, state) => const UserManagementPage(),
      ),
      GoRoute(
        path: '/admin/reports',
        name: 'admin-reports',
        builder: (context, state) => const MunicipalReportsPage(),
      ),
      GoRoute(
        path: '/admin/notifications',
        name: 'admin-notifications',
        builder: (context, state) => const MunicipalNotificationsPage(),
      ),
      GoRoute(
        path: '/admin/config',
        name: 'admin-config',
        builder: (context, state) => const MunicipalConfigPage(),
      ),
      GoRoute(
        path: '/chat/:roomId',
        name: 'chat',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId'] ?? '';
          return ChatPage(roomId: roomId);
        },
      ),
    ],
  );
});
