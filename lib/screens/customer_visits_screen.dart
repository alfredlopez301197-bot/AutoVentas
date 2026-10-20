
import 'package:flutter/material.dart';

import '../services/google_sheets_service.dart';
import '../theme/app_theme.dart';

class CustomerVisitsScreen extends StatefulWidget {
  const CustomerVisitsScreen({super.key});

  @override
  State<CustomerVisitsScreen> createState() =>
      _CustomerVisitsScreenState();
}

class _CustomerVisitsScreenState
    extends State<CustomerVisitsScreen> {
  bool _checking = true;
  bool _connected = false;

  final List<_VisitDraft> _drafts = [];

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

  Future<void> _newVisit() async {
    final draft = await showModalBottomSheet<_VisitDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      builder: (context) => const _VisitForm(),
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

  String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        title: const Text('Ruta y Visitas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar conexión',
            onPressed: _checking ? null : _checkConnection,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newVisit,
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.accent,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Nueva visita'),
      ),
      body: RefreshIndicator(
        onRefresh: _checkConnection,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
                                ? 'API disponible. Guardado pendiente.'
                                : 'Sin conexión confirmada con la API.',
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
                  'Esta pantalla está en preparación. '
                  'Puedes crear borradores de visitas para '
                  'revisar el formulario, pero todavía no '
                  'se guardan en Google Sheets. '
                  'Los borradores se pierden al cerrar '
                  'esta pantalla o reiniciar la aplicación.',
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Visitas en preparación',
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
                (visit) => Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.storefront_rounded,
                      color: AppColors.accent,
                    ),
                    title: Text(visit.customerName),
                    subtitle: Text(
                      '${visit.type} · '
                      '${_formatDate(visit.createdAt)}'
                      '${visit.notes.isEmpty ? '' : '\n${visit.notes}'}',
                    ),
                    isThreeLine: visit.notes.isNotEmpty,
                    trailing: const Icon(
                      Icons.edit_note_rounded,
                      color: Colors.orange,
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

class _VisitDraft {
  const _VisitDraft({
    required this.customerName,
    required this.type,
    required this.notes,
    required this.createdAt,
  });

  final String customerName;
  final String type;
  final String notes;
  final DateTime createdAt;
}

class _VisitForm extends StatefulWidget {
  const _VisitForm();

  @override
  State<_VisitForm> createState() => _VisitFormState();
}

class _VisitFormState extends State<_VisitForm> {
  final _formKey = GlobalKey<FormState>();

  final _customerController = TextEditingController();
  final _notesController = TextEditingController();

  String _visitType = 'Visita';

  static const _visitTypes = [
    'Visita',
    'Cobro',
    'Preventa',
    'Entrega',
    'No encontrado',
    'Otro',
  ];

  @override
  void dispose() {
    _customerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _createDraft() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      _VisitDraft(
        customerName: _customerController.text.trim(),
        type: _visitType,
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
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nueva visita',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Borrador local: todavía no se enviará '
                  'a Google Sheets.',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _customerController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del cliente',
                    prefixIcon: Icon(Icons.storefront_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Escribe el nombre del cliente';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _visitType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de visita',
                    border: OutlineInputBorder(),
                  ),
                  items: _visitTypes
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _visitType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notas y observaciones',
                    hintText: '¿Qué ocurrió durante la visita?',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _createDraft,
                    icon: const Icon(Icons.note_add_rounded),
                    label: const Text('Crear borrador'),
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
