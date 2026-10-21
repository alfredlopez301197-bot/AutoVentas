
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/google_sheets_service.dart';
import 'sales_invoice_screen.dart';
import 'sales_order_screen.dart';

/// Pantalla principal de AutoVentas.
/// Ventas y Pedidos están habilitados en modo de prueba.
/// Los módulos pendientes no registran datos reales.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _checking = true;
  bool _connected = false;

  static const _modules = <_HomeModule>[
    _HomeModule(
      'Ventas',
      Icons.point_of_sale_rounded,
      'Autoventa rápida',
    ),
    _HomeModule(
      'Pedidos',
      Icons.shopping_cart_rounded,
      'Encargos de clientes',
    ),
    _HomeModule(
      'Deudas',
      Icons.request_quote_rounded,
      'Saldos pendientes',
    ),
    _HomeModule(
      'Cobros',
      Icons.payments_rounded,
      'Abonos y pagos',
    ),
    _HomeModule(
      'Clientes',
      Icons.groups_rounded,
      'Directorio de clientes',
    ),
    _HomeModule(
      'Inventario',
      Icons.inventory_2_rounded,
      'Existencias y movimientos',
    ),
    _HomeModule(
      'Rutas',
      Icons.route_rounded,
      'Visitas y recorridos',
    ),
    _HomeModule(
      'Gastos',
      Icons.receipt_long_rounded,
      'Gastos del día',
    ),
    _HomeModule(
      'Consumo',
      Icons.production_quantity_limits_rounded,
      'Consumo de productos',
    ),
    _HomeModule(
      'Kilometraje',
      Icons.speed_rounded,
      'Km inicial y final',
    ),
    _HomeModule(
      'Cuadre de caja',
      Icons.account_balance_wallet_rounded,
      'Cierre diario',
    ),
    _HomeModule(
      'Reportes',
      Icons.bar_chart_rounded,
      'Resumen de operaciones',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    if (mounted) {
      setState(() => _checking = true);
    }

    final ok = await GoogleSheetsService.ping();

    if (!mounted) return;

    setState(() {
      _connected = ok;
      _checking = false;
    });
  }

  void _showPending(String module) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$module: pendiente de conectar '
          'con Google Sheets.',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _openModule(_HomeModule module) {
    if (module.title == 'Ventas') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) =>
              const SalesInvoiceScreen(),
        ),
      );
      return;
    }

    if (module.title == 'Pedidos') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) =>
              const SalesOrderScreen(),
        ),
      );
      return;
    }

    _showPending(module.title);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AutoVentas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar conexión',
            onPressed:
                _checking ? null : _checkConnection,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Mi cuenta',
            onPressed: () => context.push('/account'),
            icon: const Icon(
              Icons.account_circle_outlined,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _checkConnection,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bienvenido a AutoVentas',
                      style:
                          theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ventas, clientes, rutas '
                      'e inventario en un solo lugar.',
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (_checking)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _checking
                                ? 'Comprobando conexión…'
                                : _connected
                                    ? 'Google Sheets disponible '
                                      '(prueba de conexión)'
                                    : 'Sin conexión confirmada '
                                      'con Google Sheets',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Módulos de AutoVentas',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Ventas y Pedidos están disponibles '
              'en modo de prueba. '
              'Los demás módulos se activarán '
              'progresivamente.',
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    constraints.maxWidth >= 600
                        ? 4
                        : 2;

                return GridView.builder(
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  itemCount: _modules.length,
                  gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.12,
                  ),
                  itemBuilder: (context, index) {
                    final module = _modules[index];

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () =>
                            _openModule(module),
                        child: Padding(
                          padding:
                              const EdgeInsets.all(10),
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(
                                module.icon,
                                size: 30,
                                color: theme
                                    .colorScheme.primary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                module.title,
                                textAlign:
                                    TextAlign.center,
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                module.subtitle,
                                textAlign:
                                    TextAlign.center,
                                maxLines: 2,
                                overflow:
                                    TextOverflow.ellipsis,
                                style: theme
                                    .textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Ventas: prueba la selección '
                  'de ruta y cliente, los botones '
                  '+ y −, el pago mixto y el '
                  'resumen de deuda.\n\n'
                  'Pedidos: crea borradores '
                  'de encargos.\n\n'
                  'Ninguno de estos módulos '
                  'registra operaciones reales '
                  'en Google Sheets todavía.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeModule {
  const _HomeModule(
    this.title,
    this.icon,
    this.subtitle,
  );

  final String title;
  final IconData icon;
  final String subtitle;
}
