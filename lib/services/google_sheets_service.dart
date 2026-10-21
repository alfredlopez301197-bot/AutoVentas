import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleSheetsService {
  static const String apiUrl =
      'https://script.google.com/macros/s/AKfycbz6Dhi_ysLgfc6O1renR2FiIoinWJ6QyuM3n_t3vzuPE7HK1mnnb1P4V3N4q8Z-L1-v/exec';

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

  /// Inicia sesión consultando el GET de Apps Script (?user=...&pass=...)
  static Future<Map<String, dynamic>> login({
    required String usuario,
    required String password,
  }) async {
    // Armamos el enlace exactamente como probaste en el navegador
    final userEncoded = Uri.encodeComponent(usuario.trim());
    final passEncoded = Uri.encodeComponent(password);
    final urlLogin = '$apiUrl?user=$userEncoded&pass=$passEncoded';

    final response = await http
        .get(Uri.parse(urlLogin))
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Error HTTP ${response.statusCode} al iniciar sesión.');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      throw const FormatException('Respuesta inválida del servidor.');
    }

    final result = Map<String, dynamic>.from(decoded);

    // Validamos el success que devuelve tu Google Sheets
    if (result['success'] == true) {
      // Creamos una sesión local para autorizar las operaciones de ventas
      _session = 'sesion_activa_${DateTime.now().millisecondsSinceEpoch}';
      
      _currentUser = {
        'usuario': usuario,
        'nombre': usuario.toUpperCase(),
      };

      return _currentUser!;
    } else {
      throw Exception(
        result['mensaje'] ?? 'Usuario o contraseña incorrectos.',
      );
    }
  }

  /// Envía solicitudes autenticadas (Visitas, Pedidos, Cobros) a Apps Script.
  static Future<Map<String, dynamic>> post({
    required Map<String, dynamic> body,
  }) async {
    final session = _session;

    if (session == null || session.isEmpty) {
      throw Exception('No hay una sesión activa. Inicia sesión nuevamente.');
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
      throw Exception('Error HTTP ${response.statusCode}.');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      throw const FormatException('La API devolvió una respuesta inválida.');
    }

    final result = Map<String, dynamic>.from(decoded);

    if (result['status'] != 'ok') {
      final message = (result['mensaje'] ?? 'Google Sheets rechazó la solicitud.').toString();
      if (message.toLowerCase().contains('sesión')) {
        _clearSession();
      }
      throw Exception(message);
    }

    return result;
  }

  /// Cierra la sesión local de Flutter.
  static void logout() {
    _clearSession();
  }

  static void _clearSession() {
    _session = null;
    _currentUser = null;
  }
}
