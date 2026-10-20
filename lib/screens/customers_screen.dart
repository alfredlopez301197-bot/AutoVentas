
import 'package:flutter/material.dart';

import '../services/google_sheets_service.dart';
import '../theme/app_theme.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() =>
      _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchController = TextEditingController();

  bool _checking = true;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    setState(() => _checking = true);

    final connected = await GoogleSheetsService.ping();

    if (!mounted) return;

    setState(() {
      _connected = connected;
      _checking = false;
    });
  }

  void _showPending() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'La lectura de clientes estará disponible '
          'cuando terminemos la conexión autenticada '
          'con Google Sheets.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          IconButton(
            tooltip: 'Actualizar conexión',
            onPressed: _checking ? null : _checkConnection,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _checkConnection,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (_checking)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    else
                      Icon(
                        _connected
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_off_rounded,
                        color: _connected
                            ? Colors.green
                            : Colors.orange,
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _checking
                            ? 'Comprobando conexión...'
                            : _connected
                                ? 'Google Sheets disponible. '
                                  'Consulta de clientes pendiente.'
                                : 'No se pudo confirmar la conexión '
                                  'con Google Sheets.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Buscar clientes',
                hintText: 'Tienda, propietario o ruta',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.groups_rounded,
                      size: 48,
                      color: AppColors.accent,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Directorio de clientes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Estamos preparando la lectura segura '
                      'de la hoja Clientes de Google Sheets.',
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Aquí aparecerán las tiendas, '
                      'propietarios, teléfonos, direcciones, '
                      'rutas, deudas y límites de crédito.',
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Todavía no se han cargado datos reales.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.midGray,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _showPending,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Nuevo cliente (próximamente)'),
            ),
          ],
        ),
      ),
    );
  }
}
