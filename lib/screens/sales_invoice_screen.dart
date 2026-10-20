
import 'package:flutter/material.dart';

import '../services/google_sheets_service.dart';
import '../theme/app_theme.dart';

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

class _SaleLine {
  _SaleLine({
    required this.product,
    required this.quantity,
    required this.price,
  });

  final String product;
  final double quantity;
  final double price;

  double get subtotal => quantity * price;
}

class _SaleDraft {
  _SaleDraft({
    required this.customer,
    required this.invoiceNumber,
    required this.paymentType,
    required this.lines,
    required this.notes,
    required this.createdAt,
  });

  final String customer;
  final String invoiceNumber;
  final String paymentType;
  final List<_SaleLine> lines;
  final String notes;
  final DateTime createdAt;

  double get total => lines.fold(
        0,
        (sum, line) => sum + line.subtotal,
      );
}

class _SalesInvoiceScreenState
    extends State<SalesInvoiceScreen> {
  bool _checking = true;
  bool _connected = false;

  final List<_SaleDraft> _drafts = [];

  @override
  void initState() {
    super.initState();
    _checkConnection();
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

  Future<void> _createDraft() async {
    final draft = await showModalBottomSheet<_SaleDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      builder: (context) => const _SaleForm(),
    );

    if (draft == null || !mounted) return;

    setState(() => _drafts.insert(0, draft));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Borrador creado. No se ha enviado '
          'a Google Sheets.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        title: Text(
          widget.editDoc == null
              ? 'Ventas'
              : 'Ventas - modo preparación',
        ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createDraft,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva venta'),
      ),
      body: RefreshIndicator(
        onRefresh: _checkConnection,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16, 16, 16, 100,
          ),
          children: [
            Card(
              child: ListTile(
                leading: _checking
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        _connected
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_off_rounded,
                        color: _connected
                            ? Colors.green
                            : Colors.orange,
                      ),
                title: Text(
                  _checking
                      ? 'Comprobando conexión...'
                      : _connected
                          ? 'API disponible'
                          : 'No se pudo confirmar '
                            'la conexión',
                ),
                subtitle: const Text(
                  'Las ventas reales todavía no '
                  'están conectadas a Google Sheets.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
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
                    'Ventas registradas',
                    style: TextStyle(
                      color: AppColors.midGray,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 8),
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
                    'No se están consultando '
                    'ventas reales ni totales '
                    'desde Google Sheets.',
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
              'Borradores de esta sesión',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Son pruebas locales temporales. '
              'Se perderán al cerrar o reiniciar '
              'esta pantalla y no afectan '
              'inventario, deudas ni caja.',
              style: TextStyle(
                color: AppColors.midGray,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            if (_drafts.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.point_of_sale_rounded,
                        size: 44,
                        color: AppColors.midGray,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Todavía no hay borradores',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Pulsa Nueva venta para '
                        'probar el formulario.',
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
                    leading: const Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.accent,
                    ),
                    title: Text(draft.customer),
                    subtitle: Text(
                      'Factura: ${draft.invoiceNumber}\n'
                      '${draft.paymentType} - '
                      'Borrador local',
                    ),
                    trailing: Text(
                      '\$${draft.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    children: [
                      for (final line in draft.lines)
                        ListTile(
                          dense: true,
                          title: Text(line.product),
                          subtitle: Text(
                            '${line.quantity} x '
                            '\$${line.price.toStringAsFixed(2)}',
                          ),
                          trailing: Text(
                            '\$${line.subtotal.toStringAsFixed(2)}',
                          ),
                        ),
                      if (draft.notes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Notas: ${draft.notes}',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.accent,
                ),
                title: Text(
                  'Registro real pendiente',
                ),
                subtitle: Text(
                  'Para registrar ventas reales '
                  'falta conectar clientes, '
                  'productos, precios, '
                  'autorización del vendedor '
                  'y validación del inventario.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleForm extends StatefulWidget {
  const _SaleForm();

  @override
  State<_SaleForm> createState() => _SaleFormState();
}

class _SaleFormState extends State<_SaleForm> {
  final _formKey = GlobalKey<FormState>();

  final _customerController =
      TextEditingController();

  final _invoiceController =
      TextEditingController();

  final _notesController =
      TextEditingController();

  final _productController =
      TextEditingController();

  final _quantityController =
      TextEditingController(text: '1');

  final _priceController =
      TextEditingController();

  String _paymentType = 'Contado';

  final List<_SaleLine> _lines = [];

  double get _total => _lines.fold(
        0,
        (sum, line) => sum + line.subtotal,
      );

  @override
  void dispose() {
    _customerController.dispose();
    _invoiceController.dispose();
    _notesController.dispose();
    _productController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _addProduct() {
    final product = _productController.text.trim();

    final quantity = double.tryParse(
      _quantityController.text
          .trim()
          .replaceAll(',', '.'),
    );

    final price = double.tryParse(
      _priceController.text
          .trim()
          .replaceAll(',', '.'),
    );

    if (product.isEmpty ||
        quantity == null ||
        quantity <= 0 ||
        price == null ||
        price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ingresa producto, cantidad '
            'y precio válidos.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _lines.add(
        _SaleLine(
          product: product,
          quantity: quantity,
          price: price,
        ),
      );

      _productController.clear();
      _quantityController.text = '1';
      _priceController.clear();
    });
  }

  void _saveDraft() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Agrega al menos un producto.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _SaleDraft(
        customer:
            _customerController.text.trim(),
        invoiceNumber:
            _invoiceController.text.trim(),
        paymentType: _paymentType,
        lines: List<_SaleLine>.from(_lines),
        notes: _notesController.text.trim(),
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context)
            .viewInsets
            .bottom,
      ),
      child: SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: 0.92,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Nueva venta de prueba',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Este formulario solo crea '
                  'un borrador temporal. '
                  'No registra ventas reales.',
                  style: TextStyle(
                    color: AppColors.midGray,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _customerController,
                  decoration:
                      const InputDecoration(
                    labelText: 'Cliente *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value == null ||
                              value.trim().isEmpty
                          ? 'Ingresa el cliente'
                          : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _invoiceController,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Número de factura física *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value == null ||
                              value.trim().isEmpty
                          ? 'Ingresa el número '
                            'de factura'
                          : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _paymentType,
                  decoration:
                      const InputDecoration(
                    labelText: 'Tipo de pago',
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
                      setState(
                        () => _paymentType = value,
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  'Productos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _productController,
                  decoration:
                      const InputDecoration(
                    labelText: 'Nombre del producto',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller:
                            _quantityController,
                        keyboardType:
                            const TextInputType
                                .numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(
                          labelText: 'Cantidad',
                          border:
                              OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller:
                            _priceController,
                        keyboardType:
                            const TextInputType
                                .numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(
                          labelText: 'Precio',
                          border:
                              OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _addProduct,
                  icon: const Icon(
                    Icons.add_rounded,
                  ),
                  label: const Text(
                    'Agregar producto',
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0;
                    i < _lines.length;
                    i++)
                  Card(
                    child: ListTile(
                      title: Text(
                        _lines[i].product,
                      ),
                      subtitle: Text(
                        '${_lines[i].quantity} x '
                        '\$${_lines[i].price.toStringAsFixed(2)}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Quitar producto',
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                        ),
                        onPressed: () {
                          setState(
                            () => _lines.removeAt(i),
                          );
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Total de prueba: '
                  '\$${_total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(
                    labelText: 'Observaciones',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saveDraft,
                  icon: const Icon(
                    Icons.save_outlined,
                  ),
                  label: const Text(
                    'Crear borrador de prueba',
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
