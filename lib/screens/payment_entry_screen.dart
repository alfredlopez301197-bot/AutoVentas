
import 'package:flutter/material.dart';

import '../services/google_sheets_service.dart';
import '../theme/app_theme.dart';
import '../widgets/search_picker.dart';

class PaymentEntryScreen extends StatefulWidget {
  const PaymentEntryScreen({
    super.key,
    this.presetCustomer,
  });

  // Conservamos este parámetro para no romper
  // las rutas existentes de la aplicación.
  final PickedRecord? presetCustomer;

  @override
  State<PaymentEntryScreen> createState() =>
      _PaymentEntryScreenState();
}

class _PaymentEntryScreenState
    extends State<PaymentEntryScreen> {
  bool _checking = true;
  bool _connected = false;

  final List<_PaymentDraft> _drafts = [];

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

  Future<void> _newPayment() async {
    final draft = await showModalBottomSheet<_PaymentDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      builder: (context) => _PaymentForm(
        presetCustomer: widget.presetCustomer,
      ),
    );

    if (!mounted || draft == null) return;

    setState(() {
      _drafts.insert(0, draft);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Borrador creado. El cobro NO fue '
          'registrado en Google Sheets.',
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    String two(int number) =>
        number.toString().padLeft(2, '0');

    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        title: const Text('Cobros'),
        actions: [
          IconButton(
            tooltip: 'Actualizar conexión',
            onPressed: _checking ? null : _checkConnection,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newPayment,
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo cobro'),
      ),
      body: RefreshIndicator(
        onRefresh: _checkConnection,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            100,
          ),
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
                                  'Registro de cobros pendiente.'
                                : 'No se pudo confirmar '
                                  'la conexión con la API.',
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
                  'Los cobros reales estarán disponibles '
                  'cuando conectemos clientes, deudas '
                  'y sesiones seguras de Google Sheets.\n\n'
                  'Por ahora puedes probar el formulario '
                  'con borradores temporales.\n\n'
                  'Estos borradores NO descuentan deudas, '
                  'NO generan recibos oficiales y se '
                  'pierden al salir de esta pantalla.',
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Borradores de cobros',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_drafts.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Todavía no hay borradores de cobros.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              ..._drafts.map(
                (payment) => Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.payments_rounded,
                      color: AppColors.accent,
                    ),
                    title: Text(payment.customerName),
                    subtitle: Text(
                      'Recibo: ${payment.receiptNumber}\n'
                      '${payment.paymentMethod} · '
                      '${_formatDate(payment.createdAt)}'
                      '${payment.notes.isEmpty
                          ? ''
                          : '\n${payment.notes}'}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      '\$${payment.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PaymentDraft {
  const _PaymentDraft({
    required this.customerName,
    required this.receiptNumber,
    required this.paymentMethod,
    required this.amount,
    required this.notes,
    required this.createdAt,
  });

  final String customerName;
  final String receiptNumber;
  final String paymentMethod;
  final double amount;
  final String notes;
  final DateTime createdAt;
}

class _PaymentForm extends StatefulWidget {
  const _PaymentForm({
    this.presetCustomer,
  });

  final PickedRecord? presetCustomer;

  @override
  State<_PaymentForm> createState() =>
      _PaymentFormState();
}

class _PaymentFormState extends State<_PaymentForm> {
  final _formKey = GlobalKey<FormState>();

  final _customerController = TextEditingController();
  final _amountController = TextEditingController();
  final _receiptController = TextEditingController();
  final _notesController = TextEditingController();

  String _paymentMethod = 'Efectivo';

  @override
  void initState() {
    super.initState();

    final customer = widget.presetCustomer;

    if (customer != null) {
      _customerController.text = customer.label;
    }
  }

  @override
  void dispose() {
    _customerController.dispose();
    _amountController.dispose();
    _receiptController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _createDraft() {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    );

    if (amount == null ||
        !amount.isFinite ||
        amount <= 0) {
      return;
    }

    Navigator.of(context).pop(
      _PaymentDraft(
        customerName: _customerController.text.trim(),
        receiptNumber: _receiptController.text.trim(),
        paymentMethod: _paymentMethod,
        amount: amount,
        notes: _notesController.text.trim(),
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom:
            MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nuevo cobro',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Borrador de prueba. '
                  'No registra pagos reales.',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _customerController,
                  decoration: const InputDecoration(
                    labelText: 'Cliente',
                    hintText: 'Nombre del cliente',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Ingresa el nombre del cliente';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Monto cobrado',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final amount = double.tryParse(
                      (value ?? '')
                          .trim()
                          .replaceAll(',', '.'),
                    );

                    if (amount == null ||
                        !amount.isFinite ||
                        amount <= 0) {
                      return 'Ingresa un monto mayor que cero';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _receiptController,
                  decoration: const InputDecoration(
                    labelText: 'Número de recibo físico',
                    hintText: 'Ejemplo: 000125',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Ingresa el número de recibo';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Forma de pago',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Efectivo',
                      child: Text('Efectivo'),
                    ),
                    DropdownMenuItem(
                      value: 'Transferencia',
                      child: Text('Transferencia'),
                    ),
                    DropdownMenuItem(
                      value: 'Otro',
                      child: Text('Otro'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _paymentMethod = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _createDraft,
                    icon: const Icon(
                      Icons.note_add_rounded,
                    ),
                    label: const Text(
                      'Crear borrador de cobro',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
