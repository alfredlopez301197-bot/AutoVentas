import 'package:flutter/material.dart';
import '../services/google_sheets_service.dart';

class CuadreScreen extends StatefulWidget {
  const CuadreScreen({super.key});

  @override
  State<CuadreScreen> createState() => _CuadreScreenState();
}

class _CuadreScreenState extends State<CuadreScreen> {
  final TextEditingController _efectivoController = TextEditingController();
  final TextEditingController _observacionesController = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _efectivoController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _enviarCuadre() async {
    final efectivoStr = _efectivoController.text.trim();
    if (efectivoStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa el monto de efectivo contado'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      final currentUser = GoogleSheetsService.currentUser ?? {};
      final idVendedor = (currentUser['usuario'] ?? 'Desc').toString();

      await GoogleSheetsService.post(
        body: {
          'action': 'registrar_cuadre',
          'idVendedor': idVendedor,
          'efectivoFisico': double.tryParse(efectivoStr) ?? 0.0,
          'observaciones': _observacionesController.text.trim(),
          'fecha': DateTime.now().toIso8601String(),
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Cierre y cuadre registrado con éxito!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar el cuadre: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuadre y Cierre Diario')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cierre de Caja y Mercadería',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ingresa el total de dinero físico recolectado en el día y reporta el sobrante de mercadería.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _efectivoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Dinero en efectivo físico (\$)',
                prefixIcon: const Icon(Icons.attach_money_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _observacionesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Productos sobrantes / Observaciones',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _enviando ? null : _enviarCuadre,
                child: _enviando
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Enviar Cuadre al Supervisor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
