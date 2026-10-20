
import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleSheetsService {
  static const String apiUrl =
      'https://script.google.com/macros/s/'
      'AKfycbz6Dhi_ysLgfc6O1renR2FiIoinWJ6QyuM3n_t3vzuPE7HK1mnnb1P4V3N4q8Z-L1-v/exec';

  static Future<bool> ping() async {
    try {
      final response = await http.get(
        Uri.parse(apiUrl),
      ).timeout(const Duration(seconds: 15));

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
}
  
