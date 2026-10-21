import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../services/google_sheets_service.dart';
import '../theme/app_theme.dart';
// Pantallas conectadas:
import 'customer_statement_screen.dart'; 
import 'new_customer_screen.dart';
import 'sales_order_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _allCustomers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];

  Set<String> _selectedTerritories = {};
  List<String> _availableTerritories = [];

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final url = Uri.parse('${GoogleSheetsService.apiUrl}?action=sync');
      final request = await HttpClient().getUrl(url);
      final response = await request.close();
      final stringData = await response.transform(utf8.decoder).join();
      final data = jsonDecode(stringData);

      if (data['status'] == 'ok') {
        final List<dynamic> clientesData = data['clientes'] ?? [];
        
        // Obtenemos el usuario activo desde el servicio
        final currentUser = GoogleSheetsService.currentUser ?? {};
        final String miRuta = (currentUser['ruta'] ?? '').toString();
        final String miRol = (currentUser['rol'] ?? '').toString().toLowerCase();
        
        // Un Jefe o Administrador ve todo. El vendedor solo ve su ruta.
        final bool veTodo = miRol == 'jefe' || miRol == 'administrador' || miRuta.toLowerCase() == 'todas';

        final Set<String> rutas = {};
        final List<Map<String, dynamic>> clientesParseados = [];
        
        for (var c in clientesData) {
          final cliente = Map<String, dynamic>.from(c);
          final rutaCliente = cliente['Ruta']?.toString() ?? '';
          
          if (veTodo || rutaCliente == miRuta) {
            clientesParseados.add(cliente);
            if (rutaCliente.isNotEmpty) {
              rutas.add(rutaCliente);
            }
          }
        }

        if (mounted) {
          setState(() {
            _allCustomers = clientesParseados;
            _availableTerritories = rutas.toList()..sort();
            
            if (!veTodo && miRuta.isNotEmpty) {
              _selectedTerritories = {miRuta};
            }
            _loading = false;
          });
          _search('');
        }
      } else {
        throw Exception(data['mensaje'] ?? 'Error al descargar clientes');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error de conexión. Verifica tu internet.';
          _loading = false;
        });
      }
    }
  }

  void _search(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      _filteredCustomers = _allCustomers.where((c) {
        final matchRuta = _selectedTerritories.isEmpty || _selectedTerritories.contains(c['Ruta']);
        if (!matchRuta) return false;

        if (q.isEmpty) return true;

        final nombre = (c['Nombre_Tienda'] ?? '').toString().toLowerCase();
        final prop = (c['Propietario'] ?? '').toString().toLowerCase();
        final id = (c['ID_Cliente'] ?? '').toString().toLowerCase();

        return nombre.contains(q) || prop.contains(q) || id.contains(q);
      }).toList();
    });
  }

  void _abrirEstadoCuenta(Map<String, dynamic> cliente) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerStatementScreen(
          customer: cliente['ID_Cliente']?.toString() ?? '',
          customerLabel: cliente['Nombre_Tienda']?.toString() ?? 'Cliente',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isJefe = (GoogleSheetsService.currentUser?['rol'] ?? '').toString().toLowerCase() == 'jefe';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Directorio de Clientes'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _fetchCustomers,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // Buscador
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: InputDecoration(
                labelText: 'Buscar tienda o propietario...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          
          // Filtros de ruta (Solo visibles si hay más de una ruta disponible y es jefe)
          if (_availableTerritories.length > 1 && isJefe)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _availableTerritories.map((ruta) {
                    final isSelected = _selectedTerritories.contains(ruta);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(ruta),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedTerritories.add(ruta);
                            } else {
                              _selectedTerritories.remove(ruta);
                            }
                            _search(_searchController.text);
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // Lista de resultados
          Expanded(
            child: _buildList(),
          ),
        ],
      ),
      // BOTÓN FLOTANTE: NUEVO CLIENTE
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFD4AF37),
        child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        onPressed: () async {
          final creado = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewCustomerScreen()),
          );
          if (creado == true) {
            _fetchCustomers(); // Recarga la lista
          }
        },
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchCustomers,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              )
            ],
          ),
        ),
      );
    }

    if (_filteredCustomers.isEmpty) {
      return const Center(
        child: Text(
          'No se encontraron clientes en esta ruta.',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _filteredCustomers.length,
      itemBuilder: (context, index) {
        final c = _filteredCustomers[index];
        final nombre = c['Nombre_Tienda']?.toString() ?? 'Sin nombre';
        final prop = c['Propietario']?.toString() ?? 'Sin propietario';
        final ruta = c['Ruta']?.toString() ?? 'Sin ruta';
        final limite = c['Limite_Credito']?.toString() ?? '0.00';
        final deuda = c['Deuda_Actual']?.toString() ?? '0.00';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        nombre,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ruta,
                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Prop: $prop', style: TextStyle(color: Colors.grey[700])),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Límite: \$ $limite', style: const TextStyle(fontSize: 13)),
                    Text(
                      'Deuda: \$ $deuda',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _abrirEstadoCuenta(c),
                        icon: const Icon(Icons.receipt_long_rounded, size: 18),
                        label: const Text('Cobros', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: Colors.white,
                        ),
                        // BOTÓN VENDER: AHORA SÍ ABRE LA PANTALLA DE PEDIDOS
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SalesOrderScreen(
                                idCliente: c['ID_Cliente']?.toString() ?? '',
                                nombreCliente: c['Nombre_Tienda']?.toString() ?? '',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 18),
                        label: const Text('Vender', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
