import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/search_picker.dart';
import '../widgets/swipe_to_confirm_button.dart';

// ============================================================================
// ¡IMPORTANTE! PEGA AQUÍ TU ENLACE DE GOOGLE APPS SCRIPT
// ============================================================================
const String scriptUrl = 'https://script.google.com/macros/s/AKfycbz6Dhi_ysLgfc6O1renR2FiIoinWJ6QyuM3n_t3vzuPE7HK1mnnb1P4V3N4q8Z-L1-v/exec';

class CustomerVisitsScreen extends StatefulWidget {
  const CustomerVisitsScreen({super.key});

  @override
  State<CustomerVisitsScreen> createState() => _CustomerVisitsScreenState();
}

class _CustomerVisitsScreenState extends State<CustomerVisitsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _clientes = [];

  // Simulador de visitas locales (hasta que agreguemos la pestaña al Excel)
  final List<Map<String, dynamic>> _visitasLocales = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (scriptUrl == 'AQUI_TU_ENLACE_DE_APPS_SCRIPT') {
        throw Exception('Falta colocar el enlace de Apps Script en el código');
      }

      final request = await HttpClient().getUrl(Uri.parse('$scriptUrl?action=sync'));
      final response = await request.close();
      final stringData = await response.transform(utf8.decoder).join();
      final data = jsonDecode(stringData);

      if (data['status'] == 'ok') {
        final List<dynamic> clientesData = data['clientes'] ?? [];
        if (mounted) {
          setState(() {
            _clientes = clientesData.map((e) => Map<String, dynamic>.from(e)).toList();
            _loading = false;
          });
        }
      } else {
        throw Exception('El servidor no respondió correctamente');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error de conexión: Verifica tu internet.\n$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _logVisit({PickedRecord? presetCustomer}) async {
    final result = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (context) => _LogVisitSheet(
        presetCustomer: presetCustomer,
        clientes: _clientes,
      ),
    );

    if (result is Map<String, dynamic>) {
      // Guardar la visita en la lista temporal de la pantalla
      setState(() {
        _visitasLocales.insert(0, result);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visita registrada exitosamente')),
      );
    } else if (result is PickedRecord) {
      if (!mounted) return;
      // Ir a pantalla de cobros
      context.push('/payment-entry', extra: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        title: const Text('Ruta y Visitas'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.black,
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(text: 'Mis Visitas'),
            Tab(text: 'Por Visitar'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _logVisit(),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.accent,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Registrar Visita'),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [_buildVisitsTab(), _buildOverdueTab()],
        ),
      ),
    );
  }

  Widget _buildVisitsTab() {
    if (_loading && _visitasLocales.isEmpty) return const LoadingIndicator();
    if (_error != null && _visitasLocales.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(color: AppColors.accent), textAlign: TextAlign.center),
        ),
      );
    }
    if (_visitasLocales.isEmpty) {
      return const Center(
        child: Text('No hay visitas registradas hoy', style: TextStyle(color: AppColors.midGray)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _visitasLocales.length,
      itemBuilder: (context, i) {
        final visit = _visitasLocales[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            children: [
              const Icon(Icons.storefront_rounded, color: AppColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visit['nombre'] ?? 'Cliente',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${visit['tipo']} - ${visit['hora']}',
                      style: const TextStyle(color: AppColors.midGray, fontSize: 11.5),
                    ),
                    if (visit['notas'] != null && visit['notas'].isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        visit['notas'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverdueTab() {
    if (_loading) return const LoadingIndicator();
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(color: AppColors.accent), textAlign: TextAlign.center),
        ),
      );
    }
    if (_clientes.isEmpty) {
      return const Center(
        child: Text('No hay clientes asignados a tu ruta', style: TextStyle(color: AppColors.midGray)),
      );
    }
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _fetchData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _clientes.length,
        itemBuilder: (context, i) {
          final customer = _clientes[i];
          final nombre = customer['Nombre_Tienda']?.toString() ?? 'Sin Nombre';
          final ruta = customer['Ruta']?.toString() ?? '';
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ruta.isNotEmpty ? ruta : 'Sin ruta asignada',
                        style: const TextStyle(color: AppColors.accent, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _logVisit(
                    presetCustomer: PickedRecord(name: customer['ID_Cliente']?.toString() ?? '', label: nombre),
                  ),
                  icon: const Icon(Icons.add_location_alt_rounded, size: 16),
                  label: const Text('Visitar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LogVisitSheet extends StatefulWidget {
  const _LogVisitSheet({this.presetCustomer, required this.clientes});

  final PickedRecord? presetCustomer;
  final List<Map<String, dynamic>> clientes;

  @override
  State<_LogVisitSheet> createState() => _LogVisitSheetState();
}

class _LogVisitSheetState extends State<_LogVisitSheet> {
  PickedRecord? _customer;
  String _visitType = 'Visita';
  final _notesController = TextEditingController();
  bool _submitting = false;
  String? _error;

  final List<String> _visitTypes = ['Visita', 'Cobro', 'Preventa', 'Entrega'];

  @override
  void initState() {
    super.initState();
    _customer = widget.presetCustomer;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomer() async {
    final result = await showSearchPicker(
      context: context,
      title: 'Seleccionar Cliente',
      hintText: 'Buscar por nombre o dueño...',
      search: (query) async {
        final q = query.toLowerCase();
        return widget.clientes.where((c) {
          final nombre = (c['Nombre_Tienda'] ?? '').toString().toLowerCase();
          final prop = (c['Propietario'] ?? '').toString().toLowerCase();
          return q.isEmpty || nombre.contains(q) || prop.contains(q);
        }).map((c) => PickedRecord(
          name: c['ID_Cliente']?.toString() ?? '',
          label: c['Nombre_Tienda']?.toString() ?? 'Sin Nombre',
          subtitle: c['Ruta']?.toString() ?? '',
        )).toList();
      },
    );
    if (result != null) setState(() => _customer = result);
  }

  void _goToCollection() {
    final customer = _customer;
    if (customer == null) return;
    Navigator.of(context).pop(customer);
  }

  Future<bool> _submit() async {
    if (_customer == null) return false;
    
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      bool gpsActivado = await Geolocator.isLocationServiceEnabled();
      if (!gpsActivado) {
        setState(() => _error = 'Debes encender el GPS para registrar la visita.');
        return false;
      }

      // Simulamos la demora de guardar en la base de datos
      await Future.delayed(const Duration(seconds: 1));
      
      final ahora = DateTime.now();
      final hora = '${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}';

      if (!mounted) return true;
      Navigator.of(context).pop({
        'id': _customer!.name,
        'nombre': _customer!.label,
        'tipo': _visitType,
        'notas': _notesController.text.trim(),
        'hora': hora,
      });
      return true;
    } catch (e) {
      setState(() => _error = 'Error al registrar visita: $e');
      return false;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Registrar Visita',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Material(
              color: AppColors.lightGray,
              borderRadius: BorderRadius.circular(AppRadius.field),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.field),
                onTap: widget.presetCustomer != null ? null : _pickCustomer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_rounded, color: AppColors.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _customer?.label ?? 'Seleccionar Cliente',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _customer == null ? AppColors.midGray : AppColors.black,
                          ),
                        ),
                      ),
                      if (widget.presetCustomer == null)
                        const Icon(Icons.chevron_right_rounded, color: AppColors.midGray),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Motivo de la Visita', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _visitTypes.map((type) {
                final selected = _visitType == type;
                return ChoiceChip(
                  label: Text(type),
                  selected: selected,
                  selectedColor: AppColors.accent,
                  labelStyle: TextStyle(
                    color: selected ? AppColors.white : AppColors.black,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (_) => setState(() {
                    _visitType = type;
                  }),
                );
              }).toList(),
            ),
            if (_visitType == 'Cobro') ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _customer == null ? null : _goToCollection,
                icon: const Icon(Icons.payments_rounded, size: 18),
                label: const Text('Ir a registrar un cobro monetario'),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Notas y observaciones (opcional)...'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.accent, fontSize: 12.5)),
            ],
            const SizedBox(height: 16),
            Opacity(
              opacity: (_customer == null || _submitting) ? 0.4 : 1,
              child: IgnorePointer(
                ignoring: _customer == null || _submitting,
                child: SwipeToConfirmButton(
                  label: 'Desliza para registrar visita',
                  confirmedLabel: '¡Guardado!',
                  onConfirmed: _submit,
                  wasQueued: () => false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
