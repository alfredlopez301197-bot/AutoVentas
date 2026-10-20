
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
    required this.route,
    required this.customer,
    required this.items,
    required this.saleTotal,
    required this.previousDebt,
    required this.cash,
    required this.transfer,
    required this.credit,
    required this.debtPayment,
    required this.notes,
  });

  final String route;
  final String customer;
  final Map<String, int> items;
  final double saleTotal;
  final double previousDebt;
  final double cash;
  final double transfer;
  final double credit;
  final double debtPayment;
  final String notes;

  double get remainingDebt =>
      previousDebt + saleTotal - cash - transfer;
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

  // DATOS FICTICIOS PARA PROBAR LA INTERFAZ.
  // Más adelante vendrán de Google Sheets.
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

  // Deudas de ejemplo, no saldos reales.
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
  String _saleType = 'Contado';
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
    setState(() => _checking = true);

    final connected = await GoogleSheetsService.ping();

    if (!mounted) return;

    setState(() {
      _connected = connected;
      _checking = false;
    });
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

  double get _newSalePaid {
    if (_saleType == 'Crédito') return 0;

    return _received < _saleTotal
        ? _received
        : _saleTotal;
  }

  double get _debtPayment {
    if (_saleType == 'Crédito') {
      return _received;
    }

    final excess = _received - _saleTotal;
    return excess > 0 ? excess : 0;
  }

  double get _newCredit {
    if (_saleType == 'Crédito') {
      return _saleTotal;
    }

    final pending = _saleTotal - _newSalePaid;
    return pending > 0 ? pending : 0;
  }

  double get _remainingDebt {
    final result = _previousDebt +
        _saleTotal -
        _received;

    return result > 0 ? result : 0;
  }

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

  void _saveDraft() {
    if (_customer == null) {
      _message('Selecciona un cliente.');
      return;
    }

    if (_quantities.isEmpty && _received <= 0) {
      _message(
        'Agrega productos o registra un cobro.',
      );
      return;
    }

    if (_cash < 0 || _transfer < 0) {
      _message('Los pagos no pueden ser negativos.');
      return;
    }

    if (_saleType == 'Contado' &&
        _saleTotal > 0 &&
        _received < _saleTotal) {
      _message(
        'Para contado, el pago debe cubrir '
        'la venta. Usa Crédito si queda saldo.',
      );
      return;
    }

    if (_received >
        _previousDebt + _saleTotal + 0.001) {
      _message(
        'El pago supera la venta más '
        'la deuda anterior.',
      );
      return;
    }

    final draft = _SaleDraft(
      route: _route,
      customer: _customer!,
      items: Map<String, int>.from(_quantities),
      saleTotal: _saleTotal,
      previousDebt: _previousDebt,
      cash: _cash,
      transfer: _transfer,
      credit: _newCredit,
      debtPayment: _debtPayment,
      notes: _notesController.text.trim(),
    );

    setState(() {
      _drafts.insert(0, draft);
      _quantities.clear();
      _cashController.text = '0';
      _transferController.text = '0';
      _notesController.clear();
      _saleType = 'Contado';
    });

    _message(
      'Borrador de prueba guardado solo '
      'en esta pantalla. No se envió '
      'a Google Sheets.',
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 16,
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
      padding: const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: bold
                  ? FontWeight.bold
                  : FontWeight.normal,
              fontSize: bold ? 18 : 14,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Autoventa rápida'),
        actions: [
          IconButton(
            tooltip: 'Comprobar conexión',
            onPressed:
                _checking ? null : _checkConnection,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          16, 12, 16, 32,
        ),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                _connected
                    ? Icons.cloud_done
                    : Icons.cloud_off,
                color: _connected
                    ? Colors.green
                    : Colors.orange,
              ),
              title: Text(
                _checking
                    ? 'Comprobando API...'
                    : _connected
                        ? 'Google Sheets disponible'
                        : 'Sin conexión confirmada',
              ),
              subtitle: const Text(
                'Modo de prueba: clientes, '
                'productos, precios y deudas '
                'son ficticios. No se guardan '
                'ventas reales.',
              ),
            ),
          ),

          _sectionTitle('1. Ruta y cliente'),

          DropdownButtonFormField<String>(
            value: _route,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Ruta o día',
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
                _cashController.text = '0';
                _transferController.text = '0';
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
            hint: const Text('Seleccionar tienda'),
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
                _cashController.text = '0';
                _transferController.text = '0';
              });
            },
          ),

          if (_customer != null)
            Card(
              color: Colors.amber.shade50,
              child: ListTile(
                leading:
                    const Icon(Icons.account_balance_wallet),
                title: Text(
                  'Deuda anterior de prueba: '
                  '\$${_previousDebt.toStringAsFixed(2)}',
                ),
                subtitle: const Text(
                  'En la versión real se consultará '
                  'el saldo del cliente.',
                ),
              ),
            ),

          _sectionTitle('2. Productos'),

          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() => _search = value);
            },
            decoration: const InputDecoration(
              hintText: 'Buscar producto',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 8),

          for (final product in filteredProducts)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 28,
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
                            '\$${product.price.toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Quitar uno',
                      onPressed:
                          (_quantities[product.name] ??
                                      0) ==
                                  0
                              ? null
                              : () => _changeQuantity(
                                    product.name,
                                    -1,
                                  ),
                      icon: const Icon(
                        Icons.remove_circle_outline,
                      ),
                    ),
                    Text(
                      '${_quantities[product.name] ?? 0}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Agregar uno',
                      onPressed: () =>
                          _changeQuantity(
                        product.name,
                        1,
                      ),
                      icon: const Icon(
                        Icons.add_circle,
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

          _sectionTitle('3. Venta y cobro'),

          DropdownButtonFormField<String>(
            value: _saleType,
            decoration: const InputDecoration(
              labelText: 'Tipo de venta',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'Contado',
                child: Text('Contado'),
              ),
              DropdownMenuItem(
                value: 'Crédito',
                child: Text('Crédito'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _saleType = value);
              }
            },
          ),

          const SizedBox(height: 12),

          const Text(
            'Ingresa cuánto recibiste por '
            'cada forma de pago. Puedes usar '
            'ambas para un pago mixto.',
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

          _sectionTitle('4. Resumen'),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
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
                    _previousDebt + _saleTotal,
                    bold: true,
                  ),
                  _moneyRow(
                    'Efectivo recibido',
                    _cash,
                  ),
                  _moneyRow(
                    'Transferencia recibida',
                    _transfer,
                  ),
                  _moneyRow(
                    'Total recibido',
                    _received,
                    bold: true,
                  ),
                  const Divider(),
                  _moneyRow(
                    'Saldo pendiente',
                    _remainingDebt,
                    bold: true,
                  ),
                ],
              ),
            ),
          ),

          const Card(
            child: ListTile(
              leading: Icon(Icons.receipt_long),
              title: Text('Factura automática'),
              subtitle: Text(
                'El número definitivo se '
                'generará al conectar el '
                'registro seguro de ventas. '
                'Esta prueba no emite facturas.',
              ),
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Observaciones',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          FilledButton.icon(
            onPressed: _saveDraft,
            icon: const Icon(Icons.save_outlined),
            label: const Text(
              'Guardar borrador de prueba',
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Este botón NO registra ventas, '
            'cobros, facturas ni movimientos '
            'de inventario. Los borradores '
            'se pierden al cerrar esta pantalla.',
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
                title: Text('Sin borradores'),
                subtitle: Text(
                  'Prueba la selección de ruta, '
                  'cliente y productos.',
                ),
              ),
            ),

          for (final draft in _drafts)
            Card(
              child: ExpansionTile(
                leading:
                    const Icon(Icons.receipt_long),
                title: Text(draft.customer),
                subtitle: Text(
                  '${draft.route} · '
                  'Venta \$${draft.saleTotal.toStringAsFixed(2)}',
                ),
                children: [
                  for (final entry
                      in draft.items.entries)
                    ListTile(
                      dense: true,
                      title: Text(entry.key),
                      trailing: Text(
                        '${entry.value} unidades',
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
                    title: const Text(
                      'Saldo pendiente estimado',
                    ),
                    trailing: Text(
                      '\$${draft.remainingDebt.toStringAsFixed(2)}',
                    ),
                  ),
                  if (draft.notes.isNotEmpty)
                    ListTile(
                      title: const Text('Notas'),
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
