
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

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

  static const String scriptUrl =
      'https://script.google.com/macros/s/'
      'AKfycbz6Dhi_ysLgfc6O1renR2FiIoinWJ6QyuM3n_t3vzuPE7HK1mnnb1P4V3N4q8Z-L1-v/exec';

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_userController.text.trim().isEmpty ||
        _passController.text.isEmpty) {
      _mostrarError('Ingresa tu usuario y contraseña');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // El inicio de sesión real necesita que Apps Script
      // tenga habilitada la acción "login" por POST.
      // No enviamos contraseñas en la URL.
      final response = await http
          .post(
            Uri.parse(scriptUrl),
            headers: const {
              'Content-Type': 'text/plain; charset=utf-8',
            },
            body: jsonEncode({
              'action': 'login',
              'usuario': _userController.text.trim(),
              'password': _passController.text,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode != 200) {
        _mostrarError('No se pudo conectar con el servidor');
        return;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        _mostrarError('Respuesta inválida del servidor');
        return;
      }

      if (decoded['success'] == true &&
          decoded['sesion'] is String &&
          (decoded['sesion'] as String).isNotEmpty) {
        // La integración de sesiones con el resto de
        // la aplicación todavía está pendiente.
        _mostrarError(
          'El servidor respondió, pero falta integrar '
          'la sesión segura en AutoVentas.',
        );
      } else {
        _mostrarError(
          'Inicio de sesión real todavía no disponible. '
          'Puedes usar el modo de prueba.',
        );
      }
    } catch (_) {
      if (mounted) {
        _mostrarError(
          'No se pudo iniciar sesión. '
          'Puedes usar el modo de prueba.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _entrarModoPrueba() {
    // Acceso de demostración, NO autenticación real.
    // No se crea una sesión ni se conceden permisos.
    context.go('/home');
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
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 25),
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFD4AF37),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
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
                  'Modo de prueba: acceso visual sin '
                  'autenticación. No se guardan ventas, '
                  'pedidos ni cobros reales.',
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
