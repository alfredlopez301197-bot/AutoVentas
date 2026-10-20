import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../local_db/sync_job_type.dart';
import '../services/cache_service.dart';
import '../services/erp_service.dart';
import '../services/sync_engine.dart';
import '../services/sync_status_service.dart';
import '../theme/app_theme.dart';
import '../utils/erp_error_handling.dart';
import '../utils/html_text.dart';
import '../widgets/log_visit_prompt.dart';
import '../widgets/search_picker.dart';
import '../widgets/swipe_to_confirm_button.dart';
import 'all_sales_orders_screen.dart';
import 'document_detail_screen.dart';

class _OrderLine {
  _OrderLine({required this.itemCode, required this.itemName});

  final String itemCode;
  final String itemName;
  double qty = 1;

  num? unitPrice;
  String? priceStatus;
  String? warehouse;
}

class SalesOrderScreen extends StatefulWidget {
  const SalesOrderScreen({super.key, this.editDoc});

  final Map<String, dynamic>? editDoc;

  @override
  State<SalesOrderScreen> createState() => _SalesOrderScreenState();
}

class _SalesOrderScreenState extends State<SalesOrderScreen>
    with SingleTickerProviderStateMixin {
  bool get _isEditing => widget.editDoc != null;

  late final TabController _tabController = TabController(
    length: _isEditing ? 1 : 2,
    vsync: this,
  );

  PickedRecord? _customer;
  final List<_OrderLine> _lines = [];

  String? _priceList;
  num? _creditLimit;
  num? _currentOutstanding;
  DateTime? _deliveryDate;
  PickedRecord? _paymentTerms;
  PickedRecord? _termsTemplate;
  bool _loadingTermsText = false;

  final _termsController = TextEditingController();
  List<Map<String, dynamic>> _paymentScheduleTerms = [];
  bool _loadingPaymentSchedule = false;

  String? _creditLimitStatus;
  String? _priceListStatus;
  String? _paymentScheduleStatus;
  String? _outstandingStatus;
  String? _locationStatus;

  Future<void> Function()? _locationFix;

  bool _loadingPartyDetails = false;
  bool _submitting = false;
  bool _lastSubmitWasQueued = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });

    final editDoc = widget.editDoc;
    if (editDoc != null) _prefillFromExistingDoc(editDoc);
  }

  void _prefillFromExistingDoc(Map<String, dynamic> doc) {
    final customerName = doc['customer'] as String?;
    if (customerName != null) {
      unawaited(
        _loadCustomerDetails(
          PickedRecord(
            name: customerName,
            label: (doc['customer_name'] as String?) ?? customerName,
          ),
        ),
      );
    }

    final items = doc['items'];
    if (items is List) {
      for (final raw in items.whereType<Map>()) {
        final itemCode = raw['item_code']?.toString();
        if (itemCode == null) continue;
        final line =
            _OrderLine(
                itemCode: itemCode,
                itemName: (raw['item_name'] as String?) ?? itemCode,
              )
              ..qty = (raw['qty'] as num?)?.toDouble() ?? 1
              ..unitPrice = raw['rate'] as num?
              ..warehouse = raw['warehouse'] as String?;
        _lines.add(line);
      }
    }

    final deliveryDate = doc['delivery_date'] as String?;
    if (deliveryDate != null) {
      _deliveryDate = DateTime.tryParse(deliveryDate);
    }

    final paymentTermsTemplate = doc['payment_terms_template'] as String?;
    if (paymentTermsTemplate != null) {
      _paymentTerms = PickedRecord(
        name: paymentTermsTemplate,
        label: paymentTermsTemplate,
      );
    }

    final termsTemplate = doc['tc_name'] as String?;
    if (termsTemplate != null) {
      _termsTemplate = PickedRecord(name: termsTemplate, label: termsTemplate);
    }
    final terms = doc['terms'] as String?;
    if (terms != null) _termsController.text = stripHtml(terms);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomer() async {
    List<String> territories;
    try {
      territories = await ErpService.getExpandedUserTerritories();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron obtener tus rutas. Verifica tu conexión a internet.'),
        ),
      );
      return;
    }
    if (!mounted) return;
    String? territoryFilter;

    final result = await showSearchPicker(
      context: context,
      title: 'Seleccionar Cliente',
      hintText: 'Buscar por nombre del cliente...',
      search: (query) async {
        final filters = <List<dynamic>>[
          if (query.isNotEmpty) ['customer_name', 'like', '%$query%'],
          if (territoryFilter != null)
            ['territory', '=', territoryFilter]
          else if (territories.length == 1)
            ['territory', '=', territories.first]
          else if (territories.isNotEmpty)
            ['territory', 'in', territories],
        ];

        final list = await CacheService.getSearchListCached(
          cacheDoctype: 'Customer_master',
          fetch: () => ErpService.getList(
            'Customer',
            filters: filters.isEmpty ? null : filters,
            fields: const [
              'name',
              'customer_name',
              'territory',
              'disabled',
              'is_frozen',
            ],
            limit: 20,
          ),
          searchFilter: (row) {
            final name = (row['name'] ?? '').toString().toLowerCase();
            final customerName = (row['customer_name'] ?? '')
                .toString()
                .toLowerCase();
            final terr = (row['territory'] ?? '').toString();
            final q = query.toLowerCase();
            if (q.isNotEmpty &&
                !name.contains(q) &&
                !customerName.contains(q)) {
              return false;
            }
            if (territoryFilter != null && terr != territoryFilter) {
              return false;
            }
            if (territoryFilter == null &&
                territories.length == 1 &&
                terr != territories.first) {
              return false;
            }
            if (territoryFilter == null &&
                territories.isNotEmpty &&
                territories.length > 1 &&
                !territories.contains(terr)) {
              return false;
            }
            return true;
          },
        );
        return list
            .map(
              (c) => PickedRecord(
                name: c['name'] as String,
                label: (c['customer_name'] as String?) ?? c['name'] as String,
                subtitle: ErpService.customerPickerSubtitle(
                  c,
                  prefix: c['territory'] as String?,
                ),
                enabled: ErpService.isCustomerSelectable(c),
              ),
            )
            .toList();
      },
      actionsBuilder: territories.length <= 1
          ? null
          : (pickerContext, refresh) => [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: territoryFilter == null
                    ? 'Filtrar por Ruta'
                    : 'Ruta: $territoryFilter',
                onPressed: () async {
                  final picked = await showSearchPicker(
                    context: pickerContext,
                    title: 'Seleccionar Ruta',
                    search: (q) async => territories
                        .where(
                          (t) =>
                              q.isEmpty ||
                              t.toLowerCase().contains(q.toLowerCase()),
                        )
                        .map((t) => PickedRecord(name: t, label: t))
                        .toList(),
                  );
                  if (picked == null) return;
                  territoryFilter = picked.name;
                  refresh();
                },
              ),
            ],
    );

    if (result == null) return;
    await _loadCustomerDetails(result);
  }

  Future<void> _loadCustomerDetails(PickedRecord result) async {
    setState(() {
      _customer = result;
      _priceList = null;
      _creditLimit = null;
      _creditLimitStatus = null;
      _priceListStatus = null;
      _currentOutstanding = null;
      _outstandingStatus = null;
      _loadingPartyDetails = true;
      _error = null;
    });

    try {
      final customerDoc = await ErpService.getDoc('Customer', result.name);
      if (customerDoc.isEmpty) {
        _creditLimitStatus = 'No se pudieron obtener los datos del cliente del servidor';
        _priceListStatus = _creditLimitStatus;
      } else {
        final creditLimitRows = customerDoc['credit_limits'];
        if (creditLimitRows is List && creditLimitRows.isNotEmpty) {
          final rows = creditLimitRows
              .whereType<Map>()
              .map((r) => Map<String, dynamic>.from(r))
              .toList();
          final company = await ErpService.resolveDefaultCompany();
          Map<String, dynamic>? matchedRow;
          if (company != null) {
            for (final row in rows) {
              if (row['company'] == company) {
                matchedRow = row;
                break;
              }
            }
          }
          matchedRow ??= rows.first;
          final limit = matchedRow['credit_limit'] as num?;
          if (limit == null || limit == 0) {
            _creditLimitStatus =
                'El límite de crédito para este cliente es cero o está vacío';
          } else {
            _creditLimit = limit;
          }
        } else if (creditLimitRows is List) {
          _creditLimitStatus =
              'No hay límite de crédito registrado para este cliente';
        } else {
          _creditLimitStatus =
              'No tienes permiso para ver el límite de crédito';
        }

        _priceList = customerDoc['default_price_list'] as String?;
        if (_priceList == null || _priceList!.isEmpty) {
          _priceList = await ErpService.getSellingSettingsPriceList();
        }
        if (_priceList == null) {
          _priceListStatus =
              'El cliente no tiene una lista de precios predeterminada';
        }
      }
    } catch (e) {
      _creditLimitStatus = 'Error de conexión al obtener datos del cliente: $e';
      _priceListStatus = _creditLimitStatus;
    }

    final outstanding = await _fetchCurrentOutstanding(result.name);
    if (outstanding == null) {
      _outstandingStatus = 'No se pudo obtener la deuda actual de este cliente';
    } else {
      _currentOutstanding = outstanding;
    }

    if (mounted) setState(() => _loadingPartyDetails = false);
  }

  Future<void> _addItem() async {
    final result = await showSearchPicker(
      context: context,
      title: 'Seleccionar Producto',
      hintText: 'Buscar por nombre del producto...',
      search: (query) async {
        final list = await CacheService.getSearchListCached(
          cacheDoctype: 'Item_master',
          fetch: () => ErpService.getList(
            'Item',
            filters: query.isEmpty
                ? null
                : [
                    ['item_name', 'like', '%$query%'],
                  ],
            fields: const ['name', 'item_name'],
            limit: 20,
          ),
          searchFilter: (row) {
            final name = (row['name'] ?? '').toString().toLowerCase();
            final itemName = (row['item_name'] ?? '').toString().toLowerCase();
            final q = query.toLowerCase();
            if (q.isNotEmpty && !name.contains(q) && !itemName.contains(q)) {
              return false;
            }
            return true;
          },
        );
        return list
            .map(
              (i) => PickedRecord(
                name: i['name'] as String,
                label: (i['item_name'] as String?) ?? i['name'] as String,
              ),
            )
            .toList();
      },
    );

    if (result == null) return;

    final line = _OrderLine(itemCode: result.name, itemName: result.label);
    setState(() => _lines.add(line));
    await _fetchPriceForLine(line);
  }

  Future<void> _fetchPriceForLine(_OrderLine line) async {
    final priceList = _priceList;
    if (priceList == null) {
      setState(
        () =>
            line.priceStatus = _priceListStatus ?? 'No hay una lista de precios seleccionada',
      );
      return;
    }
    try {
      final prices = await ErpService.getList(
        'Item Price',
        filters: [
          ['item_code', '=', line.itemCode],
          ['price_list', '=', priceList],
        ],
        fields: const ['price_list_rate'],
        limit: 1,
      );
      if (!mounted) return;
      if (prices.isEmpty) {
        setState(
          () => line.priceStatus =
              'No hay precio registrado para este producto en la lista "$priceList"',
        );
        return;
      }
      final rate = prices.first['price_list_rate'] as num?;
      if (rate == null) {
        setState(
          () => line.priceStatus = 'El producto tiene precio registrado pero su valor está vacío',
        );
      } else {
        setState(() {
          line.unitPrice = rate;
          line.priceStatus = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => line.priceStatus = 'Error de conexión al obtener el precio: $e');
      }
    }
  }

  Future<void> _pickPriceList() async {
    final result = await showSearchPicker(
      context: context,
      title: 'Seleccionar Lista de Precios',
      hintText: 'Buscar por nombre de lista...',
      search: (query) async {
        final list = await CacheService.getSearchListCached(
          cacheDoctype: 'Price List_master',
          fetch: () => ErpService.getList(
            'Price List',
            filters: [
              ['selling', '=', 1],
              if (query.isNotEmpty) ['name', 'like', '%$query%'],
            ],
            fields: const ['name'],
            limit: 20,
          ),
          searchFilter: (row) {
            final name = (row['name'] ?? '').toString().toLowerCase();
            final q = query.toLowerCase();
            if (q.isNotEmpty && !name.contains(q)) return false;
            return true;
          },
        );
        return list
            .map(
              (p) => PickedRecord(
                name: p['name'] as String,
                label: p['name'] as String,
              ),
            )
            .toList();
      },
    );
    if (result == null) return;

    setState(() {
      _priceList = result.name;
      _priceListStatus = null;
    });

    for (final line in _lines) {
      await _fetchPriceForLine(line);
    }
  }

  Future<void> _pickWarehouseForLine(_OrderLine line) async {
    final result = await showSearchPicker(
      context: context,
      title: 'Seleccionar Bodega',
      hintText: 'Buscar por nombre de bodega...',
      search: (query) async {
        final list = await CacheService.getSearchListCached(
          cacheDoctype: 'Warehouse_master',
          fetch: () => ErpService.getList(
            'Warehouse',
            filters: [
              ['disabled', '=', 0],
              ['is_group', '=', 0],
              if (query.isNotEmpty) ['warehouse_name', 'like', '%$query%'],
            ],
            fields: const ['name', 'warehouse_name'],
            limit: 20,
          ),
          searchFilter: (row) {
            final name = (row['name'] ?? '').toString().toLowerCase();
            final wName = (row['warehouse_name'] ?? '')
                .toString()
                .toLowerCase();
            final q = query.toLowerCase();
            if (q.isNotEmpty && !name.contains(q) && !wName.contains(q)) {
              return false;
            }
            return true;
          },
        );
        return list
            .map(
              (w) => PickedRecord(
                name: w['name'] as String,
                label: (w['warehouse_name'] as String?) ?? w['name'] as String,
              ),
            )
            .toList();
      },
    );
    if (result == null) return;
    setState(() => line.warehouse = result.name);
  }

  Future<void> _pickDeliveryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _deliveryDate = picked);
  }

  Future<void> _pickPaymentTerms() async {
    final result = await showSearchPicker(
      context: context,
      title: 'Seleccionar Términos de Pago',
      hintText: 'Buscar plantilla...',
      search: (query) async {
        final list = await CacheService.getSearchListCached(
          cacheDoctype: 'Payment Terms Template_master',
          fetch: () => ErpService.getList(
            'Payment Terms Template',
            filters: query.isEmpty
                ? null
                : [
                    ['template_name', 'like', '%$query%'],
                  ],
            fields: const ['name', 'template_name'],
            limit: 20,
          ),
          searchFilter: (row) {
            final name = (row['name'] ?? '').toString().toLowerCase();
            final tName = (row['template_name'] ?? '').toString().toLowerCase();
            final q = query.toLowerCase();
            if (q.isNotEmpty && !name.contains(q) && !tName.contains(q)) {
              return false;
            }
            return true;
          },
        );
        return list
            .map(
              (t) => PickedRecord(
                name: t['name'] as String,
                label: (t['template_name'] as String?) ?? t['name'] as String,
              ),
            )
            .toList();
      },
    );
    if (result == null) return;
    setState(() {
      _paymentTerms = result;
      _paymentScheduleTerms = [];
      _paymentScheduleStatus = null;
      _loadingPaymentSchedule = true;
    });

    try {
      final template = await ErpService.getDoc(
        'Payment Terms Template',
        result.name,
      );
      if (template.isEmpty) {
        _paymentScheduleStatus = 'No se pudieron obtener los detalles de la plantilla del servidor';
      } else if (!template.containsKey('terms')) {
        _paymentScheduleStatus =
            'No tienes permiso para ver los detalles de los pagos';
      } else {
        final terms = template['terms'];
        if (terms is List && terms.isNotEmpty) {
          _paymentScheduleTerms = terms
              .whereType<Map>()
              .map((t) => Map<String, dynamic>.from(t))
              .toList();
        } else {
          _paymentScheduleStatus =
              'No hay cuotas estructuradas en esta plantilla';
        }
      }
    } catch (e) {
      _paymentScheduleStatus = 'Error de conexión al obtener la plantilla: $e';
    }
    if (mounted) setState(() => _loadingPaymentSchedule = false);
  }

  Future<void> _pickTermsTemplate() async {
    final result = await showSearchPicker(
      context: context,
      title: 'Seleccionar Términos y Condiciones',
      hintText: 'Buscar plantilla...',
      search: (query) async {
        final list = await CacheService.getSearchListCached(
          cacheDoctype: 'Terms and Conditions_master',
          fetch: () => ErpService.getList(
            'Terms and Conditions',
            filters: [
              ['selling', '=', 1],
              if (query.isNotEmpty) ['title', 'like', '%$query%'],
            ],
            fields: const ['name', 'title'],
            limit: 20,
          ),
          searchFilter: (row) {
            final name = (row['name'] ?? '').toString().toLowerCase();
            final title = (row['title'] ?? '').toString().toLowerCase();
            final q = query.toLowerCase();
            if (q.isNotEmpty && !name.contains(q) && !title.contains(q)) {
              return false;
            }
            return true;
          },
        );
        return list
            .map(
              (t) => PickedRecord(
                name: t['name'] as String,
                label: (t['title'] as String?) ?? t['name'] as String,
              ),
            )
            .toList();
      },
    );
    if (result == null) return;
    setState(() {
      _termsTemplate = result;
      _loadingTermsText = true;
    });
    try {
      final template = await ErpService.getDoc(
        'Terms and Conditions',
        result.name,
      );
      final terms = template['terms'] as String?;
      if (terms != null) _termsController.text = stripHtml(terms);
    } catch (_) {}
    if (mounted) setState(() => _loadingTermsText = false);
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  DateTime _dueDateForTerm(Map<String, dynamic> term, DateTime base) {
    final creditMonths = (term['credit_months'] as num?)?.toInt() ?? 0;
    if (creditMonths > 0) {
      return DateTime(base.year, base.month + creditMonths, base.day);
    }
    final creditDays = (term['credit_days'] as num?)?.toInt() ?? 0;
    final basedOn = term['due_date_based_on'] as String?;
    if (basedOn == 'Day(s) after the end of the invoice month') {
      final endOfMonth = DateTime(base.year, base.month + 1, 0);
      return endOfMonth.add(Duration(days: creditDays));
    }
    return base.add(Duration(days: creditDays));
  }

  num? get _grandTotal {
    if (_lines.isEmpty) return null;
    num total = 0;
    for (final line in _lines) {
      final price = line.unitPrice;
      if (price == null) return null; 
      total += price * line.qty;
    }
    return total;
  }

  Future<num?> _fetchCurrentOutstanding(String customerName) async {
    try {
      final invoices = await ErpService.getList(
        'Sales Invoice',
        filters: [
          ['customer', '=', customerName],
          ['docstatus', '=', 1],
          ['outstanding_amount', '>', 0],
        ],
        fields: const ['outstanding_amount'],
        limit: 200,
      );
      num total = 0;
      for (final invoice in invoices) {
        final amount = invoice['outstanding_amount'];
        if (amount is num) total += amount;
      }
      return total;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _checkCreditLimit() async {
    final creditLimit = _creditLimit;
    final customer = _customer;
    final grandTotal = _grandTotal;
    if (creditLimit == null || customer == null || grandTotal == null) {
      return true;
    }

    final currentOutstanding = await _fetchCurrentOutstanding(customer.name);
    if (currentOutstanding == null) return true;

    try {
      final projected = currentOutstanding + grandTotal;
      if (projected <= creditLimit) return true;

      if (!mounted) return false;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          title: const Text('Límite de Crédito Excedido'),
          content: Text(
            'Límite permitido: \$${creditLimit.toStringAsFixed(2)}\n'
            'Deuda actual del cliente: \$${currentOutstanding.toStringAsFixed(2)}\n'
            'Total de este pedido: \$${grandTotal.toStringAsFixed(2)}\n'
            'Total proyectado: \$${projected.toStringAsFixed(2)}\n\n'
            'No se puede enviar el pedido porque superaría el límite de crédito del cliente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return false;
    } catch (_) {
      return true;
    }
  }

  Future<String?> _captureLocationUrl() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _locationStatus = 'El GPS está apagado en el dispositivo';
        _locationFix = Geolocator.openLocationSettings;
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _locationStatus = 'Permiso de ubicación denegado';
        _locationFix = null;
        return null;
      }
      if (permission == LocationPermission.deniedForever) {
        _locationStatus =
            'Permiso denegado permanentemente. Actívalo en la configuración de la app.';
        _locationFix = Geolocator.openAppSettings;
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _locationStatus =
          'Ubicación obtenida (${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)})';
      _locationFix = null;
      return 'https://www.google.com/maps?q=${position.latitude},${position.longitude}';
    } catch (e) {
      _locationStatus = 'Error al obtener la ubicación: $e';
      _locationFix = null;
      return null;
    }
  }

  Future<String?> _ensureLocationCaptured() async {
    while (true) {
      final url = await _captureLocationUrl();
      if (url != null) return url;
      if (!mounted) return null;

      final fix = _locationFix;
      if (fix != null) await fix();
      if (!mounted) return null;

      final retry = Completer<void>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_locationStatus ?? 'Debes activar el GPS para enviar el pedido'),
          duration: const Duration(seconds: 12),
          action: SnackBarAction(
            label: 'Reintentar',
            onPressed: () {
              if (!retry.isCompleted) retry.complete();
            },
          ),
        ),
      );
      await retry.future;
      if (!mounted) return null;
    }
  }

  void _resetOrderForm() {
    _customer = null;
    _lines.clear();
    _priceList = null;
    _creditLimit = null;
    _creditLimitStatus = null;
    _priceListStatus = null;
    _deliveryDate = null;
    _paymentTerms = null;
    _termsTemplate = null;
    _termsController.clear();
    _paymentScheduleTerms = [];
    _paymentScheduleStatus = null;
    _locationStatus = null;
  }

  Future<bool> _submit() async {
    if (_customer == null || _lines.isEmpty) return false;

    final withinCreditLimit = await _checkCreditLimit();
    if (!withinCreditLimit) return false;

    setState(() {
      _submitting = true;
      _error = null;
      _lastSubmitWasQueued = false;
    });

    Map<String, dynamic>? fields;
    try {
      final locationUrl = await _ensureLocationCaptured();
      if (locationUrl == null) {
        if (mounted) setState(() => _submitting = false);
        return false;
      }
      if (mounted && _locationStatus != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ubicación: $_locationStatus'),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      fields = <String, dynamic>{
        'customer': _customer!.name,
        'items': _lines
            .map(
              (l) => {
                'item_code': l.itemCode,
                'qty': l.qty,
                if (l.warehouse != null) 'warehouse': l.warehouse,
              },
            )
            .toList(),
        if (_deliveryDate != null)
          'delivery_date': _deliveryDate!.toIso8601String().split('T').first,
        if (_paymentTerms != null)
          'payment_terms_template': _paymentTerms!.name,
        if (_termsTemplate != null) 'tc_name': _termsTemplate!.name,
        if (_termsController.text.trim().isNotEmpty)
          'terms': _termsController.text.trim(),
        'custom_location_url': locationUrl,
      };

      final editDoc = widget.editDoc;
      if (editDoc != null) {
        final editName = editDoc['name'] as String;
        if (!SyncStatusService().isOnline) {
          await SyncEngine().enqueue(
            type: SyncJobType.genericApiCall,
            payload: {
              'operation': 'update',
              'doctype': 'Sales Order',
              'name': editName,
              'data': fields,
            },
          );
          _lastSubmitWasQueued = true;
          if (!mounted) return true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sin internet — Los cambios se guardarán automáticamente'),
            ),
          );
          Navigator.of(context).pop();
          return true;
        }
        await ErpService.updateDoc('Sales Order', editName, fields);
        if (!mounted) return true;
        Navigator.of(context).pop();
        return true;
      }

      if (!SyncStatusService().isOnline) {
        await SyncEngine().enqueue(
          type: SyncJobType.salesOrderCreate,
          payload: fields,
        );
        _lastSubmitWasQueued = true;
        if (!mounted) return true;
        setState(_resetOrderForm);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sin internet — Pedido guardado en cola para sincronizar'),
          ),
        );
        return true;
      }

      final salesPerson = await ErpService.resolveCurrentSalesPerson();
      if (salesPerson != null) {
        fields['sales_team'] = [
          {'sales_person': salesPerson, 'allocated_percentage': 100},
        ];
      }
      final created = await ErpService.createDoc('Sales Order', fields);
      final submittedCustomer = _customer;

      if (!mounted) return true;
      setState(_resetOrderForm);

      final createdName = created['name'] as String?;
      if (createdName != null) {
        if (submittedCustomer != null) {
          await promptLogVisit(
            context,
            customer: submittedCustomer.name,
            territory: submittedCustomer.subtitle,
            referenceDoctype: 'Sales Order',
            referenceName: createdName,
          );
        }
        if (!mounted) return true;
        context.push(documentDetailRoute('Sales Order', createdName));
      }
      return true;
    } catch (e) {
      final capturedFields = fields;
      if (e is ErpException &&
          e.isConnectivityFailure &&
          capturedFields != null) {
        final editDoc = widget.editDoc;
        if (editDoc != null) {
          await SyncEngine().enqueue(
            type: SyncJobType.genericApiCall,
            payload: {
              'operation': 'update',
              'doctype': 'Sales Order',
              'name': editDoc['name'] as String,
              'data': capturedFields,
            },
          );
          _lastSubmitWasQueued = true;
          if (!mounted) return true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fallo de red — Cambios guardados en modo offline'),
            ),
          );
          Navigator.of(context).pop();
          return true;
        }
        await SyncEngine().enqueue(
          type: SyncJobType.salesOrderCreate,
          payload: capturedFields,
        );
        _lastSubmitWasQueued = true;
        if (!mounted) return true;
        setState(_resetOrderForm);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fallo de red — Pedido guardado en modo offline'),
          ),
        );
        return true;
      }
      if (!mounted) return false;
      final message = handleErpError(context, e);
      if (message == null) return false;
      setState(() => _error = message);
      return false;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _customer != null && _lines.isNotEmpty && !_submitting;
    final grandTotal = _grandTotal;
    final onCreateTab = _tabController.index == 0;

    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Pedido' : 'Nuevo Pedido'),
        bottom: _isEditing
            ? null
            : TabBar(
                controller: _tabController,
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.midGray,
                indicatorColor: AppColors.accent,
                tabs: const [
                  Tab(text: 'Nuevo Pedido'),
                  Tab(text: 'Todos los Pedidos'),
                ],
              ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _sectionTitle('Cliente'),
                      const SizedBox(height: 8),
                      _pickerCard(
                        label: _customer?.label ?? 'Seleccionar Cliente',
                        icon: Icons.storefront_rounded,
                        onTap: _pickCustomer,
                        trailing: _loadingPartyDetails
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                      ),
                      if (_customer != null && !_loadingPartyDetails) ...[
                        if (_customer!.subtitle != null) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              'Ruta: ${_customer!.subtitle}',
                              style: const TextStyle(
                                color: AppColors.midGray,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            _creditLimit != null
                                ? 'Límite de crédito: \$${_creditLimit!.toStringAsFixed(2)}'
                                : (_creditLimitStatus ?? 'Límite de crédito no disponible'),
                            style: const TextStyle(
                              color: AppColors.midGray,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            _currentOutstanding != null
                                ? 'Deuda actual: \$${_currentOutstanding!.toStringAsFixed(2)}'
                                : (_outstandingStatus ??
                                      'Deuda actual no disponible'),
                            style: const TextStyle(
                              color: AppColors.midGray,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _priceList != null
                              ? Text(
                                  'Lista de precios: $_priceList',
                                  style: const TextStyle(
                                    color: AppColors.midGray,
                                    fontSize: 12,
                                  ),
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _priceListStatus ??
                                            'Lista de precios no disponible',
                                        style: const TextStyle(
                                          color: AppColors.midGray,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _pickPriceList,
                                      child: const Text(
                                        'Elegir manual',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _sectionTitle('Artículos'),
                          TextButton.icon(
                            onPressed: _addItem,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Añadir Producto'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_lines.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                          ),
                          child: const Center(
                            child: Text(
                              'No has añadido artículos aún',
                              style: TextStyle(color: AppColors.midGray),
                            ),
                          ),
                        )
                      else
                        ..._lines.asMap().entries.map((entry) {
                          final index = entry.key;
                          final line = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        line.itemName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle_outline_rounded,
                                            size: 20,
                                          ),
                                          color: AppColors.accent,
                                          visualDensity: VisualDensity.compact,
                                          onPressed: line.qty > 1
                                              ? () => setState(
                                                  () => line.qty -= 1,
                                                )
                                              : null,
                                        ),
                                        SizedBox(
                                          width: 28,
                                          child: Text(
                                            line.qty.toStringAsFixed(0),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.add_circle_outline_rounded,
                                            size: 20,
                                          ),
                                          color: AppColors.accent,
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () =>
                                              setState(() => line.qty += 1),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        color: AppColors.midGray,
                                      ),
                                      onPressed: () => setState(
                                        () => _lines.removeAt(index),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  line.unitPrice != null
                                      ? 'Precio: \$${line.unitPrice} × ${line.qty.toStringAsFixed(0)} = \$${(line.unitPrice! * line.qty).toStringAsFixed(2)}'
                                      : (line.priceStatus ?? 'Precio no disponible'),
                                  style: const TextStyle(
                                    color: AppColors.midGray,
                                    fontSize: 11.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () => _pickWarehouseForLine(line),
                                  child: Text(
                                    'Bodega: ${line.warehouse ?? 'Predeterminada (Automática)'}',
                                    style: const TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      if (_lines.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            grandTotal != null
                                ? 'Total estimado: \$${grandTotal.toStringAsFixed(2)}'
                                : 'Total incompleto (faltan precios)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _sectionTitle('Fecha de Entrega'),
                      const SizedBox(height: 8),
                      _pickerCard(
                        label: _deliveryDate != null
                            ? _formatDate(_deliveryDate!)
                            : 'Seleccionar fecha de entrega',
                        icon: Icons.event_rounded,
                        onTap: _pickDeliveryDate,
                      ),
                      const SizedBox(height: 24),
                      _sectionTitle('Términos de Pago'),
                      const SizedBox(height: 8),
                      _pickerCard(
                        label: _paymentTerms?.label ?? 'Seleccionar Términos de Pago',
                        icon: Icons.receipt_long_rounded,
                        onTap: _pickPaymentTerms,
                        trailing: _loadingPaymentSchedule
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                      ),
                      if (_paymentScheduleTerms.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Vista previa de cuotas (estimadas)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._paymentScheduleTerms.map((t) {
                                final portion = t['invoice_portion'] as num?;
                                final description = t['description'] as String?;
                                final baseDate =
                                    _deliveryDate ?? DateTime.now();
                                final dueDate = _dueDateForTerm(t, baseDate);
                                final amount =
                                    (portion != null && grandTotal != null)
                                    ? grandTotal * portion / 100
                                    : null;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Vencimiento ${_formatDate(dueDate)} — ${portion ?? '—'}%'
                                          '${description != null && description.isNotEmpty ? ' — $description' : ''}',
                                          style: const TextStyle(
                                            color: AppColors.midGray,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      if (amount != null)
                                        Text(
                                          '\$${amount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: AppColors.black,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ] else if (_paymentScheduleStatus != null &&
                          !_loadingPaymentSchedule) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            _paymentScheduleStatus!,
                            style: const TextStyle(
                              color: AppColors.midGray,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _sectionTitle('Términos y Condiciones'),
                      const SizedBox(height: 8),
                      _pickerCard(
                        label: _termsTemplate?.label ?? 'Seleccionar plantilla',
                        icon: Icons.description_rounded,
                        onTap: _pickTermsTemplate,
                        trailing: _loadingTermsText
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _termsController,
                        minLines: 3,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          hintText:
                              'Escribe los términos manualmente o edítalos tras elegir una plantilla',
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.accent,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  if (!_isEditing) const AllSalesOrdersScreen(),
                ],
              ),
            ),
            if (onCreateTab) ...[
              if (!canSubmit && !_submitting)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    _customer == null
                        ? 'Selecciona un cliente primero'
                        : 'Añade al menos un artículo',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.midGray,
                      fontSize: 12,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Opacity(
                  opacity: canSubmit ? 1 : 0.4,
                  child: IgnorePointer(
                    ignoring: !canSubmit,
                    child: SwipeToConfirmButton(
                      label: 'Desliza para enviar pedido',
                      confirmedLabel: 'Guardado',
                      onConfirmed: _submit,
                      wasQueued: () => _lastSubmitWasQueued,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
    );
  }

  Widget _pickerCard({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: AppColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (trailing != null) trailing,
              const Icon(Icons.chevron_right_rounded, color: AppColors.midGray),
            ],
          ),
        ),
      ),
    );
  }
}
