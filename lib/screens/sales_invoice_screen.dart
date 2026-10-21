
import 'package:flutter/material.dart';

import '../services/google_sheets_service.dart';

class SalesInvoiceScreen extends StatefulWidget {
  const SalesInvoiceScreen({
    super.key,
    this.editDoc,
  });

  final Map<String, dynamic>? editDoc;

  @override
  State<SalesInvoiceScreen> createState() =>
      _SalesInvoiceScreenState();
}

class _Product {
  const _Product(this.name, this.price);

  final String name;
  final double price;
}

class _SaleDraft {
  const _SaleDraft({
    required this.operation,
    required this.route,
    required this.customer,
    required this.items,
    required this.total,
    required this.previousDebt,
    required this.cash,
    required this.transfer,
    required this.notes,
  });

  final String operation;
  final String route;
  final String customer;
  final Map<String, int> items;
  final double total;
  final double previousDebt;
  final double cash;
  final double transfer;
  final String notes;

  double get received => cash + transfer;

  double get remainingDebt =>
      (previousDebt + total - received)
          .clamp(0.0, double.infinity)
          .toDouble();
}

class _SalesInvoiceScreenState
    extends State<SalesInvoiceScreen> {
  static const _routes = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
  ];

  // DATOS FICTICIOS PARA PRUEBAS.
  // Después se sustituirán por los datos reales.
  static const Map<String, List<String>> _clients = {
    'Lunes': [
      'Tienda María',
      'Comercial López',
      'Minimarket Ana',
    ],
    'Martes': [
      'Tienda El Sol',
      'Comercial Pérez',
    ],
    'Miércoles': [
      'Tienda Central',
      'Minimarket Rosa',
    ],
    'Jueves': [
      'Tienda San José',
      'Comercial Norte',
    ],
    'Viernes': [
      'Tienda La Esquina',
      'Minimarket Sur',
    ],
    'Sábado': [
      'Tienda Esperanza',
    ],
  };

  static const _products = [
    _Product('Producto A', 2.50),
    _Product('Producto B', 3.00),
    _Product('Producto C', 1.75),
    _Product('Producto D', 4.50),
    _Product('Producto E', 2.25),
    _Product('Producto F', 5.00),
  ];

  // Saldos ficticios: NO son deudas reales.
  static const Map<String, double> _demoDebts = {
    'Tienda María': 30,
    'Comercial López': 15,
    'Tienda El Sol': 20,
  };

  final _searchController = TextEditingController();
  final _cashController = TextEditingController(text: '0');
  final _transferController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  final Map<String, int> _quantities = {};
  final List<_SaleDraft> _drafts = [];

  String _route = 'Lunes';
  String? _customer;
  String _operation = 'Venta de contado';
  String _search = '';

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
    _cashController.dispose();
    _transferController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    if (mounted) {
      setState(() => _checking = true);
    }

    try {
      final connected = await GoogleSheetsService.ping();

      if (!mounted) return;

      setState(() {
        _connected = connected;
        _checking = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _connected = false;
        _checking = false;
      });
    }
  }

  double _amount(String text) {
    return double.tryParse(
          text.trim().replaceAll(',', '.'),
        ) ??
        0;
  }

  double get _saleTotal {
    double total = 0;

    for (final product in _products) {
      total += product.price *
          (_quantities[product.name] ?? 0);
    }

    return total;
  }

  double get _previousDebt =>
      _demoDebts[_customer] ?? 0;

  double get _cash => _amount(_cashController.text);

  double get _transfer =>
      _amount(_transferController.text);

  double get _received => _cash + _transfer;

  double get _totalDue => _previousDebt + _saleTotal;

  double get _remainingDebt =>
      (_totalDue - _received)
          .clamp(0.0, double.infinity)
          .toDouble();

  void _changeQuantity(String name, int change) {
    setState(() {
      final current = _quantities[name] ?? 0;
      final next = current + change;

      if (next <= 0) {
        _quantities.remove(name);
      } else {
        _quantities[name] = next;
      }
    });
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _resetPayment() {
    _cashController.text = '0';
    _transferController.text = '0';
  }

  void _changeOperation(String? value) {
    if (value == null) return;

    setState(() {
      _operation = value;

      if (value == 'Abono de deuda') {
        _quantities.clear();
      } else if (value == 'Venta de contado') {
        _resetPayment();
      }
    });
  }

  void _saveDraft() {
    if (_customer == null) {
      _message('Selecciona la ruta y el cliente.');
      return;
    }

    if (_cash < 0 || _transfer < 0) {
      _message('Los pagos no pueden ser negativos.');
      return;
    }

    if (_operation == 'Abono de deuda') {
      if (_received <= 0) {
        _message('Ingresa el importe del abono.');
        return;
      }

      if (_received > _previousDebt) {
        _message(
          'El abono supera la deuda anterior '
          'de prueba.',
        );
        return;
      }
    } else {
      if (_quantities.isEmpty) {
        _message('Agrega al menos un producto.');
        return;
      }

      if (_operation == 'Venta de contado' &&
          _received < _saleTotal) {
        _message(
          'El pago debe cubrir el total de la venta. '
          'Selecciona venta a crédito si queda saldo.',
        );
        return;
      }

      if (_received > _totalDue + 0.001) {
        _message(
          'El pago supera la venta más la deuda '
          'anterior de prueba.',
        );
        return;
      }
    }

    final draft = _SaleDraft(
      operation: _operation,
      route: _route,
      customer: _customer!,
      items: Map<String, int>.from(_quantities),
      total: _saleTotal,
      previousDebt: _previousDebt,
      cash: _cash,
      transfer: _transfer,
      notes: _notesController.text.trim(),
    );

    setState(() {
      _drafts.insert(0, draft);
      _quantities.clear();
      _resetPayment();
      _notesController.clear();
      _operation = 'Venta de contado';
    });

    _message(
      'Borrador guardado en esta sesión. '
      'No se envió a Google Sheets.',
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 18,
        bottom: 10,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _moneyRow(
    String label,
    double value, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight:
                  bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 17 : 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableClients =
        _clients[_route] ?? <String>[];

    final filteredProducts = _products.where(
      (product) => product.name
          .toLowerCase()
          .contains(_search.toLowerCase()),
    );

    final isDebtPayment = _operation == 'Abono de deuda';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Autoventa rápida'),
        actions: [
          IconButton(
            tooltip: 'Comprobar conexión',
            onPressed:
                _checking ? null : _checkConnection,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                _checking
                    ? Icons.cloud_sync_rounded
                    : _connected
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded,
                color: _checking
                    ? Colors.blueGrey
                    : _connected
                        ? Colors.green
                        : Colors.orange,
              ),
              title: Text(
                _checking
                    ? 'Comprobando conexión…'
                    : _connected
                        ? 'Google Sheets responde'
                        : 'Conexión no confirmada',
              ),
              subtitle: const Text(
                'Modo de prueba. No se registran '
                'ventas, cobros ni facturas reales.',
              ),
            ),
          ),

          _sectionTitle('1. Ruta y cliente'),

          DropdownButtonFormField<String>(
            value: _route,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Ruta o día de visita',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final route in _routes)
                DropdownMenuItem(
                  value: route,
                  child: Text(route),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                _route = value;
                _customer = null;
                _quantities.clear();
                _resetPayment();
              });
            },
          ),

          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            key: ValueKey(_route),
            value: _customer,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Cliente de la ruta',
              border: OutlineInputBorder(),
            ),
            hint: const Text('Seleccionar cliente'),
            items: [
              for (final client in availableClients)
                DropdownMenuItem(
                  value: client,
                  child: Text(
                    client,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              setState(() {
                _customer = value;
                _quantities.clear();
                _resetPayment();
              });
            },
          ),

          if (_customer != null) ...[
            const SizedBox(height: 8),
            Card(
              color: Colors.amber.shade50,
              child: ListTile(
                leading: const Icon(
                  Icons.account_balance_wallet_outlined,
                ),
                title: Text(
                  'Deuda anterior de prueba: '
                  '\$${_previousDebt.toStringAsFixed(2)}',
                ),
                subtitle: const Text(
                  'Este saldo es ficticio y no proviene '
                  'de una cuenta real.',
                ),
              ),
            ),
          ],

          _sectionTitle('2. Tipo de operación'),

          DropdownButtonFormField<String>(
            value: _operation,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '¿Qué vas a registrar?',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'Venta de contado',
                child: Text('Venta de contado'),
              ),
              DropdownMenuItem(
                value: 'Venta a crédito',
                child: Text('Venta a crédito'),
              ),
              DropdownMenuItem(
                value: 'Abono de deuda',
                child: Text('Abono de deuda anterior'),
              ),
            ],
            onChanged: _changeOperation,
          ),

          if (!isDebtPayment) ...[
            _sectionTitle('3. Productos'),

            TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _search = value);
              },
              decoration: const InputDecoration(
                hintText: 'Buscar producto',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 8),

            for (final product in filteredProducts)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '\$${product.price.toStringAsFixed(2)} '
                              'por unidad',
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Quitar uno',
                        onPressed:
                            (_quantities[product.name] ?? 0) == 0
                                ? null
                                : () => _changeQuantity(
                                      product.name,
                                      -1,
                                    ),
                        icon: const Icon(
                          Icons.remove_circle_outline_rounded,
                        ),
                      ),
                      Text(
                        '${_quantities[product.name] ?? 0}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Agregar uno',
                        onPressed: () => _changeQuantity(
                          product.name,
                          1,
                        ),
                        icon: const Icon(
                          Icons.add_circle_rounded,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _moneyRow(
                  'Total de productos',
                  _saleTotal,
                  bold: true,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Card(
              child: ListTile(
                leading: Icon(Icons.payments_outlined),
                title: Text('Cobrar deuda anterior'),
                subtitle: Text(
                  'No se agregarán productos a este '
                  'borrador. Ingresa cuánto recibiste.',
                ),
              ),
            ),
          ],

          _sectionTitle(
            isDebtPayment ? '3. Registrar el abono' : '4. Forma de pago',
          ),

          const Text(
            'Puedes repartir el importe entre efectivo '
            'y transferencia. Los importes se calculan '
            'automáticamente.',
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cashController,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Efectivo',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _transferController,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Transferencia',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),

          _sectionTitle('5. Resumen de la operación'),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (isDebtPayment) ...[
                    _moneyRow(
                      'Deuda anterior',
                      _previousDebt,
                    ),
                    const Divider(),
                    _moneyRow(
                      'Abono recibido',
                      _received,
                    ),
                    const Divider(),
                    _moneyRow(
                      'Deuda restante estimada',
                      (_previousDebt - _received)
                          .clamp(0.0, double.infinity)
                          .toDouble(),
                      bold: true,
                    ),
                  ] else ...[
                    _moneyRow(
                      'Deuda anterior',
                      _previousDebt,
                    ),
                    _moneyRow(
                      'Venta de hoy',
                      _saleTotal,
                    ),
                    const Divider(),
                    _moneyRow(
                      'Total por cobrar',
                      _totalDue,
                      bold: true,
                    ),
                    _moneyRow('Efectivo recibido', _cash),
                    _moneyRow('Transferencia recibida', _transfer),
                    _moneyRow(
                      'Total recibido',
                      _received,
                      bold: true,
                    ),
                    const Divider(),
                    _moneyRow(
                      'Saldo pendiente estimado',
                      _remainingDebt,
                      bold: true,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const Card(
            child: ListTile(
              leading: Icon(Icons.receipt_long_rounded),
              title: Text('Factura pendiente de integración'),
              subtitle: Text(
                'El número definitivo se asignará al conectar '
                'el registro de ventas. Esta pantalla no '
                'emite facturas.',
              ),
            ),
          ),

          _sectionTitle('Observaciones'),

          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Notas de la venta o del cobro',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          FilledButton.icon(
            onPressed: _saveDraft,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar borrador de prueba'),
          ),

          const SizedBox(height: 12),

          const Text(
            'Los borradores solo existen mientras esta pantalla '
            'permanezca abierta. No modifican inventario, '
            'deudas, caja, facturas ni Google Sheets.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),

          _sectionTitle('Borradores de esta sesión'),

          if (_drafts.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.receipt_long_outlined),
                title: Text('Sin borradores'),
                subtitle: Text(
                  'Crea una venta o un abono para probar '
                  'el resumen.',
                ),
              ),
            ),

          for (final draft in _drafts)
            Card(
              child: ExpansionTile(
                leading: const Icon(
                  Icons.receipt_long_rounded,
                ),
                title: Text(draft.customer),
                subtitle: Text(
                  '${draft.operation} · ${draft.route}',
                ),
                children: [
                  if (draft.items.isNotEmpty)
                    for (final entry in draft.items.entries)
                      ListTile(
                        dense: true,
                        title: Text(entry.key),
                        trailing: Text(
                          '${entry.value} unidades',
                        ),
                      ),
                  ListTile(
                    title: const Text('Total de venta'),
                    trailing: Text(
                      '\$${draft.total.toStringAsFixed(2)}',
                    ),
                  ),
                  ListTile(
                    title: const Text('Efectivo'),
                    trailing: Text(
                      '\$${draft.cash.toStringAsFixed(2)}',
                    ),
                  ),
                  ListTile(
                    title: const Text('Transferencia'),
                    trailing: Text(
                      '\$${draft.transfer.toStringAsFixed(2)}',
                    ),
                  ),
                  ListTile(
                    title: const Text('Saldo pendiente estimado'),
                    trailing: Text(
                      '\$${draft.remainingDebt.toStringAsFixed(2)}',
                    ),
                  ),
                  if (draft.notes.isNotEmpty)
                    ListTile(
                      title: const Text('Observaciones'),
                      subtitle: Text(draft.notes),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
