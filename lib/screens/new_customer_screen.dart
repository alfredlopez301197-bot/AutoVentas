import 'package:flutter/material.dart';
import '../services/google_sheets_service.dart';

class NewCustomerScreen extends StatefulWidget {
  const NewCustomerScreen({super.key});

  @override
  State<NewCustomerScreen> createState() => _NewCustomerScreenState();
}

class _NewCustomerScreenState extends State<NewCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _nombreTiendaController = TextEditingController();
  final TextEditingController _propietarioController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _limiteCreditoController = TextEditingController(text: '0.00');

  String _rutaSeleccionada = 'Ruta Norte'; // Valor por defecto o el de tu ruta actual
  String _diaVisitaSeleccionado = 'Lunes';
  
  bool _guardando = false;

  final List<String> _rutasDisponibles = ['Ruta Norte', 'Ruta Sur', 'Ruta Centro'];
  final List<String> _diasSemana = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

  @override
  void dispose() {
    _nombreTiendaController.dispose();
    _propietarioController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _limiteCreditoController.dispose();
    super.dispose();
  }

  Future<void> _guardarCliente() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      final currentUser = GoogleSheetsService.currentUser ?? {};
      final idVendedor = (currentUser['usuario'] ?? 'Desc').toString();

      // Generamos un ID de cliente basado en milisegundos o texto
      final idCliente = 'C${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      // Estructura de datos que se enviará al Apps Script de Google Sheets
      await GoogleSheetsService.post(
        body: {
          'action': 'registrar_cliente',
          'idVendedor': idVendedor,
          'idCliente': idCliente,
          'nombreTienda': _nombreTiendaController.text.trim(),
          'propietario': _propietarioController.text.trim(),
          'telefono': _telefonoController.text.trim(),
          'direccion': _direccionController.text.trim(),
          'ruta': _rutaSeleccionada,
          'limiteCredito': double.tryParse(_limiteCreditoController.text.trim()) ?? 0.0,
          'deudaActual': 0.0,
          'diaVisita': _diaVisitaSeleccionado,
          'latitud': 0.0, // Puedes integrar geolocator aquí si lo requieres
          'longitud': 0.0,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Cliente creado y guardado con éxito!'), backgroundColor: Colors.green),
      );
      
      // Retorna 'true' para indicar que se creó con éxito y recargar la lista anterior
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar cliente: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Nuevo Cliente')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nombreTiendaController,
              decoration: const InputDecoration(labelText: 'Nombre de la Tienda', border: OutlineInputBorder()),
              validator: (val) => val == null || val.isEmpty ? 'Ingresa el nombre de la tienda' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _propietarioController,
              decoration: const InputDecoration(labelText: 'Nombre del Propietario', border: OutlineInputBorder()),
              validator: (val) => val == null || val.isEmpty ? 'Ingresa el propietario' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _telefonoController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _direccionController,
              decoration: const InputDecoration(labelText: 'Dirección', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _rutaSeleccionada,
              decoration: const InputDecoration(labelText: 'Ruta', border: OutlineInputBorder()),
              items: _rutasDisponibles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (val) => setState(() => _rutaSeleccionada = val ?? _rutaSeleccionada),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _diaVisitaSeleccionado,
              decoration: const InputDecoration(labelText: 'Día de Visita', border: OutlineInputBorder()),
              items: _diasSemana.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (val) => setState(() => _diaVisitaSeleccionado = val ?? _diaVisitaSeleccionado),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _limiteCreditoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Límite de Crédito (\$)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.white,
              ),
              onPressed: _guardando ? null : _guardarCliente,
              child: _guardando
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Guardar Cliente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
