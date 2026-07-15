import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/constants/app_roles.dart';
import '../providers/fleet_provider.dart';

class CoopDriversPage extends ConsumerStatefulWidget {
  const CoopDriversPage({super.key});
  @override
  ConsumerState<CoopDriversPage> createState() => _CoopDriversPageState();
}

class _CoopDriversPageState extends ConsumerState<CoopDriversPage> {
  late final TextEditingController _cedula, _nombres, _apellidos, _telefono, _correo, _licencia, _placa, _password;
  String? _editId;

  @override
  void initState() {
    super.initState();
    _cedula = TextEditingController(); _nombres = TextEditingController(); _apellidos = TextEditingController();
    _telefono = TextEditingController(); _correo = TextEditingController(); _licencia = TextEditingController();
    _placa = TextEditingController(); _password = TextEditingController();
  }

  @override
  void dispose() {
    _cedula.dispose(); _nombres.dispose(); _apellidos.dispose(); _telefono.dispose();
    _correo.dispose(); _licencia.dispose(); _placa.dispose(); _password.dispose();
    super.dispose();
  }

  void _openForm({Map<String, String>? data}) {
    _editId = data?['id'];
    _cedula.text = data?['cedula'] ?? '';
    _nombres.text = data?['nombres'] ?? '';
    _apellidos.text = data?['apellidos'] ?? '';
    _telefono.text = data?['telefono'] ?? '';
    _correo.text = data?['correo'] ?? '';
    _licencia.text = data?['licencia'] ?? '';
    _placa.text = data?['placa'] ?? '';
    _password.clear();

    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text(_editId != null ? 'Editar Conductor' : 'Nuevo Conductor', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Color(0xFF001B44))),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _buildField(_cedula, 'Cédula', Icons.badge_outlined),
        const SizedBox(height: 10),
        _buildField(_nombres, 'Nombres', Icons.person_outline),
        const SizedBox(height: 10),
        _buildField(_apellidos, 'Apellidos', Icons.person_outline),
        const SizedBox(height: 10),
        _buildField(_telefono, 'Teléfono', Icons.phone_outlined, keyboardType: TextInputType.phone),
        const SizedBox(height: 10),
        _buildField(_correo, 'Correo', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 10),
        _buildField(_licencia, 'Licencia', Icons.credit_card_outlined),
        const SizedBox(height: 10),
        _buildField(_placa, 'Placa', Icons.directions_bus_outlined),
        if (_editId == null) ...[const SizedBox(height: 10), _buildField(_password, 'Contraseña', Icons.lock_outlined, obscure: true)],
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Color(0xFF434750)))),
        ElevatedButton(onPressed: () async {
          final fn = '${_nombres.text.trim()} ${_apellidos.text.trim()}';
          if (_correo.text.trim().isEmpty || _password.text.isEmpty || fn.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nombre, correo y contraseña son requeridos'), backgroundColor: Color(0xFFBA1A1A)));
            return;
          }
          final coopId = ref.read(currentCoopIdProvider);
          final repo = ref.read(fleetRepositoryProvider);
          await repo.createDriver(
            cooperativaId: coopId,
            email: _correo.text.trim(),
            password: _password.text,
            fullName: fn,
            licenseNumber: _licencia.text.trim().isNotEmpty ? _licencia.text.trim() : null,
          );
          if (!mounted) return;
          Navigator.pop(context);
          ref.invalidate(driversProvider(coopId));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conductor registrado correctamente'), backgroundColor: Color(0xFF001B44)));
        }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF001B44), foregroundColor: Colors.white), child: Text(_editId != null ? 'Guardar' : 'Registrar')),
      ],
    ));
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {TextInputType keyboardType = TextInputType.text, bool obscure = false}) {
    return TextField(controller: ctrl, obscureText: obscure, keyboardType: keyboardType, decoration: InputDecoration(
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF434750)),
      labelText: label, labelStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFF434750)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF001B44))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ));
  }

  void _confirmDelete(d) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Eliminar conductor', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
      content: Text('¿Eliminar a ${d.fullName} permanentemente?', style: const TextStyle(fontFamily: 'Inter')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () { Navigator.pop(context); ref.invalidate(driversProvider(ref.read(currentCoopIdProvider))); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${d.fullName} eliminado'), backgroundColor: const Color(0xFFBA1A1A))); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBA1A1A), foregroundColor: Colors.white), child: const Text('Eliminar')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final coopId = ref.watch(currentCoopIdProvider);
    final drivers = ref.watch(driversProvider(coopId));

    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 0), child: Row(children: [
        const Text('Conductores', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF001B44), fontFamily: 'Inter')),
        const Spacer(),
        ElevatedButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.add, size: 18), label: const Text('Nuevo'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF001B44), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12))),
      ])),
      const SizedBox(height: 12),
      Expanded(child: drivers.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF001B44))),
        error: (_, __) => const Center(child: Text('Error al cargar conductores')),
        data: (list) => ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: list.length,
          prototypeItem: const SizedBox(height: 80),
          itemBuilder: (_, i) {
            final d = list[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 4)]),
              child: Row(children: [
                CircleAvatar(radius: 24, backgroundColor: const Color(0xFF001B44), child: Text(d.fullName.isNotEmpty ? d.fullName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontFamily: 'Inter'))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.fullName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
                  const SizedBox(height: 2),
                  Text(d.email.isNotEmpty ? d.email : 'Sin correo', style: const TextStyle(fontSize: 13, color: Color(0xFF434750), fontFamily: 'Inter')),
                  Text('Lic: ${d.licenseNumber ?? '—'} · Bus: ${d.assignedBusPlate ?? '—'}', style: const TextStyle(fontSize: 12, color: Color(0xFF434750), fontFamily: 'Inter')),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: d.isActive ? Colors.green.withAlpha(20) : Colors.grey.withAlpha(30), borderRadius: BorderRadius.circular(8)), child: Text(d.isActive ? 'Activo' : 'Inactivo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, fontFamily: 'Inter', color: d.isActive ? Colors.green.shade700 : const Color(0xFF434750)))),
                const SizedBox(width: 4),
                IconButton(icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF434750)), onPressed: () => _openForm(data: {'id': d.id, 'nombres': d.fullName.split(' ').first, 'apellidos': d.fullName.split(' ').skip(1).join(' '), 'correo': d.email, 'licencia': d.licenseNumber ?? '', 'placa': d.assignedBusPlate ?? ''})),
                IconButton(icon: const Icon(Icons.location_on_outlined, size: 20, color: Color(0xFF001B44)), onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Conductor: ${d.fullName}'), backgroundColor: const Color(0xFF001B44)));
                }, tooltip: 'Ver ubicación'),
                IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFBA1A1A)), onPressed: () => _confirmDelete(d)),
              ]),
            );
          },
        ),
      )),
    ]);
  }
}
