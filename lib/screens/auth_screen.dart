import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/google_sheets_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _userController =
      TextEditingController();

  final TextEditingController _passController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final usuario = _userController.text.trim();
    final password = _passController.text;

    if (usuario.isEmpty || password.isEmpty) {
      _mostrarError('Ingresa tu usuario y contraseña.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await GoogleSheetsService.login(
        usuario: usuario,
        password: password,
      );

      if (!mounted) return;

      final nombre = (user['nombre'] ?? usuario).toString();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bienvenido, $nombre.'),
          backgroundColor: Colors.green,
        ),
      );

      context.go('/home');
    } catch (e) {
      if (!mounted) return;

      var mensaje = e.toString().replaceFirst('Exception: ', '');

      if (mensaje.contains('TimeoutException')) {
        mensaje = 'El servidor tardó demasiado. '
            'Comprueba tu conexión e inténtalo de nuevo.';
      }

      _mostrarError(mensaje);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _entrarModoPrueba() {
    // Solo permite visualizar la aplicación.
    // No crea una sesión autenticada.
    GoogleSheetsService.logout();
    context.go('/home');
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: Color(0xFFD4AF37),
                ),
                const SizedBox(height: 20),
                const Text(
                  'AutoVentas',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Acceso al sistema',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _userController,
                  enabled: !_isLoading,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passController,
                  enabled: !_isLoading,
                  obscureText: _obscurePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!_isLoading) _login();
                  },
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Ingresar',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed:
                        _isLoading ? null : _entrarModoPrueba,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text(
                      'Entrar en modo de prueba',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'El modo de prueba permite visualizar '
                  'la aplicación sin autenticar al usuario. '
                  'Las operaciones protegidas requieren '
                  'una sesión válida.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
