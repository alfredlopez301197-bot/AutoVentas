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
    setState(() => line.warehouse =
