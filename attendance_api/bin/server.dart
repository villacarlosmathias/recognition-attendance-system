import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

Future<void> main() async {
  final connection = await openDatabaseConnection();

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler((Request request) async {
        final path = request.url.path;
        final method = request.method;

        if (method == 'GET' && path == 'health') {
          return jsonResponse({'status': 'ok'});
        }

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
          final studentNo = data['student_no'].toString().trim();

          return registerStudent(connection, studentNo);
        }

        if (method == 'POST' && path == 'attendance/check-in') {
          final body = await request.readAsString();
          final data = jsonDecode(body) as Map<String, dynamic>;
          final attendeeId = data['attendee_id'] as int;

          return checkIn(connection, attendeeId);
        }

        return jsonResponse({'message': 'Route not found'}, statusCode: 404);
      });

  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final server = await shelf_io.serve(handler, '0.0.0.0', port);

  print('Server running at http://${server.address.host}:${server.port}');
}

Future<Connection> openDatabaseConnection() async {
  final databaseUrl = Platform.environment['DATABASE_URL'];
  final isRender = Platform.environment['RENDER'] == 'true';

  if (databaseUrl != null && databaseUrl.isNotEmpty) {
    final uri = Uri.parse(databaseUrl);
    final userInfo = uri.userInfo.split(':');

    return Connection.open(
      Endpoint(
        host: uri.host,
        port: uri.hasPort ? uri.port : 5432,
        database: uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '',
        username: userInfo.isNotEmpty ? userInfo[0] : '',
        password: userInfo.length > 1 ? userInfo[1] : '',
      ),
      settings: const ConnectionSettings(sslMode: SslMode.require),
    );
  }

  if (isRender) {
    throw Exception('DATABASE_URL is missing in Render Environment Variables.');
  }

  return Connection.open(
    Endpoint(
      host: 'localhost',
      port: 5432,
      database: 'attendance_db',
      username: 'postgres',
      password: 'Postgre123!',
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );
}

Response jsonResponse(Map<String, dynamic> data, {int statusCode = 200}) {
  return Response(
    statusCode,
    body: jsonEncode(data),
    headers: {'Content-Type': 'application/json'},
  );
}

Future<Response> getAttendees(Connection connection) async {
  final result = await connection.execute('''
    SELECT id, event_id, student_no, seat_no, full_name, status, created_at
    FROM attendees
    ORDER BY seat_no ASC
  ''');

  final attendees = result.map((row) {
    return {
      'id': row[0],
      'event_id': row[1],
      'student_no': row[2],
      'seat_no': row[3],
      'full_name': row[4],
      'status': row[5],
      'created_at': row[6].toString(),
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
      SELECT id, event_id, student_no, seat_no, full_name, status, created_at
      FROM attendees
      WHERE full_name ILIKE @name OR student_no ILIKE @name
      ORDER BY seat_no ASC
    '''),
    parameters: {'name': '%$name%'},
  );

  final attendees = result.map((row) {
    return {
      'id': row[0],
      'event_id': row[1],
      'student_no': row[2],
      'seat_no': row[3],
      'full_name': row[4],
      'status': row[5],
      'created_at': row[6].toString(),
    };
  }).toList();

  return Response.ok(
    jsonEncode(attendees),
    headers: {'Content-Type': 'application/json'},
  );
}

Future<Response> registerStudent(
  Connection connection,
  String studentNo,
) async {
  if (studentNo.isEmpty) {
    return jsonResponse({
      'message': 'Student number is required',
    }, statusCode: 400);
  }

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
    return jsonResponse({
      'message': 'Student number not found',
    }, statusCode: 404);
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

  return jsonResponse({
    'message': status == 'Checked In'
        ? 'Already registered'
        : 'Registration successful',
    'student_no': attendee[1],
    'seat_no': attendee[2],
    'full_name': attendee[3],
    'status': 'Checked In',
  });
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
    return jsonResponse({'message': 'Attendee not found'}, statusCode: 404);
  }

  final attendee = attendeeResult.first;
  final status = attendee[3].toString();

  if (status == 'Checked In') {
    return jsonResponse({
      'message': 'Already checked in',
      'id': attendee[0],
      'seat_no': attendee[1],
      'full_name': attendee[2],
      'status': attendee[3],
    });
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

  return jsonResponse({
    'message': 'Attendance recorded',
    'id': attendee[0],
    'seat_no': attendee[1],
    'full_name': attendee[2],
    'status': 'Checked In',
  });
}
