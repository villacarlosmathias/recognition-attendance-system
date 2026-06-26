import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const baseUrl = 'https://recognition-api-29xg.onrender.com';

  Future<List<dynamic>> getEvents() async {
    final response = await http.get(Uri.parse('$baseUrl/events'));
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/events'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getAttendees(int eventId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/events/$eventId/attendees'),
    );
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> addAttendee(
    int eventId,
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/events/$eventId/attendees'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> importAttendees(
    int eventId,
    List<Map<String, dynamic>> attendees,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/events/$eventId/import-attendees'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'attendees': attendees}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Import failed');
    }

    return data;
  }

  Future<List<dynamic>> getReport(int eventId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/events/$eventId/report'),
    );

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }

    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> registerStudent(
    int eventId,
    String studentNo,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/events/$eventId/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'student_no': studentNo}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Registration failed');
    }

    return data;
  }
}
