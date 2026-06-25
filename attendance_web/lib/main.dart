import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const AttendanceWebApp());
}

class AttendanceWebApp extends StatelessWidget {
  const AttendanceWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recognition Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
        colorSchemeSeed: const Color(0xFF2563EB),
      ),
      home: const StudentRegistrationPage(),
    );
  }
}

class StudentRegistrationPage extends StatefulWidget {
  const StudentRegistrationPage({super.key});

  @override
  State<StudentRegistrationPage> createState() =>
      _StudentRegistrationPageState();
}

class _StudentRegistrationPageState extends State<StudentRegistrationPage> {
  final studentNoController = TextEditingController();

  static const baseUrl = 'https://recognition-api-29xg.onrender.com';

  bool isLoading = false;
  String? errorMessage;
  Map<String, dynamic>? result;

  Future<void> registerStudent() async {
    final studentNo = studentNoController.text.trim();

    if (studentNo.isEmpty) {
      setState(() {
        errorMessage = 'Please enter your student number.';
        result = null;
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
      result = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/student/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'student_no': studentNo}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        setState(() {
          errorMessage = data['message'] ?? 'Registration failed.';
        });
        return;
      }

      setState(() {
        result = data;
      });
    } catch (_) {
      setState(() {
        errorMessage = 'Cannot connect to server. Please ask assistance.';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void resetForm() {
    setState(() {
      studentNoController.clear();
      errorMessage = null;
      result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = result != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.school_rounded,
                        size: 64,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Recognition Day 2026',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Student Attendance & Seat Assignment',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: isSuccess
                      ? _SuccessCard(data: result!, onReset: resetForm)
                      : _RegistrationCard(
                          controller: studentNoController,
                          isLoading: isLoading,
                          errorMessage: errorMessage,
                          onSubmit: registerStudent,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RegistrationCard extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSubmit;

  const _RegistrationCard({
    required this.controller,
    required this.isLoading,
    required this.errorMessage,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('registration'),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter your Student Number',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'After registration, your seat number will appear immediately.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              textAlign: TextAlign.center,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                hintText: 'e.g. 2026-001',
                prefixIcon: const Icon(Icons.badge_outlined),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : onSubmit,
                icon: isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(isLoading ? 'Registering...' : 'Register'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onReset;

  const _SuccessCard({required this.data, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('success'),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 38,
              backgroundColor: Color(0xFFDCFCE7),
              child: Icon(
                Icons.check_rounded,
                size: 48,
                color: Color(0xFF16A34A),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              data['message'] ?? 'Registration successful',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF16A34A),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              data['full_name'] ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Text(
                    'YOUR SEAT NUMBER',
                    style: TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    data['seat_no'].toString(),
                    style: const TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Register another student'),
            ),
          ],
        ),
      ),
    );
  }
}
