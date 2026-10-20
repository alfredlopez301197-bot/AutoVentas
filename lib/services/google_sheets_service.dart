
import 'dart:convert';

import 'package:http/http.dart' as http;

class GoogleSheetsService {
  static const String apiUrl =
      'https://script.google.com/macros/s/'
      'AKfycbz6Dhi_ysLgfc6O1renR2FiIoinWJ6QyuM3n_t3vzuPE7HK1mnnb1P4V3N4q8Z-L1-v/exec';

  static const Duration _timeout = Duration(seconds: 20);

  /// Comprueba si la API AutoVentas está disponible.
  static Future<bool> ping() async {
    try {
      final response = await http.get(
        Uri.parse(apiUrl),
      ).timeout(_timeout);

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

  /// Envía una solicitud JSON a Google Apps Script.
  ///
  /// El servidor debe autenticar cada solicitud.
  /// No se debe incluir un token secreto fijo en
  /// el código público de Flutter.
  ///
  /// Las operaciones de ventas y cobros requieren
  /// identificadores únicos para evitar duplicados.
  static Future<Map<String, dynamic>> post({
    required Map<String, dynamic> body,
  }) async {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: const {
        'Content-Type': 'text/plain; charset=utf-8',
      },
      body: jsonEncode(body),
    ).timeout(_timeout);

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

    final result = Map<String, dynamic>.from(decoded);

    if (result['status'] != 'ok') {
      throw Exception(
        result['mensaje'] ??
            'Google Sheets rechazó la solicitud.',
      );
    }

    return result;
  }
}
