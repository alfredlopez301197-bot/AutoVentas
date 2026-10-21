import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/google_sheets_service.dart';

class NewCustomerScreen extends StatefulWidget {
  const NewCustomerScreen({super.key});

  @override
  State<NewCustomerScreen> createState() => _NewCustomerScreenState();
}

class _NewCustomerScreenState extends State<NewCustomerScreen> {
  final _tiendaController = TextEditingController();
  final _propietarioController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _limiteController = TextEditingController();
  
  String _diaVisita = 'Lunes';
  final List<String> _dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
  
  bool _isLoading = false;
  String _loadingMessage = '';

  Future<Position?> _obtenerUbicacion() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('El GPS está desactivado. Por favor, enciéndelo.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permiso de ubicación denegado.');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Los permisos de ubicación están bloqueados permanentemente.');
    } 

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _guardarCliente() async {
    final tienda = _tiendaController.text.trim();
    final propietario = _propietarioController.text.trim();
    final telefono = _telefonoController.text.trim();
    final direccion = _direccionController.text.trim();
    final limite = _limiteController.text.trim();

    if (tienda.isEmpty || propietario.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La tienda y el propietario son obligatorios'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Obteniendo coordenadas GPS...';
    });

    try {
      // 1. Capturar ubicación exacta
      final position = await _obtenerUbicacion();
      
      setState(() {
        _loadingMessage = 'Guardando en la base de datos...';
      });

      // 2. Preparar datos de sesión
      final currentUser = GoogleSheetsService.currentUser ?? {};
      final String miRol = (currentUser['rol'] ?? '').toString().toLowerCase();
      String rutaAsignada = (currentUser['ruta'] ?? '').toString();

      if (miRol == 'jefe' || miRol == 'administrador' || rutaAsignada == 'Todas') {
        rutaAsignada = 'General'; 
      }

      // 3. Enviar todo a Google Sheets
      await GoogleSheetsService.post(
        body: {
          'action': 'guardar_cliente',
          'nombreTienda': tienda,
          'propietario': propietario,
          'telefono': telefono,
          'direccion': direccion,
          'ruta': rutaAsignada,
          'limiteCredito': limite.isEmpty ? 0 : num.tryParse(limite) ?? 0,
          'diaVisita': _diaVisita,
          'latitud': position?.latitude ?? '',
          'longitud': position?.longitude ?? '',
        },
      );

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente guardado con GPS exitosamente'), backgroundColor: Colors.green),
      );
      
      Navigator.pop(context, true); 
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
                decoration: const InputDecoration(labelText: 'Nombre de la Tienda *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _propietarioController,
                enabled: !_isLoading,
                decoration: const InputDecoration(labelText: 'Nombre del Propietario *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _telefonoController,
                enabled: !_isLoading,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _direccionController,
                enabled: !_isLoading,
                keyboardType: TextInputType.streetAddress,
                decoration: const InputDecoration(labelText: 'Dirección Exacta', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _diaVisita,
                decoration: const InputDecoration(labelText: 'Día de Visita Asignado', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
                items: _dias.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: _isLoading ? null : (val) => setState(() => _diaVisita = val!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _limiteController,
                enabled: !_isLoading,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Límite de Crédito (\$) (Opcional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _guardarCliente,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.white),
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                            const SizedBox(width: 15),
                            Text(_loadingMessage, style: const TextStyle(fontSize: 16)),
                          ],
                        )
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
