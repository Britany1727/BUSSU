import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';
import 'recover_password_page.dart';
import 'register_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isAdminMode = false;

  late final AnimationController _animController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.loading;

    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.errorMessage != null &&
          previous?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF001B44), Color(0xFF001B44), Color(0xFFF8F9FA)],
            stops: [0.0, 0.42, 0.42],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideUp,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 20),
                      _buildLogo(),
                      const SizedBox(height: 36),
                      _buildCard(context, isLoading),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(children: [
      Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(25),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.directions_bus, size: 48, color: Colors.white),
      ),
      const SizedBox(height: 16),
      const Text('BUSSU',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Inter', letterSpacing: 2)),
      const SizedBox(height: 4),
      const Text('Transporte público inteligente',
          style: TextStyle(fontSize: 14, color: Colors.white70, fontFamily: 'Inter')),
    ]);
  }

  Widget _buildCard(BuildContext context, bool isLoading) {
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
            _buildRoleSelector(),
            const SizedBox(height: 24),
            _buildInput(
              controller: _emailController,
              icon: Icons.email_outlined,
              label: 'Correo electrónico',
              hint: _isAdminMode ? 'admin@bussu.app' : 'usuario@bussu.app',
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
              action: TextInputAction.done,
              validator: (v) => Validators.validatePassword(v),
              suffix: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF434750)),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              onSubmitted: (_) => _handleLogin(),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF001B44),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
                ),
                child: isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(_isAdminMode ? 'Acceder como administrador' : 'Iniciar Sesión'),
              ),
            ),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton(
                onPressed: _navigateToRegister,
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF434750)),
                child: const Text('Crear cuenta', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
              ),
              Container(width: 1, height: 16, color: const Color(0xFFE0E0E0)),
              TextButton(
                onPressed: _navigateToRecoverPassword,
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF434750)),
                child: const Text('Recuperar acceso', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
              ),
            ]),
            if (_isAdminMode)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFED000).withAlpha(25), borderRadius: BorderRadius.circular(10)),
                child: const Text('Usa: driver@ · coop@ · admin@ · premium@\n+ 12345678', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF001B44), fontFamily: 'Inter', fontWeight: FontWeight.w500)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(child: _RoleTab(label: 'Usuario', icon: Icons.person_outline, selected: !_isAdminMode, onTap: () => setState(() => _isAdminMode = false))),
        Expanded(child: _RoleTab(label: 'Administrativo', icon: Icons.admin_panel_settings_outlined, selected: _isAdminMode, onTap: () => setState(() => _isAdminMode = true))),
      ]),
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
    String? Function(String?)? validator,
    Widget? suffix,
    void Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: action,
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

  void _handleLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      ref.read(authNotifierProvider.notifier).login(
            _emailController.text.trim(),
            _passwordController.text,
          );
    }
  }

  void _navigateToRegister() {
    Navigator.of(context).push(MaterialPageRoute<RegisterPage>(builder: (_) => const RegisterPage()));
  }

  void _navigateToRecoverPassword() {
    Navigator.of(context).push(MaterialPageRoute<RecoverPasswordPage>(builder: (_) => const RecoverPasswordPage()));
  }
}

class _RoleTab extends StatelessWidget {
  final String label; final IconData icon; final bool selected; final VoidCallback onTap;
  const _RoleTab({required this.label, required this.icon, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF001B44) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: selected ? Colors.white : const Color(0xFF434750)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : const Color(0xFF434750), fontFamily: 'Inter')),
        ]),
      ),
    );
  }
}
