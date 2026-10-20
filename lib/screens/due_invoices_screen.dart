
import 'package:flutter/material.dart';

import '../services/google_sheets_service.dart';
import '../theme/app_theme.dart';

class DueInvoicesScreen extends StatefulWidget {
  const DueInvoicesScreen({super.key});

  @override
  State<DueInvoicesScreen> createState() =>
      _DueInvoicesScreenState();
}

class _DueInvoicesScreenState
    extends State<DueInvoicesScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        title: const Text('Deudas de clientes'),
        actions: [
          IconButton(
            tooltip: 'Actualizar conexión',
            onPressed: _checking
                ? null
                : _checkConnection,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _checkConnection,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
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
                                ? 'API disponible. '
                                  'Consulta de deudas pendiente.'
                                : 'No se pudo confirmar '
                                  'la conexión con la API.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.black,
                borderRadius:
                    BorderRadius.circular(AppRadius.card),
              ),
              child: const Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total de deudas pendientes',
                    style: TextStyle(
                      color: AppColors.midGray,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Pendiente de cargar',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Todavía no hay datos de deudas '
                    'consultados desde Google Sheets.',
                    style: TextStyle(
                      color: AppColors.midGray,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Clientes con deudas',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 46,
                      color: AppColors.midGray,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Consulta de deudas en preparación',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Aquí aparecerán los clientes '
                      'con saldo pendiente, el monto '
                      'adeudado y sus movimientos.',
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No se muestran saldos de ERPNext '
                      'ni se inventan valores.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.midGray,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Buscar cliente',
                hintText:
                    'Disponible al conectar Google Sheets',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Card(
              child: ListTile(
                leading: Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.accent,
                ),
                title: Text('Vencimientos'),
                subtitle: Text(
                  'Las fechas de vencimiento '
                  'se habilitarán cuando exista '
                  'información confiable de las deudas.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
