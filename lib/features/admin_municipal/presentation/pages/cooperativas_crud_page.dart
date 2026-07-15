import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/constants/app_roles.dart';
import '../../domain/entities/cooperativa_status.dart';
import '../providers/system_alerts_provider.dart';

class CooperativasCrudPage extends ConsumerStatefulWidget {
  const CooperativasCrudPage({super.key});
  @override
  ConsumerState<CooperativasCrudPage> createState() => _CooperativasCrudPageState();
}

class _CooperativasCrudPageState extends ConsumerState<CooperativasCrudPage> {
  late final TextEditingController _nombre, _ruc, _buses, _correo, _password;
  bool _estado = true;
  late String? _editingId;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(); _ruc = TextEditingController(); _buses = TextEditingController();
    _correo = TextEditingController(); _password = TextEditingController();
  }

  @override
  void dispose() {
    _nombre.dispose(); _ruc.dispose(); _buses.dispose(); _correo.dispose(); _password.dispose();
    super.dispose();
  }

  void _openCreate() {
    _nombre.clear(); _ruc.clear(); _buses.clear(); _correo.clear(); _password.clear();
    _estado = true;
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Nueva Cooperativa', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Color(0xFF001B44))),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _field(_nombre, 'Nombre'), const SizedBox(height: 10),
        _field(_ruc, 'RUC'), const SizedBox(height: 10),
        _field(_buses, 'Número de buses', keyboardType: TextInputType.number), const SizedBox(height: 10),
        _field(_correo, 'Correo', keyboardType: TextInputType.emailAddress), const SizedBox(height: 10),
        _field(_password, 'Contraseña', obscure: true),
        const SizedBox(height: 12),
        SwitchListTile(title: const Text('Activo', style: TextStyle(fontFamily: 'Inter')), value: _estado, onChanged: (v) => setState(() => _estado = v), dense: true, contentPadding: EdgeInsets.zero, activeColor: const Color(0xFF001B44)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () async {
          final fn = _nombre.text.trim();
          if (fn.isEmpty || _correo.text.trim().isEmpty || _ruc.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nombre, RUC y correo son requeridos'), backgroundColor: Color(0xFFBA1A1A)));
            return;
          }
          final repo = ref.read(networkMonitorRepositoryProvider);
          await repo.createCooperativa({
            'name': fn,
            'ruc': _ruc.text.trim(),
            'status': _estado ? 'active' : 'inactive',
          });
          if (!mounted) return;
          Navigator.pop(context);
          ref.invalidate(cooperativasStatusProvider);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cooperativa creada correctamente'), backgroundColor: Color(0xFF001B44)));
        }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF001B44), foregroundColor: Colors.white), child: const Text('Registrar')),
      ],
    ));
  }

  void _openEdit(CooperativaStatus c) {
    _editingId = c.id;
    _nombre.text = c.name;
    _ruc.text = c.ruc ?? '';
    _buses.text = '${c.totalBuses}';
    _estado = c.activeBuses > 0;
    _correo.clear(); _password.clear();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Editar Cooperativa', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Color(0xFF001B44))),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _field(_nombre, 'Nombre'), const SizedBox(height: 10),
        _field(_ruc, 'RUC'), const SizedBox(height: 10),
        _field(_buses, 'Número de buses', keyboardType: TextInputType.number), const SizedBox(height: 10),
        SwitchListTile(title: const Text('Activo', style: TextStyle(fontFamily: 'Inter')), value: _estado, onChanged: (v) => setState(() => _estado = v), dense: true, contentPadding: EdgeInsets.zero, activeColor: const Color(0xFF001B44)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () {
          if (_nombre.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nombre es requerido'), backgroundColor: Color(0xFFBA1A1A)));
            return;
          }
          Navigator.pop(context);
          ref.invalidate(cooperativasStatusProvider);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cooperativa actualizada'), backgroundColor: Color(0xFF001B44)));
        }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF001B44), foregroundColor: Colors.white), child: const Text('Guardar')),
      ],
    ));
  }

  void _confirmDelete(CooperativaStatus c) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Eliminar Cooperativa', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
      content: Text('¿Eliminar "${c.name}" permanentemente? Esta acción no se puede deshacer.', style: const TextStyle(fontFamily: 'Inter')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () {
          Navigator.pop(context);
          ref.invalidate(cooperativasStatusProvider);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${c.name} eliminada'), backgroundColor: const Color(0xFFBA1A1A)));
        }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBA1A1A), foregroundColor: Colors.white), child: const Text('Eliminar')),
      ],
    ));
  }

  Widget _field(TextEditingController ctrl, String label, {TextInputType keyboardType = TextInputType.text, bool obscure = false}) {
    return TextField(controller: ctrl, obscureText: obscure, keyboardType: keyboardType, decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(fontFamily: 'Inter'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE0E0E0))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF001B44))), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)));
  }

  @override
  Widget build(BuildContext context) {
    final coopStatus = ref.watch(cooperativasStatusProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Cooperativas', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Color(0xFF001B44))), backgroundColor: const Color(0xFFF8F9FA), elevation: 0),
      floatingActionButton: FloatingActionButton(onPressed: _openCreate, backgroundColor: const Color(0xFF001B44), child: const Icon(Icons.add, color: Colors.white)),
      body: coopStatus.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF001B44))),
        error: (_, __) => const Center(child: Text('Error al cargar')),
        data: (coops) => ListView.builder(padding: const EdgeInsets.all(16), itemCount: coops.length, prototypeItem: const SizedBox(height: 80), itemBuilder: (_, i) {
          final c = coops[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 4)]),
            child: Row(children: [
              CircleAvatar(radius: 28, backgroundColor: const Color(0xFF001B44), child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontFamily: 'Inter'))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
                const SizedBox(height: 2),
                Row(children: [Text(c.ruc ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF434750), fontFamily: 'Inter')), const SizedBox(width: 12), Text('Buses: ${c.activeBuses}/${c.totalBuses}', style: const TextStyle(fontSize: 13, color: Color(0xFF434750), fontFamily: 'Inter'))]),
                Row(children: [Text('${c.totalDrivers} conductores', style: const TextStyle(fontSize: 12, color: Color(0xFF434750), fontFamily: 'Inter')), const SizedBox(width: 12), Text('Ocup: ${c.averageOccupancy.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, color: Color(0xFF434750), fontFamily: 'Inter'))]),
              ])),
              Column(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: (c.activeBuses > 0 ? Colors.green : Colors.grey).withAlpha(20), borderRadius: BorderRadius.circular(8)), child: Text(c.activeBuses > 0 ? 'Activo' : 'Inactivo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, fontFamily: 'Inter', color: c.activeBuses > 0 ? Colors.green.shade700 : const Color(0xFF434750)))),
                const SizedBox(height: 6),
                Text('${c.fleetActivityPct.toStringAsFixed(0)}% activ.', style: const TextStyle(fontSize: 11, color: Color(0xFF434750), fontFamily: 'Inter')),
              ]),
              IconButton(icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF434750)), onPressed: () => _openEdit(c)),
              IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFBA1A1A)), onPressed: () => _confirmDelete(c)),
            ]),
          );
        }),
      ),
    );
  }
}
