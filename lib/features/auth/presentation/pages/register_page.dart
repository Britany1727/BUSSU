import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_roles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.loading;

    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.errorMessage != null &&
          previous?.errorMessage != next.errorMessage) {
        final isEmailPending = next.errorMessage!.contains('correo');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: isEmailPending ? const Color(0xFF001B44) : AppTheme.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 5),
          ),
        );
        if (isEmailPending) Navigator.of(context).pop();
      }
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF001B44), Color(0xFF001B44), Color(0xFFF8F9FA)],
            stops: [0.0, 0.35, 0.35],
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
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildCard(isLoading),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(25),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.person_add_outlined, size: 40, color: Colors.white),
      ),
      const SizedBox(height: 12),
      const Text('Crear Cuenta',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Inter')),
      const SizedBox(height: 4),
      const Text('Únete a BUSSU',
          style: TextStyle(fontSize: 14, color: Colors.white70, fontFamily: 'Inter')),
    ]);
  }

  Widget _buildCard(bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x1A002F6C), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInput(
              controller: _nameController,
              icon: Icons.person_outlined,
              label: 'Nombre completo',
              hint: 'Juan Pérez',
              keyboardType: TextInputType.name,
              action: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              validator: (v) => Validators.validateRequired(v, 'Nombre'),
            ),
            const SizedBox(height: 16),
            _buildInput(
              controller: _emailController,
              icon: Icons.email_outlined,
              label: 'Correo electrónico',
              hint: 'correo@ejemplo.com',
              keyboardType: TextInputType.emailAddress,
              action: TextInputAction.next,
              validator: Validators.validateEmail,
            ),
            const SizedBox(height: 16),
            _buildInput(
              controller: _passwordController,
              icon: Icons.lock_outlined,
              label: 'Contraseña',
              hint: '••••••••',
              obscure: _obscurePassword,
              action: TextInputAction.next,
              validator: (v) => Validators.validatePassword(v),
              suffix: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF434750)),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Mínimo 8 caracteres', style: TextStyle(fontSize: 11, color: Color(0xFF434750), fontFamily: 'Inter')),
            const SizedBox(height: 16),
            _buildInput(
              controller: _confirmPasswordController,
              icon: Icons.lock_outlined,
              label: 'Confirmar contraseña',
              hint: '••••••••',
              obscure: _obscureConfirm,
              action: TextInputAction.done,
              validator: (v) => Validators.validatePasswordMatch(_passwordController.text, v),
              suffix: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF434750)),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              onSubmitted: (_) => _handleRegister(),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF001B44),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
                ),
                child: isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Crear Cuenta'),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF434750)),
              child: const Text('¿Ya tienes cuenta? Iniciar sesión', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    String? hint,
    bool obscure = false,
    TextInputType? keyboardType,
    TextInputAction? action,
    TextCapitalization? textCapitalization,
    String? Function(String?)? validator,
    Widget? suffix,
    void Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: action,
      textCapitalization: textCapitalization ?? TextCapitalization.none,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 15, fontFamily: 'Inter', color: Color(0xFF001B44)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
        labelStyle: const TextStyle(color: Color(0xFF434750), fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF001B44), size: 22),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF001B44), width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFBA1A1A))),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  void _handleRegister() {
    if (_formKey.currentState?.validate() ?? false) {
      ref.read(authNotifierProvider.notifier).register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            confirmPassword: _confirmPasswordController.text,
            fullName: _nameController.text.trim(),
            role: UserRole.usuario,
          );
    }
  }
}
