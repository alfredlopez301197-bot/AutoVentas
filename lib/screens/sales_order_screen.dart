import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import '../services/google_sheets_service.dart';

class SalesOrderScreen extends StatefulWidget {
  final String idCliente;
  final String nombreCliente;

  const SalesOrderScreen({
    super.key,
    required this.idCliente,
    required this.nombreCliente,
  });

  @override
  State<SalesOrderScreen> createState() => _SalesOrderScreenState();
}

class _SalesOrderScreenState extends State<SalesOrderScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _productos = [];
  
  // Mapa para guardar las cantidades del carrito (ID_Producto -> Cantidad)
  final Map<String, int> _carrito = {};
  bool _guardando = false;
  String _tipoPago = 'Contado'; // Opciones: Contado o Credito

  @override
  void initState() {
    super.initState();
    _fetchProductos();
  }

  Future<void> _fetchProductos() async {
    try {
      final url = Uri.parse('${GoogleSheetsService.apiUrl}?action=productos');
      final request = await HttpClient().getUrl(url);
      final response = await request.close();
      final stringData = await response.transform(utf8.decoder).join();
      final data = jsonDecode(stringData);

      if (data['status'] == 'ok') {
        if (mounted) {
          setState(() {
            _productos = List<Map<String, dynamic>>.from(data['productos'] ?? []);
            _loading = false;
          });
        }
      } else {
        throw Exception(data['mensaje'] ?? 'Error al cargar productos');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error de conexión al cargar productos.';
          _loading = false;
        });
      }
    }
  }

  double get _totalVenta {
    double total = 0;
    for (var prod in _productos) {
      final id = prod['ID_Producto'].toString();
      final cantidad = _carrito[id] ?? 0;
      if (cantidad > 0) {
        final precio = double.tryParse(prod['Precio_Venta'].toString()) ?? 0.0;
        total += cantidad * precio;
      }
    }
    return total;
  }

  Future<void> _registrarVenta() async {
    if (_totalVenta <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agrega al menos un producto al carrito', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      return;
    }

    setState(() => _guardando = true);

    try {
      final currentUser = GoogleSheetsService.currentUser ?? {};
      final idVendedor = (currentUser['usuario'] ?? 'Desc').toString();

      final items = <Map<String, dynamic>>[];
      for (var prod in _productos) {
        final id = prod['ID_Producto'].toString();
        final cantidad = _carrito[id] ?? 0;
        if (cantidad > 0) {
          final precio = double.tryParse(prod['Precio_Venta'].toString()) ?? 0.0;
          items.add({
            'idProducto': id,
            'nombre': prod['Nombre']?.toString() ?? '',
            'cantidad': cantidad,
            'precio': precio,
            'subtotal': cantidad * precio,
          });
        }
      }

      await GoogleSheetsService.post(
        body: {
          'action': 'registrar_venta',
          'idVendedor': idVendedor,
          'idCliente': widget.idCliente,
          'tipoPago': _tipoPago,
          'subtotal': _totalVenta,
          'descuento': 0, // Puedes agregar un campo de descuento luego
          'total': _totalVenta,
          'items': items,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Venta registrada con éxito!'), backgroundColor: Colors.green));
      Navigator.pop(context); // Regresa a clientes
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Vender a: ${widget.nombreCliente}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    // Tipo de Pago
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tipo de pago:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          DropdownButton<String>(
                            value: _tipoPago,
                            items: ['Contado', 'Credito'].map((String val) {
                              return DropdownMenuItem<String>(value: val, child: Text(val));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _tipoPago = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Lista de Productos
                    Expanded(
                      child: ListView.builder(
                        itemCount: _productos.length,
                        itemBuilder: (context, index) {
                          final prod = _productos[index];
                          final id = prod['ID_Producto'].toString();
                          final nombre = prod['Nombre'].toString();
                          final precio = double.tryParse(prod['Precio_Venta'].toString()) ?? 0.0;
                          final cantidad = _carrito[id] ?? 0;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text('\$${precio.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                        onPressed: cantidad > 0 ? () => setState(() => _carrito[id] = cantidad - 1) : null,
                                      ),
                                      Text('$cantidad', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                                        onPressed: () => setState(() => _carrito[id] = cantidad + 1),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total a pagar', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text('\$${_totalVenta.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: _guardando || _totalVenta <= 0 ? null : _registrarVenta,
                icon: _guardando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_circle),
                label: Text(_guardando ? 'Guardando...' : 'Confirmar Venta', style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
