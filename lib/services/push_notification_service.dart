
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../main.dart' show openDocumentFromNotification;
import 'auth_service.dart';
import 'erp_service.dart';
import 'prefetch_service.dart';

/// Registra el token FCM del dispositivo para el usuario actual.
class PushNotificationService {
  PushNotificationService._();

  static bool _initialized = false;

  /// Inicializa Firebase e intenta registrar las notificaciones.
  /// Los errores no deben impedir el acceso a la aplicación.
  static Future<void> registerForCurrentUser() async {
    try {
      if (!_initialized) {
        // Android obtiene la configuración nativa de Firebase
        // mediante google-services.json, si está configurado.
        await Firebase.initializeApp();
        _initialized = true;
      }

      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission();

      final token = await messaging.getToken();

      if (token != null) {
        await _saveToken(token);
      }

      messaging.onTokenRefresh.listen((newToken) {
        _saveToken(newToken);
      });

      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

      final initialMessage = await messaging.getInitialMessage();

      if (initialMessage != null) {
        _handleTap(initialMessage);
      }

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    } catch (e, stackTrace) {
      // La ausencia de configuración de Firebase no debe
      // bloquear el inicio de AutoVentas.
      debugPrint(
        'PushNotificationService: not active yet ($e)',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static void _handleTap(RemoteMessage message) {
    final doctype = message.data['doctype'];
    final name = message.data['name'];

    if (doctype is String && name is String) {
      openDocumentFromNotification(doctype, name);
    }

    _refreshCacheFor(message);
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    _refreshCacheFor(message);
  }

  static void _refreshCacheFor(RemoteMessage message) {
    final doctype = message.data['doctype'];

    if (doctype is String) {
      PrefetchService.handlePushRefresh(doctype);
    }
  }

  static Future<void> _saveToken(String token) async {
    try {
      final userId = await AuthService.currentUserId();

      if (userId == null) return;

      await ErpService.updateDoc('User', userId, {
        'custom_fcm_token': token,
      });
    } catch (_) {
      // Si falla el registro del token, la aplicación continúa.
    }
  }
}
