import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_roles.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/conductor/presentation/pages/incident_report_page.dart';
import 'help/help_page.dart';
import 'help/privacy_agreement_page.dart';

final notifToggleProvider = StateProvider<bool>((ref) => true);

class UnifiedProfilePage extends ConsumerStatefulWidget {
  const UnifiedProfilePage({super.key});
  @override
  ConsumerState<UnifiedProfilePage> createState() => _UnifiedProfilePageState();
}

class _UnifiedProfilePageState extends ConsumerState<UnifiedProfilePage> {
  bool _uploading = false;
  bool _editing = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameCtrl = TextEditingController(text: user?.fullName ?? '');
    _phoneCtrl = TextEditingController(text: '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 512, maxHeight: 512);
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      final file = File(picked.path);
      final ext = picked.path.split('.').last;
      final path = 'avatars/${user.id}.$ext';

      final storage = Supabase.instance.client.storage;
      await storage.from('avatars').upload(path, file, fileOptions: const FileOptions(upsert: true));
      final publicUrl = storage.from('avatars').getPublicUrl(path);

      await Supabase.instance.client.from('profiles').update({'avatar_url': publicUrl}).eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto de perfil actualizada'), backgroundColor: Color(0xFF2E7D32)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFBA1A1A)));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _editing = false);
    try {
      await Supabase.instance.client.from('profiles').update({
        'full_name': _nameCtrl.text.trim(),
      }).eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado'), backgroundColor: Color(0xFF2E7D32)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: const Color(0xFFBA1A1A)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final role = user?.role;
    final isPremium = user?.isPremium ?? false;
    final notifs = ref.watch(notifToggleProvider);
    final isUsuario = role == UserRole.usuario;
    final isConductor = role == UserRole.conductor;

    return ListView(padding: const EdgeInsets.all(16), children: [
      const SizedBox(height: 24),
      Row(children: [
        const Expanded(child: Text('Mi Perfil', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF001B44), fontFamily: 'Inter'))),
        IconButton(
          onPressed: () {
            if (_editing) {
              _saveProfile();
            } else {
              setState(() {
                _editing = true;
                _nameCtrl.text = user?.fullName ?? '';
              });
            }
          },
          icon: Icon(_editing ? Icons.check : Icons.edit_outlined, color: const Color(0xFF001B44)),
          tooltip: _editing ? 'Guardar' : 'Editar',
        ),
      ]),
      const SizedBox(height: 20),
      _buildAvatar(user?.avatarUrl, user?.fullName),
      const SizedBox(height: 12),
      Text(user?.fullName ?? 'Usuario', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
      const SizedBox(height: 4),
      Text(user?.email ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Color(0xFF434750), fontFamily: 'Inter')),
      const SizedBox(height: 8),
      _buildRoleBadge(role, isPremium),
      const SizedBox(height: 24),
      Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 8)]),
        child: Column(children: [
          if (_editing) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nombre completo',
                  labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF434750), fontFamily: 'Inter'),
                  prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF001B44)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF001B44))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF001B44), fontFamily: 'Inter'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _phoneCtrl,
                decoration: InputDecoration(
                  labelText: 'Telefono (opcional)',
                  labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF434750), fontFamily: 'Inter'),
                  prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF001B44)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF001B44))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF001B44), fontFamily: 'Inter'),
                keyboardType: TextInputType.phone,
              ),
            ),
            const Divider(height: 1),
          ] else ...[
            _buildInfoTile(Icons.person_outline, 'Nombre completo', user?.fullName ?? 'No disponible'),
            const Divider(height: 1, indent: 56),
            _buildInfoTile(Icons.email_outlined, 'Correo electronico', user?.email ?? 'No disponible'),
            const Divider(height: 1, indent: 56),
            if (isConductor) ...[
              _buildInfoTile(Icons.badge_outlined, 'Rol', 'Conductor'),
              const Divider(height: 1, indent: 56),
              _buildInfoTile(Icons.directions_bus_outlined, 'Bus asignado', 'Bus ABC-123'),
              const Divider(height: 1, indent: 56),
            ],
            if (isUsuario) ...[
              _buildInfoTile(Icons.person_outline, 'Tipo de cuenta', isPremium ? 'Premium' : 'Estandar'),
              const Divider(height: 1, indent: 56),
            ],
            if (role == UserRole.cooperativaAdmin) ...[
              _buildInfoTile(Icons.business_outlined, 'Rol', 'Admin Cooperativa'),
              const Divider(height: 1, indent: 56),
            ],
            if (role == UserRole.municipalAdmin) ...[
              _buildInfoTile(Icons.shield_outlined, 'Rol', 'Admin Municipal'),
              const Divider(height: 1, indent: 56),
            ],
            _buildInfoTile(Icons.phone_outlined, 'Telefono', 'No registrado'),
            const Divider(height: 1, indent: 56),
            _buildInfoTile(Icons.location_on_outlined, 'Ubicacion', 'Lima, Peru'),
          ],
        ]),
      ),
      const SizedBox(height: 16),
      Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 8)]),
        child: Column(children: [
          if (isUsuario) ...[
            _buildListItem(Icons.help_outline, 'Ayuda', const Color(0xFF001B44), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpPage()))),
            const Divider(height: 1, indent: 56),
          ],
          if (isConductor) ...[
            _buildListItem(Icons.warning_amber_outlined, 'Reportar incidente', const Color(0xFFBA1A1A), () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const IncidentReportPage()));
            }),
            const Divider(height: 1, indent: 56),
            _buildListItem(Icons.help_outline, 'Ayuda', const Color(0xFF001B44), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpPage()))),
            const Divider(height: 1, indent: 56),
          ],
          if (!isUsuario && !isConductor) ...[
            _buildListItem(Icons.warning_amber_outlined, 'Reportar incidente', const Color(0xFFBA1A1A), () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const IncidentReportPage(role: 'cooperativa')));
            }),
            const Divider(height: 1, indent: 56),
            _buildListItem(Icons.help_outline, 'Ayuda', const Color(0xFF001B44), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpPage()))),
            const Divider(height: 1, indent: 56),
          ],
          _buildListItem(Icons.description_outlined, 'Contrato de Confidencialidad', const Color(0xFF001B44), () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyAgreementPage()));
          }),
          const Divider(height: 1, indent: 56),
          ListTile(leading: const Icon(Icons.notifications_outlined, color: Color(0xFF001B44)), title: const Text('Notificaciones', style: TextStyle(fontFamily: 'Inter', color: Color(0xFF001B44))), trailing: Switch(value: notifs, activeColor: const Color(0xFF001B44), onChanged: (v) => ref.read(notifToggleProvider.notifier).state = v)),
        ]),
      ),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => ref.read(authNotifierProvider.notifier).logout(), icon: const Icon(Icons.logout, size: 18), label: const Text('Cerrar sesion'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFBA1A1A), side: const BorderSide(color: Color(0xFFBA1A1A)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
    ]);
  }

  Widget _buildAvatar(String? avatarUrl, String? fullName) {
    return Center(
      child: GestureDetector(
        onTap: _uploading ? null : _pickAndUploadImage,
        child: Stack(children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: const Color(0xFF001B44),
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? Text((fullName ?? '?')[0].toUpperCase(), style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.w600, fontFamily: 'Inter'))
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Color(0xFFFED000), shape: BoxShape.circle),
              child: _uploading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF001B44)))
                  : const Icon(Icons.camera_alt, size: 14, color: Color(0xFF001B44)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF001B44)),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF434750), fontFamily: 'Inter')),
      subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF001B44), fontFamily: 'Inter')),
    );
  }

  Widget _buildRoleBadge(UserRole? role, bool isPremium) {
    String text; Color color; IconData icon;
    if (isPremium) { text = 'Premium Member'; color = const Color(0xFFFED000); icon = Icons.workspace_premium; }
    else if (role == UserRole.conductor) { text = 'Conductor'; color = Colors.orange; icon = Icons.directions_bus; }
    else if (role == UserRole.cooperativaAdmin) { text = 'Admin Cooperativa'; color = const Color(0xFFFED000); icon = Icons.business; }
    else if (role == UserRole.municipalAdmin) { text = 'Admin Municipal'; color = Colors.purple; icon = Icons.shield; }
    else { text = 'Usuario'; color = Colors.grey; icon = Icons.person; }
    return Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: color), const SizedBox(width: 6), Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color, fontFamily: 'Inter'))])));
  }

  Widget _buildListItem(IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(leading: Icon(icon, color: color), title: Text(title, style: const TextStyle(fontFamily: 'Inter', color: Color(0xFF001B44))), trailing: const Icon(Icons.chevron_right, color: Color(0xFF434750)), onTap: onTap);
  }
}
