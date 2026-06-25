import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const EventAttendanceApp());
}

class EventAttendanceApp extends StatelessWidget {
  const EventAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Event Smart Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
        colorSchemeSeed: const Color(0xFF2563EB),
      ),
      home: const AdminShell(),
    );
  }
}

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

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int selectedIndex = 0;
  Map<String, dynamic>? selectedEvent;

  void openEvent(Map<String, dynamic> event) {
    setState(() {
      selectedEvent = event;
      selectedIndex = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(onOpenEvents: () => setState(() => selectedIndex = 1)),
      EventsPage(onOpenEvent: openEvent),
      EventDetailsPage(event: selectedEvent),
      const StudentRegistrationPage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          Container(
            width: 270,
            color: const Color(0xFF0F172A),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  const Icon(
                    Icons.event_available,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Smart Attendance',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _NavTile(
                    icon: Icons.dashboard,
                    label: 'Dashboard',
                    selected: selectedIndex == 0,
                    onTap: () => setState(() => selectedIndex = 0),
                  ),
                  _NavTile(
                    icon: Icons.event,
                    label: 'Events',
                    selected: selectedIndex == 1,
                    onTap: () => setState(() => selectedIndex = 1),
                  ),
                  _NavTile(
                    icon: Icons.people,
                    label: 'Event Details',
                    selected: selectedIndex == 2,
                    onTap: () => setState(() => selectedIndex = 2),
                  ),
                  _NavTile(
                    icon: Icons.qr_code,
                    label: 'Student Registration',
                    selected: selectedIndex == 3,
                    onTap: () => setState(() => selectedIndex = 3),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: pages[selectedIndex]),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: ListTile(
        onTap: onTap,
        selected: selected,
        selectedTileColor: const Color(0xFF2563EB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(icon, color: Colors.white),
        title: Text(label, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  final VoidCallback onOpenEvents;

  const DashboardPage({super.key, required this.onOpenEvents});

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      title: 'Dashboard',
      subtitle: 'Reusable event registration, attendance, and seat management.',
      child: Column(
        children: [
          Row(
            children: const [
              _DashboardCard(
                title: 'Events',
                value: 'Manage',
                icon: Icons.event,
              ),
              SizedBox(width: 16),
              _DashboardCard(
                title: 'Seat Plan',
                value: 'Flexible',
                icon: Icons.chair,
              ),
              SizedBox(width: 16),
              _DashboardCard(
                title: 'Reports',
                value: 'Per Event',
                icon: Icons.bar_chart,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: onOpenEvents,
              icon: const Icon(Icons.add),
              label: const Text('Create or Open Event'),
            ),
          ),
        ],
      ),
    );
  }
}

class EventsPage extends StatefulWidget {
  final void Function(Map<String, dynamic> event) onOpenEvent;

  const EventsPage({super.key, required this.onOpenEvent});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final api = ApiService();
  bool loading = true;
  List<dynamic> events = [];

  @override
  void initState() {
    super.initState();
    loadEvents();
  }

  Future<void> loadEvents() async {
    setState(() => loading = true);
    events = await api.getEvents();
    setState(() => loading = false);
  }

  Future<void> openCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const CreateEventDialog(),
    );

    if (created == true) {
      await loadEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      title: 'Events',
      subtitle: 'Create and manage events with optional seat plans.',
      action: ElevatedButton.icon(
        onPressed: openCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Event'),
      ),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: events.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final event = events[index];
                final seatPlan = event['requires_seat_plan'] == true
                    ? event['seat_plan_type']
                    : 'none';

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(18),
                    title: Text(
                      event['event_name'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(
                      'Date: ${event['event_date'] ?? '-'}\n'
                      'Venue: ${event['venue'] ?? '-'}\n'
                      'Seat Plan: $seatPlan',
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => widget.onOpenEvent(event),
                      child: const Text('Open'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class CreateEventDialog extends StatefulWidget {
  const CreateEventDialog({super.key});

  @override
  State<CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<CreateEventDialog> {
  final api = ApiService();

  final titleController = TextEditingController();
  final dateController = TextEditingController();
  final venueController = TextEditingController();
  final startTimeController = TextEditingController();
  final endTimeController = TextEditingController();

  bool requiresSeatPlan = false;
  String seatPlanType = 'none';
  bool saving = false;

  Future<void> saveEvent() async {
    setState(() => saving = true);

    await api.createEvent({
      'event_name': titleController.text.trim(),
      'event_date': dateController.text.trim(),
      'venue': venueController.text.trim(),
      'start_time': startTimeController.text.trim().isEmpty
          ? null
          : startTimeController.text.trim(),
      'end_time': endTimeController.text.trim().isEmpty
          ? null
          : endTimeController.text.trim(),
      'requires_registration': true,
      'requires_seat_plan': requiresSeatPlan,
      'seat_plan_type': requiresSeatPlan ? seatPlanType : 'none',
    });

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Event'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _Input(controller: titleController, label: 'Event Title'),
              _Input(controller: dateController, label: 'Date YYYY-MM-DD'),
              _Input(controller: venueController, label: 'Venue'),
              _Input(
                controller: startTimeController,
                label: 'Start Time HH:MM',
              ),
              _Input(controller: endTimeController, label: 'End Time HH:MM'),
              SwitchListTile(
                value: requiresSeatPlan,
                onChanged: (value) {
                  setState(() {
                    requiresSeatPlan = value;
                    seatPlanType = value ? 'individual' : 'none';
                  });
                },
                title: const Text('Requires Seat Plan'),
              ),
              if (requiresSeatPlan)
                DropdownButtonFormField<String>(
                  initialValue: seatPlanType,
                  decoration: const InputDecoration(
                    labelText: 'Seat Plan Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'individual',
                      child: Text('Individual'),
                    ),
                    DropdownMenuItem(value: 'group', child: Text('Per Group')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      seatPlanType = value ?? 'individual';
                    });
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: saving ? null : saveEvent,
          child: Text(saving ? 'Saving...' : 'Save Event'),
        ),
      ],
    );
  }
}

class EventDetailsPage extends StatefulWidget {
  final Map<String, dynamic>? event;

  const EventDetailsPage({super.key, required this.event});

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  final api = ApiService();

  bool loading = false;
  List<dynamic> attendees = [];

  @override
  void didUpdateWidget(covariant EventDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.event?['id'] != oldWidget.event?['id']) {
      loadAttendees();
    }
  }

  @override
  void initState() {
    super.initState();
    loadAttendees();
  }

  Future<void> loadAttendees() async {
    final event = widget.event;
    if (event == null) return;

    setState(() => loading = true);
    attendees = await api.getAttendees(event['id']);
    setState(() => loading = false);
  }

  Future<void> openAddStudent() async {
    final event = widget.event;
    if (event == null) return;

    final added = await showDialog<bool>(
      context: context,
      builder: (_) => AddStudentDialog(event: event),
    );

    if (added == true) {
      await loadAttendees();
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;

    if (event == null) {
      return const _PageScaffold(
        title: 'Event Details',
        subtitle: 'Select an event from the Events page.',
        child: Center(child: Text('No event selected.')),
      );
    }

    final checkedIn = attendees
        .where((a) => a['status'] == 'Checked In')
        .length;
    final pending = attendees.length - checkedIn;

    return _PageScaffold(
      title: event['event_name'] ?? 'Event',
      subtitle: '${event['venue'] ?? '-'} • ${event['event_date'] ?? '-'}',
      action: ElevatedButton.icon(
        onPressed: openAddStudent,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Student'),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _DashboardCard(
                title: 'Participants',
                value: attendees.length.toString(),
                icon: Icons.groups,
              ),
              const SizedBox(width: 16),
              _DashboardCard(
                title: 'Checked In',
                value: checkedIn.toString(),
                icon: Icons.check_circle,
              ),
              const SizedBox(width: 16),
              _DashboardCard(
                title: 'Pending',
                value: pending.toString(),
                icon: Icons.hourglass_top,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: attendees.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final attendee = attendees[index];
                      final seatText = attendee['group_name'] != null
                          ? '${attendee['group_name']} - Seat ${attendee['group_seat_no']}'
                          : attendee['seat_no'] == null
                          ? 'No seat plan'
                          : 'Seat ${attendee['seat_no']}';

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text((index + 1).toString()),
                          ),
                          title: Text(attendee['full_name'] ?? ''),
                          subtitle: Text(
                            '${attendee['student_no'] ?? '-'} • $seatText',
                          ),
                          trailing: Text(
                            attendee['status'] ?? 'Pending',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: attendee['status'] == 'Checked In'
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class AddStudentDialog extends StatefulWidget {
  final Map<String, dynamic> event;

  const AddStudentDialog({super.key, required this.event});

  @override
  State<AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<AddStudentDialog> {
  final api = ApiService();

  final studentNoController = TextEditingController();
  final fullNameController = TextEditingController();

  bool saving = false;

  Future<void> saveStudent() async {
    setState(() => saving = true);

    await api.addAttendee(widget.event['id'], {
      'student_no': studentNoController.text.trim(),
      'full_name': fullNameController.text.trim(),
    });

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Student'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Input(controller: studentNoController, label: 'Student Number'),
            _Input(controller: fullNameController, label: 'Full Name'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: saving ? null : saveStudent,
          child: Text(saving ? 'Saving...' : 'Save Student'),
        ),
      ],
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
  final api = ApiService();
  final eventIdController = TextEditingController(text: '1');
  final studentNoController = TextEditingController();

  bool loading = false;
  String? errorMessage;
  Map<String, dynamic>? result;

  Future<void> register() async {
    final eventId = int.tryParse(eventIdController.text.trim()) ?? 1;
    final studentNo = studentNoController.text.trim();

    setState(() {
      loading = true;
      errorMessage = null;
      result = null;
    });

    try {
      final data = await api.registerStudent(eventId, studentNo);
      setState(() => result = data);
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() => loading = false);
    }
  }

  void reset() {
    setState(() {
      studentNoController.clear();
      result = null;
      errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      title: 'Student Registration',
      subtitle:
          'Students scan QR, enter student number, and get attendance confirmation.',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: result == null
              ? Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.qr_code_2,
                          size: 64,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Register Attendance',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Enter your event ID and student number.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 24),
                        _Input(
                          controller: eventIdController,
                          label: 'Event ID',
                        ),
                        _Input(
                          controller: studentNoController,
                          label: 'Student Number',
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: loading ? null : register,
                            icon: loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: Text(
                              loading ? 'Registering...' : 'Register',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _SuccessCard(data: result!, onReset: reset),
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
    final hasGroup = data['group_name'] != null;
    final hasSeat = data['seat_no'] != null || data['group_seat_no'] != null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: Color(0xFFDCFCE7),
              child: Icon(Icons.check, size: 52, color: Color(0xFF16A34A)),
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
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
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
                  Text(
                    hasGroup
                        ? 'GROUP ASSIGNMENT'
                        : hasSeat
                        ? 'YOUR SEAT NUMBER'
                        : 'ATTENDANCE CONFIRMED',
                    style: const TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (hasGroup) ...[
                    Text(
                      data['group_name'].toString(),
                      style: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Seat ${data['group_seat_no']}',
                      style: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontSize: 46,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ] else if (data['seat_no'] != null) ...[
                    Text(
                      data['seat_no'].toString(),
                      style: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontSize: 68,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Thank you for registering.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.person_add),
              label: const Text('Register another'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  const _PageScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 26),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _DashboardCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 130,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFDBEAFE),
              child: Icon(icon, color: const Color(0xFF2563EB), size: 30),
            ),
            const SizedBox(width: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _Input({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
