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
      final response = await http.get(Uri.parse(apiUrl)).timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Inicia sesión consultando el GET de Apps Script (?user=...&pass=...)
  static Future<Map<String, dynamic>> login({
    required String usuario,
    required String password,
  }) async {
    final userEncoded = Uri.encodeComponent(usuario.trim());
    final passEncoded = Uri.encodeComponent(password);
    final urlLogin = '$apiUrl?user=$userEncoded&pass=$passEncoded';

    var response = await http.get(Uri.parse(urlLogin)).timeout(_timeout);
    
    // Si Google redirige, seguimos la ruta (Error 302 / 303)
    if (response.statusCode == 302 || response.statusCode == 303) {
      final location = response.headers['location'];
      if (location != null) {
        response = await http.get(Uri.parse(location)).timeout(_timeout);
      }
    }

    if (response.statusCode != 200) {
      throw Exception('Error HTTP ${response.statusCode} al iniciar sesión.');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      throw const FormatException('Respuesta inválida del servidor.');
    }

    final result = Map<String, dynamic>.from(decoded);

    if (result['success'] == true) {
      _session = 'sesion_activa_${DateTime.now().millisecondsSinceEpoch}';
      
      // Guardamos la info del rol y ruta para usarla en todo el sistema
      final datosUsuario = result['usuario'] as Map<String, dynamic>? ?? {};
      
      _currentUser = {
        'usuario': usuario,
        'nombre': datosUsuario['nombre'] ?? usuario.toUpperCase(),
        'rol': datosUsuario['rol'] ?? '',
        'ruta': datosUsuario['ruta'] ?? '',
      };

      return _currentUser!;
    } else {
      throw Exception(
        result['mensaje'] ?? 'Usuario o contraseña incorrectos.',
      );
    }
  }

  /// Envía solicitudes (Clientes, Visitas, Pedidos, Cobros) a Apps Script.
  static Future<Map<String, dynamic>> post({
    required Map<String, dynamic> body,
  }) async {
    // Forzamos al cliente a atrapar el salto de Google para evitar que la app se congele.
    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse(apiUrl))
        ..headers['Content-Type'] = 'text/plain; charset=utf-8' // Clave para evitar problemas CORS
        ..body = jsonEncode(body)
        ..followRedirects = false; // Detenemos la redirección automática

      final streamedResponse = await client.send(request).timeout(_timeout);
      http.Response response = await http.Response.fromStream(streamedResponse);

      // ¡AQUÍ ESTÁ LA SOLUCIÓN! Atrapamos el 302 y vamos directo a la URL con la respuesta.
      if (response.statusCode == 302 || response.statusCode == 303) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          response = await client.get(Uri.parse(redirectUrl)).timeout(_timeout);
        }
      }

      if (response.statusCode != 200) {
        throw Exception('Error HTTP ${response.statusCode}. Verifica tu conexión.');
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        throw const FormatException('La API devolvió una respuesta inválida.');
      }

      final result = Map<String, dynamic>.from(decoded);

      if (result['status'] != 'ok') {
        throw Exception((result['mensaje'] ?? 'Google Sheets rechazó la solicitud.').toString());
      }

      return result;
    } finally {
      client.close();
    }
  }

  static void logout() {
    _session = null;
    _currentUser = null;
  }
}
