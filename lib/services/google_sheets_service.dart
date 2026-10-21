import 'dart:convert';

import 'package:http/http.dart' as http;

class GoogleSheetsService {
  static const String apiUrl =
      'https://script.google.com/macros/s/'
      'AKfycbz6Dhi_ysLgfc6O1renR2FiIoinWJ6QyuM3n_t3vzuPE7HK1mnnb1P4V3N4q8Z-L1-v/exec';

  static const Duration _timeout = Duration(seconds: 20);

  // Sesión disponible durante la ejecución de la aplicación.
  static String? _session;
  static Map<String, dynamic>? _currentUser;

  static bool get isAuthenticated =>
      _session != null && _session!.isNotEmpty;

  static Map<String, dynamic>? get currentUser => _currentUser;

  /// Comprueba que la API pública esté disponible.
  static Future<bool> ping() async {
    try {
      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(_timeout);

      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body);

      return data is Map &&
          data['status'] == 'ok' &&
          data['aplicacion'] == 'AutoVentas';
    } catch (_) {
      return false;
    }
  }

  /// Inicia sesión contra la hoja Usuarios de Apps Script.
  static Future<Map<String, dynamic>> login({
    required String usuario,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse(apiUrl),
          headers: const {
            'Content-Type': 'text/plain; charset=utf-8',
          },
          body: jsonEncode({
            'action': 'login',
            'usuario': usuario.trim(),
            'password': password,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Error HTTP ${response.statusCode} al iniciar sesión.',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      throw const FormatException(
        'Respuesta inválida del servidor.',
      );
    }

    final result = Map<String, dynamic>.from(decoded);

    final session = result['sesion'];
    final user = result['usuario'];

    if (result['status'] != 'ok' ||
        result['success'] != true ||
        session is! String ||
        session.isEmpty) {
      throw Exception(
        result['mensaje'] ??
            'Usuario o contraseña incorrectos.',
      );
    }

    _session = session;

    _currentUser = user is Map
        ? Map<String, dynamic>.from(user)
        : <String, dynamic>{};

    return _currentUser!;
  }

  /// Envía solicitudes autenticadas a Apps Script.
  ///
  /// Añade automáticamente la sesión a cada solicitud.
  static Future<Map<String, dynamic>> post({
    required Map<String, dynamic> body,
  }) async {
    final session = _session;

    if (session == null || session.isEmpty) {
      throw Exception(
        'No hay una sesión activa. Inicia sesión nuevamente.',
      );
    }

    final payload = <String, dynamic>{
      ...body,
      'sesion': session,
    };

    final response = await http
        .post(
          Uri.parse(apiUrl),
          headers: const {
            'Content-Type': 'text/plain; charset=utf-8',
          },
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Error HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      throw const FormatException(
        'La API devolvió una respuesta inválida.',
      );
    }

    final result = Map<String, dynamic>.from(decoded);

    if (result['status'] != 'ok') {
      final message = (result['mensaje'] ??
              'Google Sheets rechazó la solicitud.')
          .toString();

      if (message.toLowerCase().contains('sesión')) {
        _clearSession();
      }

      throw Exception(message);
    }

    return result;
  }

  /// Cierra la sesión local de Flutter.
  ///
  /// La sesión del servidor caduca según su configuración.
  static void logout() {
    _clearSession();
  }

  static void _clearSession() {
    _session = null;
    _currentUser = null;
  }
}
