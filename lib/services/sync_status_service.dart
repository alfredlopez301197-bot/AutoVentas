
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../local_db/app_database.dart';
import '../local_db/sync_job_type.dart';
import 'google_sheets_service.dart';

/// Controla la conexión y las operaciones pendientes
/// de sincronización de AutoVentas.
class SyncStatusService extends ChangeNotifier {
  SyncStatusService._(this._db);

  static SyncStatusService? _instance;

  @visibleForTesting
  static bool disableBackgroundWorkForTests = false;

  factory SyncStatusService() =>
      _instance ??= SyncStatusService._(
        AppDatabase.instance,
      );

  final AppDatabase _db;

  StreamSubscription<List<ConnectivityResult>>?
      _connectivitySub;

  StreamSubscription<List<SyncJob>>?
      _pendingCountSub;

  Timer? _fallbackTimer;
  Timer? _debounce;

  int _listenerCount = 0;

  bool _isOnline = true;
  int _pendingCount = 0;
  bool _checking = false;

  bool get isOnline => _isOnline;

  int get pendingCount => _pendingCount;

  bool get isChecking => _checking;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _listenerCount++;

    if (_listenerCount == 1) {
      _start();
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _listenerCount--;

    if (_listenerCount == 0) {
      _stop();
    }
  }

  void _start() {
    if (disableBackgroundWorkForTests) return;

    _watchPendingCount();
    _listenToConnectivityChanges();

    unawaited(checkNow());
  }

  void _stop() {
    _connectivitySub?.cancel();
    _pendingCountSub?.cancel();
    _fallbackTimer?.cancel();
    _debounce?.cancel();

    _connectivitySub = null;
    _pendingCountSub = null;
    _fallbackTimer = null;
    _debounce = null;
  }

  void _watchPendingCount() {
    final query = _db.select(_db.syncJobs)
      ..where(
        (t) => t.status.isIn([
          SyncJobStatus.pending.name,
          SyncJobStatus.inProgress.name,
          SyncJobStatus.needsReview.name,
        ]),
      );

    _pendingCountSub =
        query.watch().listen((rows) {
      _pendingCount = rows.length;
      notifyListeners();
    });
  }

  void _listenToConnectivityChanges() {
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(
      (_) {
        _debounce?.cancel();

        _debounce = Timer(
          const Duration(milliseconds: 800),
          () {
            unawaited(checkNow());
          },
        );
      },
    );

    _fallbackTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) {
        unawaited(checkNow());
      },
    );
  }

  /// Comprueba si Google Apps Script responde.
  Future<bool> checkNow() async {
    if (_checking) {
      return _isOnline;
    }

    _checking = true;
    notifyListeners();

    try {
      final reachable =
          await GoogleSheetsService.ping();

      _isOnline = reachable;

      return reachable;
    } catch (_) {
      _isOnline = false;
      return false;
    } finally {
      _checking = false;
      notifyListeners();
    }
  }
}
