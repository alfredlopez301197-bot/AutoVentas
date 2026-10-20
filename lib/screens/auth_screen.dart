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
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;

  // PEGA AQUÍ TU LINK EXACTO DE APPS SCRIPT (MANTÉN LAS COMILLAS SIMPLES)
  final String scriptUrl = 'https://script.google.com/macros/s/AKfycbwCJoLUxBHrlJd7Rz4VTyiptxNmVJSUP77oYjR3om2rUHwovWxsuiulQfeefcTp4ZZZ/exec';

  Future<void> _login() async {
    setState(() => _isLoading = true);
    
    try {
      final url = Uri.parse('$scriptUrl?user=${_userController.text}&pass=${_passController.text}');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) context.go('/home');
        } else {
          _mostrarError('Usuario o contraseña incorrectos');
        }
      } else {
        _mostrarError('Error de conexión con el servidor');
      }
    } catch (e) {
      _mostrarError('Error: No se pudo conectar a la base de datos');
    }
    
    setState(() => _isLoading = false);
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Color(0xFFD4AF37)),
              const SizedBox(height: 20),
              const Text('Acceso Panda', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              TextField(
                controller: _userController,
                decoration: const InputDecoration(labelText: 'Usuario', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _login,
                        child: const Text('Ingresar', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
