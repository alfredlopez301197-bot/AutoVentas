import 'package:flutter/material.dart';
import '../services/google_sheets_service.dart';

class NewCustomerScreen extends StatefulWidget {
  const NewCustomerScreen({super.key});

  @override
  State<NewCustomerScreen> createState() => _NewCustomerScreenState();
}

class _NewCustomerScreenState extends State<NewCustomerScreen> {
  final _tiendaController = TextEditingController();
  final _propietarioController = TextEditingController();
  final _limiteController = TextEditingController();
  
  bool _isLoading = false;

  Future<void> _guardarCliente() async {
    final tienda = _tiendaController.text.trim();
    final propietario = _propietarioController.text.trim();
    final limite = _limiteController.text.trim();

    if (tienda.isEmpty || propietario.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La tienda y el propietario son obligatorios'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Tomamos la ruta del vendedor actual para asignársela al cliente automáticamente
      final currentUser = GoogleSheetsService.currentUser ?? {};
      final String miRol = (currentUser['rol'] ?? '').toString().toLowerCase();
      String rutaAsignada = (currentUser['ruta'] ?? '').toString();

      // Si es el jefe, por defecto lo mandamos a "Ruta General"
      if (miRol == 'jefe' || miRol == 'administrador' || rutaAsignada == 'Todas') {
        rutaAsignada = 'General'; 
      }

      await GoogleSheetsService.post(
        body: {
          'action': 'guardar_cliente',
          'nombreTienda': tienda,
          'propietario': propietario,
          'ruta': rutaAsignada,
          'limiteCredito': limite.isEmpty ? 0 : num.tryParse(limite) ?? 0,
        },
      );

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente guardado con éxito'), backgroundColor: Colors.green),
      );
      
      Navigator.pop(context, true); // Regresamos y avisamos que se guardó
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Cliente')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _tiendaController,
                enabled: !_isLoading,
                decoration: const InputDecoration(labelText: 'Nombre de la Tienda', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _propietarioController,
                enabled: !_isLoading,
                decoration: const InputDecoration(labelText: 'Nombre del Propietario', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _limiteController,
                enabled: !_isLoading,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Límite de Crédito (\$) (Opcional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _guardarCliente,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.white),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Guardar Cliente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
