import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

Future<void> main() async {
  final connection = await Connection.open(
    Endpoint(
      host: 'localhost',
      port: 5432,
      database: 'attendance_db',
      username: 'postgres',
      password: 'Postgre123!',
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler((Request request) async {
        final path = request.url.path;
        final method = request.method;

        if (method == 'GET' && path == 'attendees') {
          return getAttendees(connection);
        }

        if (method == 'GET' && path == 'attendees/search') {
          final name = request.url.queryParameters['name'] ?? '';
          return searchAttendees(connection, name);
        }

        if (method == 'POST' && path == 'student/register') {
          final body = await request.readAsString();
          final data = jsonDecode(body) as Map<String, dynamic>;
          final studentNo = data['student_no'].toString();

          return registerStudent(connection, studentNo);
        }

        if (method == 'POST' && path == 'attendance/check-in') {
          final body = await request.readAsString();
          final data = jsonDecode(body) as Map<String, dynamic>;
          final attendeeId = data['attendee_id'] as int;

          return checkIn(connection, attendeeId);
        }

        return Response.notFound(
          jsonEncode({'message': 'Route not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      });

  final server = await shelf_io.serve(handler, '0.0.0.0', 8080);

  print('Server running at http://${server.address.host}:${server.port}');
}

Future<Response> getAttendees(Connection connection) async {
  final result = await connection.execute('''
    SELECT id, event_id, seat_no, full_name, status, created_at
    FROM attendees
    ORDER BY seat_no ASC
    ''');

  final attendees = result.map((row) {
    return {
      'id': row[0],
      'event_id': row[1],
      'seat_no': row[2],
      'full_name': row[3],
      'status': row[4],
      'created_at': row[5].toString(),
    };
  }).toList();

  return Response.ok(
    jsonEncode(attendees),
    headers: {'Content-Type': 'application/json'},
  );
}

Future<Response> searchAttendees(Connection connection, String name) async {
  final result = await connection.execute(
    Sql.named('''
      SELECT id, event_id, seat_no, full_name, status, created_at
      FROM attendees
      WHERE full_name ILIKE @name
      ORDER BY seat_no ASC
    '''),
    parameters: {'name': '%$name%'},
  );

  final attendees = result.map((row) {
    return {
      'id': row[0],
      'event_id': row[1],
      'seat_no': row[2],
      'full_name': row[3],
      'status': row[4],
      'created_at': row[5].toString(),
    };
  }).toList();

  return Response.ok(
    jsonEncode(attendees),
    headers: {'Content-Type': 'application/json'},
  );
}

Future<Response> checkIn(Connection connection, int attendeeId) async {
  final attendeeResult = await connection.execute(
    Sql.named('''
      SELECT id, seat_no, full_name, status
      FROM attendees
      WHERE id = @id
      LIMIT 1
    '''),
    parameters: {'id': attendeeId},
  );

  if (attendeeResult.isEmpty) {
    return Response.notFound(
      jsonEncode({'message': 'Attendee not found'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final attendee = attendeeResult.first;
  final status = attendee[3].toString();

  if (status == 'Checked In') {
    return Response.ok(
      jsonEncode({
        'message': 'Already checked in',
        'id': attendee[0],
        'seat_no': attendee[1],
        'full_name': attendee[2],
        'status': attendee[3],
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  await connection.execute(
    Sql.named('''
      INSERT INTO attendance_logs (attendee_id)
      VALUES (@attendee_id)
    '''),
    parameters: {'attendee_id': attendeeId},
  );

  await connection.execute(
    Sql.named('''
      UPDATE attendees
      SET status = 'Checked In'
      WHERE id = @id
    '''),
    parameters: {'id': attendeeId},
  );

  return Response.ok(
    jsonEncode({
      'message': 'Attendance recorded',
      'id': attendee[0],
      'seat_no': attendee[1],
      'full_name': attendee[2],
      'status': 'Checked In',
    }),
    headers: {'Content-Type': 'application/json'},
  );
}

Future<Response> registerStudent(
  Connection connection,
  String studentNo,
) async {
  final result = await connection.execute(
    Sql.named('''
      SELECT id, student_no, seat_no, full_name, status
      FROM attendees
      WHERE student_no = @student_no
      LIMIT 1
    '''),
    parameters: {'student_no': studentNo},
  );

  if (result.isEmpty) {
    return Response.notFound(
      jsonEncode({'message': 'Student number not found'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final attendee = result.first;
  final attendeeId = attendee[0];
  final status = attendee[4].toString();

  if (status != 'Checked In') {
    await connection.execute(
      Sql.named('''
        INSERT INTO attendance_logs (attendee_id)
        VALUES (@attendee_id)
      '''),
      parameters: {'attendee_id': attendeeId},
    );

    await connection.execute(
      Sql.named('''
        UPDATE attendees
        SET status = 'Checked In'
        WHERE id = @id
      '''),
      parameters: {'id': attendeeId},
    );
  }

  return Response.ok(
    jsonEncode({
      'message': status == 'Checked In'
          ? 'Already registered'
          : 'Registration successful',
      'student_no': attendee[1],
      'seat_no': attendee[2],
      'full_name': attendee[3],
      'status': 'Checked In',
    }),
    headers: {'Content-Type': 'application/json'},
  );
}
