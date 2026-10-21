
import 'dart:convert';

import 'package:http/http.dart' as http;

class GoogleSheetsService {
  static const String apiUrl =
      'https://script.google.com/macros/s/'
      'AKfycbz6Dhi_ysLgfc6O1renR2FiIoinWJ6QyuM3n_t3vzuPE7HK1mnnb1P4V3N4q8Z-L1-v/exec';

  // SOLO PARA PRUEBAS PRIVADAS.
  // Pega aquí el token de prueba en tu editor.
  // No compartas el token ni publiques esta versión.
  static const String _apiToken =
      'fbd37c5b-80b1-401b-bbc9-d40548a3c6a9-4008d40c-ce4b-44cc-855b-747ef99d2692';

  static const Duration _timeout =
      Duration(seconds: 20);

  static Future<bool> ping() async {
    try {
      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(_timeout);

      if (response.statusCode != 200) {
        return false;
      }

      final data = jsonDecode(response.body);

      return data is Map &&
          data['status'] == 'ok' &&
          data['aplicacion'] == 'AutoVentas';
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> post({
    required Map<String, dynamic> body,
  }) async {
    if (_apiToken.isEmpty ||
        _apiToken == 'PEGA_AQUI_TU_TOKEN_DE_PRUEBA') {
      throw Exception(
        'Falta configurar el token de prueba.',
      );
    }

    final payload = <String, dynamic>{
      ...body,
      'token': _apiToken,
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
        'Error HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      throw const FormatException(
        'La API devolvió una respuesta inválida.',
      );
    }

    final result =
        Map<String, dynamic>.from(decoded);

    if (result['status'] != 'ok') {
      throw Exception(
        result['mensaje'] ??
            'Google Sheets rechazó la solicitud.',
      );
    }

    return result;
  }

  static Future<List<Map<String, dynamic>>>
      getProductos() async {
    final result = await post(
      body: {'action': 'productos'},
    );

    return _toMapList(result['data']);
  }

  static Future<List<Map<String, dynamic>>>
      getClientes() async {
    final result = await post(
      body: {'action': 'clientes'},
    );

    return _toMapList(result['data']);
  }

  static List<Map<String, dynamic>> _toMapList(
    dynamic value,
  ) {
    if (value is! List) {
      throw const FormatException(
        'La API no devolvió una lista válida.',
      );
    }

    return value
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }
}
