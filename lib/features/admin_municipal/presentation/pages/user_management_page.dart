import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/repositories/network_monitor_repository.dart';
import '../providers/system_alerts_provider.dart';

class UserManagementPage extends ConsumerStatefulWidget {
  const UserManagementPage({super.key});

  @override
  ConsumerState<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends ConsumerState<UserManagementPage> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(allUsersProvider);

    return Container(
      color: const Color(0xFFF8F9FA),
      child: users.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF001B44))),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (userList) {
          final usuarios = userList.where((u) => (u['role'] as String? ?? 'usuario') == 'usuario').toList();
          final conductores = userList.where((u) => (u['role'] as String? ?? '') == 'conductor').toList();
          final coopAdmins = userList.where((u) => (u['role'] as String? ?? '') == 'cooperativa_admin').toList();
          final municipalAdmins = userList.where((u) => (u['role'] as String? ?? '') == 'municipal_admin').toList();

          if (_selectedCategory != null) {
            List<Map<String, dynamic>> filteredList;
            String title;
            Color color;
            IconData icon;
            switch (_selectedCategory) {
              case 'usuarios':
                filteredList = usuarios; title = 'Usuarios'; color = Colors.grey; icon = Icons.person;
              case 'conductores':
                filteredList = conductores; title = 'Conductores'; color = Colors.orange; icon = Icons.directions_bus;
              case 'cooperativas':
                filteredList = coopAdmins; title = 'Admin Cooperativa'; color = Colors.blue; icon = Icons.business;
              case 'municipales':
                filteredList = municipalAdmins; title = 'Admin Municipal'; color = Colors.purple; icon = Icons.account_balance;
              default:
                filteredList = []; title = ''; color = Colors.grey; icon = Icons.person;
            }
            return Column(children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 0), child: Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF001B44)), onPressed: () => setState(() => _selectedCategory = null)),
                Icon(icon, color: color, size: 22), const SizedBox(width: 8),
                Expanded(child: Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color, fontFamily: 'Inter'))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(8)), child: Text('${filteredList.length}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color, fontFamily: 'Inter'))),
              ])),
              const SizedBox(height: 12),
              Expanded(child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredList.length,
                itemBuilder: (_, i) {
                  final u = filteredList[i];
                  final fullName = (u['full_name'] as String?) ?? 'Sin nombre';
                  final email = (u['email'] as String?) ?? '';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 4)]),
                    child: Row(children: [
                      CircleAvatar(radius: 22, backgroundColor: color.withAlpha(30), child: Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : '?', style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter'))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(fullName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
                        if (email.isNotEmpty) Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF434750), fontFamily: 'Inter'), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ])),
                      PopupMenuButton<String>(
                        onSelected: (newRole) {
                          ref.read(networkMonitorRepositoryProvider).updateUserRole(u['id'] as String, newRole);
                          ref.invalidate(allUsersProvider);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'usuario', child: Text('Usuario')),
                          const PopupMenuItem(value: 'conductor', child: Text('Conductor')),
                          const PopupMenuItem(value: 'cooperativa_admin', child: Text('Admin Cooperativa')),
                          const PopupMenuItem(value: 'municipal_admin', child: Text('Admin Municipal')),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.more_vert, size: 16, color: Color(0xFF434750)),
                        ),
                      ),
                    ]),
                  );
                },
              )),
            ]);
          }

          return Column(children: [
            const Padding(padding: EdgeInsets.fromLTRB(16, 20, 16, 0), child: Row(children: [
              Icon(Icons.group, color: Color(0xFF001B44), size: 22), SizedBox(width: 8),
              Text('Gestión de Usuarios', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF001B44), fontFamily: 'Inter')),
            ])),
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
              _categoryCard(context, Icons.person, '${usuarios.length}', 'Usuarios', Colors.grey, () => setState(() => _selectedCategory = 'usuarios')),
              const SizedBox(width: 8),
              _categoryCard(context, Icons.directions_bus, '${conductores.length}', 'Conductores', Colors.orange, () => setState(() => _selectedCategory = 'conductores')),
            ])),
            const SizedBox(height: 8),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
              _categoryCard(context, Icons.business, '${coopAdmins.length}', 'Coop Admin', Colors.blue, () => setState(() => _selectedCategory = 'cooperativas')),
              const SizedBox(width: 8),
              _categoryCard(context, Icons.account_balance, '${municipalAdmins.length}', 'Municipal', Colors.purple, () => setState(() => _selectedCategory = 'municipales')),
            ])),
          ]);
        },
      ),
    );
  }

  Widget _categoryCard(BuildContext ctx, IconData icon, String count, String label, Color color, VoidCallback onTap) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 4)]),
        child: Column(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color, fontFamily: 'Inter')),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF434750), fontFamily: 'Inter'), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Icon(Icons.chevron_right, color: color.withAlpha(150), size: 18),
        ]),
      ),
    ));
  }
}
