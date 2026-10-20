
import 'package:flutter/material.dart';

import '../services/google_sheets_service.dart';
import '../theme/app_theme.dart';

class StockMovementScreen extends StatefulWidget {
  const StockMovementScreen({super.key});

  @override
  State<StockMovementScreen> createState() =>
      _StockMovementScreenState();
}

class _StockMovementScreenState
    extends State<StockMovementScreen> {
  bool _checking = true;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    setState(() {
      _checking = true;
    });

    final connected = await GoogleSheetsService.ping();

    if (!mounted) return;

    setState(() {
      _connected = connected;
      _checking = false;
    });
  }

  void _showPendingMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Esta función estará disponible cuando '
          'conectemos el inventario real de Google Sheets.',
        ),
      ),
    );
  }

  Widget _buildConnectionCard() {
    return Card(
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
                        ? 'API disponible. '
                          'Inventario pendiente de cargar.'
                        : 'No se pudo confirmar '
                          'la conexión con la API.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInformationCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.inventory_2_rounded,
              size: 52,
              color: AppColors.accent,
            ),
            SizedBox(height: 12),
            Text(
              'Inventario AutoVentas',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Esta pantalla se conectará con '
              'la hoja Productos de Google Sheets.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              'Aquí podrás consultar:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '• Código del producto\n'
              '• Nombre y categoría\n'
              '• Precio de venta\n'
              '• Existencias actuales',
              textAlign: TextAlign.left,
            ),
            SizedBox(height: 12),
            Text(
              'Todavía no se han cargado productos reales. '
              'No se mostrarán existencias inventadas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.midGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _showPendingMessage,
          icon: const Icon(Icons.search_rounded),
          label: const Text('Buscar producto'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _showPendingMessage,
          icon: const Icon(Icons.swap_vert_rounded),
          label: const Text('Movimientos de inventario'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _showPendingMessage,
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: const Text('Exportar inventario a PDF'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        title: const Text('Inventario'),
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
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            24,
          ),
          children: [
            _buildConnectionCard(),
            const SizedBox(height: 12),
            _buildInformationCard(),
            const SizedBox(height: 20),
            const Text(
              'Funciones de inventario',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildPendingActions(),
          ],
        ),
      ),
    );
  }
}
