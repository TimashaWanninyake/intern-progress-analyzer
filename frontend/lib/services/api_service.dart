// call Flask APIs
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Replace with your Flask backend URL
  static const String baseUrl = 'http://127.0.0.1:5000';

  // ================= SIGNUP =================
  static Future<Map<String, dynamic>> signup(
      String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ================= LOGIN BY EMAIL (NO PASSWORD) =================
  static Future<Map<String, dynamic>> loginByEmail(
      String email, String role) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login-by-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'role': role,
        }),
      );

      final body = jsonDecode(response.body);

      if (body['success']) {
        // Save token in shared preferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', body['token']);
      }

      return body;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ================= LOGIN (WITH PASSWORD - LEGACY) =================
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final body = jsonDecode(response.body);

      if (body['success']) {
        // Save token in shared preferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', body['token']);
      }

      return body;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ================= GET TOKEN =================
  static Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // ================= LOGOUT =================
  static Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  // ================= AUTHORIZED GET REQUEST =================
  static Future<Map<String, dynamic>> getRequest(String endpoint) async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ================= AUTHORIZED POST REQUEST =================
  static Future<Map<String, dynamic>> postRequest(
      String endpoint, Map<String, dynamic> body) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ================= AUTHORIZED PUT REQUEST =================
  static Future<Map<String, dynamic>> putRequest(
      String endpoint, Map<String, dynamic> body) async {
    try {
      final token = await getToken();
      final response = await http.put(
        Uri.parse('$baseUrl/$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ================= AUTHORIZED DELETE REQUEST =================
  static Future<Map<String, dynamic>> deleteRequest(String endpoint) async {
    try {
      final token = await getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',  
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
