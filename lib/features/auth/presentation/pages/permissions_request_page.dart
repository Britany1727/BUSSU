import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/role_guard.dart';
import '../../../../core/services/permission_service.dart';

class PermissionsRequestPage extends StatefulWidget {
  const PermissionsRequestPage({super.key});

  @override
  State<PermissionsRequestPage> createState() => _PermissionsRequestPageState();
}

class _PermissionsRequestPageState extends State<PermissionsRequestPage> {
  final _permissionService = PermissionService();
  bool _locationGranted = false;
  bool _notificationGranted = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentPermissions();
  }

  Future<void> _checkCurrentPermissions() async {
    final loc = await _permissionService.isLocationGranted();
    final notif = await _permissionService.isNotificationGranted();
    if (mounted) {
      setState(() {
        _locationGranted = loc;
        _notificationGranted = notif;
      });
      if (loc && notif) _goForward();
    }
  }

  void _goForward() {
    final auth = ProviderScope.containerOf(context).read(authStateChangesProvider);
    final role = auth.valueOrNull;
    if (role != null && mounted) {
      context.go(role.pathPrefix);
    }
  }

  Future<void> _requestLocation() async {
    setState(() => _loading = true);
    final granted = await _permissionService.requestLocation();
    if (mounted) {
      setState(() {
        _locationGranted = granted;
        _loading = false;
      });
      if (_locationGranted && _notificationGranted) _goForward();
    }
  }

  Future<void> _requestNotification() async {
    setState(() => _loading = true);
    final granted = await _permissionService.requestNotification();
    if (mounted) {
      setState(() {
        _notificationGranted = granted;
        _loading = false;
      });
      if (_locationGranted && _notificationGranted) _goForward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          final auth = ProviderScope.containerOf(context).read(authStateChangesProvider);
          final role = auth.valueOrNull;
          if (role != null && mounted) {
            context.go(role.pathPrefix);
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF001B44), Color(0xFF001B44), Color(0xFFF8F9FA)],
              stops: [0.0, 0.30, 0.30],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.security, size: 48, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text('Permisos necesarios',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Inter')),
                    const SizedBox(height: 4),
                    const Text('Para brindarte la mejor experiencia',
                        style: TextStyle(fontSize: 14, color: Colors.white70, fontFamily: 'Inter')),
                    const SizedBox(height: 32),
                    _buildPermissionCard(
                      icon: Icons.location_on_outlined,
                      title: 'Ubicación GPS',
                      description: 'Necesitamos tu ubicación para mostrarte rutas cercanas, paradas disponibles y el mapa en tiempo real.',
                      granted: _locationGranted,
                      onTap: _locationGranted ? null : _requestLocation,
                      color: const Color(0xFF2196F3),
                    ),
                    const SizedBox(height: 16),
                    _buildPermissionCard(
                      icon: Icons.notifications_outlined,
                      title: 'Notificaciones',
                      description: 'Recibe alertas sobre estado de tu viaje, proximidad a paradas y avisos importantes del sistema.',
                      granted: _notificationGranted,
                      onTap: _notificationGranted ? null : _requestNotification,
                      color: const Color(0xFFFED000),
                    ),
                    const SizedBox(height: 28),
                    if (_loading)
                      const CircularProgressIndicator(color: Color(0xFF001B44))
                    else if (_locationGranted && _notificationGranted)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _goForward,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF001B44),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
                          ),
                          child: const Text('Continuar'),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: () async {
                          final all = await _permissionService.areAllPermissionsGranted();
                          if (all && mounted) _goForward();
                        },
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF434750)),
                        child: const Text('Omitir por ahora', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool granted,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x1A002F6C), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: granted ? Colors.green.withAlpha(20) : color.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              granted ? Icons.check_circle : icon,
              color: granted ? Colors.green : color,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(fontSize: 13, color: Color(0xFF434750), fontFamily: 'Inter', height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!granted)
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                backgroundColor: color.withAlpha(20),
                foregroundColor: color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Activar', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter', fontSize: 13)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.green.withAlpha(20), borderRadius: BorderRadius.circular(8)),
              child: const Text('Activo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green, fontFamily: 'Inter')),
            ),
        ],
      ),
    );
  }
}
