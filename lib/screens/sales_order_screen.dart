
import 'package:flutter/material.dart';

import '../services/google_sheets_service.dart';

class SalesOrderScreen extends StatefulWidget {
  const SalesOrderScreen({super.key, this.editDoc});

  final Map<String, dynamic>? editDoc;

  @override
  State<SalesOrderScreen> createState() => _SalesOrderScreenState();
}

class _OrderLine {
  _OrderLine({
    required this.product,
    required this.quantity,
    required this.price,
  });

  final String product;
  final double quantity;
  final double price;

  double get total => quantity * price;
}

class _OrderDraft {
  _OrderDraft({
    required this.customer,
    required this.deliveryDate,
    required this.lines,
    required this.notes,
  });

  final String customer;
  final DateTime deliveryDate;
  final List<_OrderLine> lines;
  final String notes;

  double get total =>
      lines.fold(0.0, (sum, line) => sum + line.total);
}

class _SalesOrderScreenState extends State<SalesOrderScreen> {
  final List<_OrderDraft> _drafts = [];

  bool _checking = true;
  bool _apiAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    if (mounted) {
      setState(() => _checking = true);
    }

    final available = await GoogleSheetsService.ping();

    if (!mounted) return;

    setState(() {
      _apiAvailable = available;
      _checking = false;
    });
  }

  Future<void> _newOrder() async {
    if (widget.editDoc != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La edición de pedidos anteriores estará '
            'disponible cuando conectemos Google Sheets.',
          ),
        ),
      );
      return;
    }

    final draft = await showModalBottomSheet<_OrderDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _OrderForm(),
    );

    if (!mounted || draft == null) return;

    setState(() => _drafts.insert(0, draft));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Borrador creado. No se ha enviado a Google Sheets.',
        ),
      ),
    );
  }

  String _date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editDoc != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Editar pedido' : 'Pedidos'),
        actions: [
          IconButton(
            onPressed: _checking ? null : _checkConnection,
            icon: const Icon(Icons.refresh),
            tooltip: 'Comprobar conexión',
          ),
        ],
      ),
      floatingActionButton: editing
          ? null
          : FloatingActionButton.extended(
              onPressed: _newOrder,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo pedido'),
            ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _apiAvailable
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
                    color: _apiAvailable
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _checking
                          ? 'Comprobando conexión...'
                          : _apiAvailable
                              ? 'API disponible. El registro de '
                                  'pedidos todavía está pendiente.'
                              : 'No se pudo comprobar la conexión '
                                  'con Google Sheets.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Los pedidos creados aquí son borradores '
                'temporales. No se envían al servidor, '
                'no modifican inventario ni deudas y '
                'desaparecen al cerrar esta pantalla.',
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            editing
                ? 'Pedido anterior'
                : 'Borradores de pedidos',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (editing)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'La edición de pedidos existentes '
                  'está pendiente de conexión segura '
                  'con Google Sheets.',
                ),
              ),
            )
          else if (_drafts.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 52,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Todavía no hay borradores.',
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Pulsa "Nuevo pedido" para preparar uno.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ..._drafts.map(
              (draft) => Card(
                child: ExpansionTile(
                  title: Text(draft.customer),
                  subtitle: Text(
                    'Entrega: ${_date(draft.deliveryDate)}'
                    ' · Total estimado: '
                    '\$${draft.total.toStringAsFixed(2)}',
                  ),
                  children: [
                    for (final line in draft.lines)
                      ListTile(
                        title: Text(line.product),
                        subtitle: Text(
                          '${line.quantity} × '
                          '\$${line.price.toStringAsFixed(2)}',
                        ),
                        trailing: Text(
                          '\$${line.total.toStringAsFixed(2)}',
                        ),
                      ),
                    if (draft.notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Observaciones: ${draft.notes}',
                        ),
                      ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _drafts.remove(draft));
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Eliminar borrador'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 90),
        ],
      ),
    );
  }
}

class _OrderForm extends StatefulWidget {
  const _OrderForm();

  @override
  State<_OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends State<_OrderForm> {
  final _formKey = GlobalKey<FormState>();

  final _customerController = TextEditingController();
  final _productController = TextEditingController();
  final _quantityController =
      TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  final List<_OrderLine> _lines = [];

  DateTime _deliveryDate = DateTime.now();

  double get _total =>
      _lines.fold(0.0, (sum, line) => sum + line.total);

  @override
  void dispose() {
    _customerController.dispose();
    _productController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double? _number(String value) {
    return double.tryParse(
      value.trim().replaceAll(',', '.'),
    );
  }

  void _addProduct() {
    final product = _productController.text.trim();
    final quantity = _number(_quantityController.text);
    final price = _number(_priceController.text);

    if (product.isEmpty ||
        quantity == null ||
        quantity <= 0 ||
        price == null ||
        price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Escribe un producto, cantidad mayor que cero '
            'y precio válido.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _lines.add(
        _OrderLine(
          product: product,
          quantity: quantity,
          price: price,
        ),
      );
    });

    _productController.clear();
    _quantityController.text = '1';
    _priceController.clear();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _deliveryDate,
      firstDate: DateTime.now().subtract(
        const Duration(days: 1),
      ),
      lastDate: DateTime.now().add(
        const Duration(days: 365),
      ),
    );

    if (selected != null) {
      setState(() => _deliveryDate = selected);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Añade al menos un producto al pedido.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _OrderDraft(
        customer: _customerController.text.trim(),
        deliveryDate: _deliveryDate,
        lines: List<_OrderLine>.from(_lines),
        notes: _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Nuevo borrador de pedido',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Este formulario todavía no envía '
                'información a Google Sheets.',
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _customerController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del cliente',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Ingresa el cliente';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  'Fecha de entrega: '
                  '${_deliveryDate.day}/'
                  '${_deliveryDate.month}/'
                  '${_deliveryDate.year}',
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Productos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _productController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del producto',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantityController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Cantidad',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Precio unitario',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _addProduct,
                icon: const Icon(Icons.add),
                label: const Text('Añadir producto'),
              ),
              if (_lines.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (var i = 0; i < _lines.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_lines[i].product),
                    subtitle: Text(
                      '${_lines[i].quantity} × '
                      '\$${_lines[i].price.toStringAsFixed(2)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() => _lines.removeAt(i));
                      },
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total estimado: '
                    '\$${_total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observaciones',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text(
                  'Crear borrador de pedido',
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
