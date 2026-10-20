import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../widgets/loading_indicator.dart';

// ============================================================================
// ¡IMPORTANTE! PEGA AQUÍ TU ENLACE DE GOOGLE APPS SCRIPT
// (El mismo que usaste en auth_screen.dart, asegúrate de mantener las comillas)
// ============================================================================
const String scriptUrl = 'AQUI_TU_ENLACE_DE_APPS_SCRIPT';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _allCustomers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  bool _loading = true;
  String? _error;

  List<String> _availableTerritories = [];
  Set<String> _selectedTerritories = {};

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomers() async {
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
        
        // Extraer lista de clientes y rutas únicas
        final Set<String> rutas = {};
        final List<Map<String, dynamic>> clientesParseados = [];
        
        for (var c in clientesData) {
          final cliente = Map<String, dynamic>.from(c);
          clientesParseados.add(cliente);
          
          final ruta = cliente['Ruta']?.toString();
          if (ruta != null && ruta.isNotEmpty) {
            rutas.add(ruta);
          }
        }

        if (mounted) {
          setState(() {
            _allCustomers = clientesParseados;
            _availableTerritories = rutas.toList()..sort();
            _loading = false;
          });
          _search(_controller.text);
        }
      } else {
        throw Exception('El servidor no devolvió status: ok');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error de conexión: Verifica tu internet o el enlace del script.\n$e';
          _loading = false;
        });
      }
    }
  }

  void _search(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filteredCustomers = _allCustomers.where((c) {
        final nombre = (c['Nombre_Tienda'] ?? '').toString().toLowerCase();
        final propietario = (c['Propietario'] ?? '').toString().toLowerCase();
        final ruta = (c['Ruta'] ?? '').toString();

        // Filtro de texto
        final matchesText = q.isEmpty || nombre.contains(q) || propietario.contains(q);
        
        // Filtro de ruta
        final matchesRuta = _selectedTerritories.isEmpty || _selectedTerritories.contains(ruta);

        return matchesText && matchesRuta;
      }).toList();
    });
  }

  Future<void> _openTerritoryFilter() async {
    if (_availableTerritories.isEmpty) return;
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (context) {
        var localSelection = Set<String>.from(_selectedTerritories);
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filtrar por Ruta',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._availableTerritories.map(
                      (t) => CheckboxListTile(
                        value: localSelection.contains(t),
                        onChanged: (checked) {
                          setSheetState(() {
                            if (checked == true) {
                              localSelection.add(t);
                            } else {
                              localSelection.remove(t);
                            }
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.accent,
                        title: Text(t),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setSheetState(() => localSelection.clear()),
                            child: const Text('Limpiar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(localSelection),
                            child: const Text('Aplicar'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() => _selectedTerritories = result);
      _search(_controller.text);
    }
  }

  void _openCustomerActions(Map<String, dynamic> customer) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (sheetContext) {
        final limit = double.tryParse(customer['Limite_Credito']?.toString() ?? '0') ?? 0.0;
        final outstanding = double.tryParse(customer['Deuda_Actual']?.toString() ?? '0') ?? 0.0;
        final available = limit - outstanding;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer['Nombre_Tienda']?.toString() ?? 'Cliente',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.lightGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Límite de crédito: \$${limit.toStringAsFixed(2)}'),
                      Text('Deuda actual: \$${outstanding.toStringAsFixed(2)}'),
                      Text(
                        available >= 0
                            ? 'Crédito disponible: \$${available.toStringAsFixed(2)}'
                            : 'Cupo excedido: \$${(-available).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: available >= 0 ? AppColors.success : AppColors.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.storefront_rounded, color: AppColors.accent),
                  title: const Text('Visitar Cliente'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.push('/customer-visits');
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.receipt_long_outlined, color: AppColors.accent),
                  title: const Text('Estado de Cuenta / Cobros'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    // Redirigirá a la pantalla de estado de cuenta
                    context.push('/customer-statement/${customer['ID_Cliente']}');
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.badge_outlined, color: AppColors.accent),
                  title: const Text('Editar Información'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Edición de clientes en construcción')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        title: const Text('Directorio de Clientes'),
        actions: [
          if (_availableTerritories.length > 1)
            IconButton(
              icon: Icon(
                Icons.tune_rounded,
                color: _selectedTerritories.isNotEmpty ? AppColors.accent : null,
              ),
              onPressed: _openTerritoryFilter,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                controller: _controller,
                onChanged: _search,
                decoration: const InputDecoration(
                  hintText: 'Buscar tienda o propietario...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.accent,
                onRefresh: _fetchCustomers,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          Padding(padding: EdgeInsets.only(top: 80), child: LoadingIndicator()),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.accent),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    if (_filteredCustomers.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(
              child: Text(
                'No hay clientes registrados',
                style: TextStyle(color: AppColors.midGray),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _filteredCustomers.length,
      separatorBuilder: (context, i) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final customer = _filteredCustomers[i];
        final nombreTienda = customer['Nombre_Tienda']?.toString() ?? 'Sin Nombre';
        final propietario = customer['Propietario']?.toString() ?? '';
        final ruta = customer['Ruta']?.toString() ?? 'Sin Ruta';

        return Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: () => _openCustomerActions(customer),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.lightGray,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: AppColors.black,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombreTienda,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: AppColors.black,
                          ),
                        ),
                        if (propietario.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            propietario,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.midGray,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          ruta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded, // Se cambió de left a right (flecha correcta)
                    color: AppColors.midGray,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
