
import 'package:flutter/material.dart';

import '../services/google_sheets_service.dart';
import '../theme/app_theme.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() =>
      _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  bool _checking = true;
  bool _connected = false;

  final List<_ExpenseDraft> _drafts = [];

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

  Future<void> _newExpense() async {
    final draft = await showModalBottomSheet<_ExpenseDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      builder: (context) => const _ExpenseForm(),
    );

    if (!mounted || draft == null) return;

    setState(() {
      _drafts.insert(0, draft);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Borrador creado. El gasto NO se guardó '
          'en Google Sheets.',
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    String two(int value) =>
        value.toString().padLeft(2, '0');

    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        title: const Text('Gastos'),
        actions: [
          IconButton(
            tooltip: 'Actualizar conexión',
            onPressed: _checking ? null : _checkConnection,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newExpense,
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo gasto'),
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
                                  'Registro de gastos pendiente.'
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
                  'Pantalla en preparación. Puedes probar '
                  'el formulario creando borradores, pero '
                  'todavía NO se registran gastos reales.\n\n'
                  'Los borradores se pierden al salir '
                  'de esta pantalla o reiniciar la aplicación.',
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Borradores de gastos',
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
                      'Todavía no has creado borradores.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              ..._drafts.map(
                (expense) => Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.accent,
                    ),
                    title: Text(expense.category),
                    subtitle: Text(
                      '${expense.type} · '
                      '${_formatDate(expense.createdAt)}'
                      '${expense.notes.isEmpty
                          ? ''
                          : '\n${expense.notes}'}',
                    ),
                    isThreeLine: expense.notes.isNotEmpty,
                    trailing: Text(
                      '\$${expense.amount.toStringAsFixed(2)}',
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

class _ExpenseDraft {
  const _ExpenseDraft({
    required this.type,
    required this.category,
    required this.amount,
    required this.notes,
    required this.createdAt,
  });

  final String type;
  final String category;
  final double amount;
  final String notes;
  final DateTime createdAt;
}

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm();

  @override
  State<_ExpenseForm> createState() =>
      _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String _type = 'Personal';
  String _category = 'Alimentación';

  static const _personalCategories = [
    'Alimentación',
    'Peajes',
    'Hospedaje',
    'Transporte',
    'Otros gastos personales',
  ];

  static const _vehicleCategories = [
    'Combustible',
    'Aceite',
    'Mantenimiento',
    'Otros gastos del vehículo',
  ];

  List<String> get _categories =>
      _type == 'Personal'
          ? _personalCategories
          : _vehicleCategories;

  @override
  void dispose() {
    _amountController.dispose();
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
      _ExpenseDraft(
        type: _type,
        category: _category,
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
                  'Nuevo gasto',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Borrador temporal. No se enviará '
                  'a Google Sheets.',
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de gasto',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Personal',
                      child: Text('Personal'),
                    ),
                    DropdownMenuItem(
                      value: 'Vehículo',
                      child: Text('Vehículo'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _type = value;
                      _category = _categories.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(_type),
                  value: _category,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories
                      .map(
                        (category) =>
                            DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _category = value);
                    }
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
                    labelText: 'Monto',
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
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones',
                    hintText: 'Detalle del gasto',
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
                      'Crear borrador',
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
