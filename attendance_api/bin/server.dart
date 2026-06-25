import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

Future<void> main() async {
  final connection = await openDatabaseConnection();
  await ensureDatabaseSchema(connection);

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware((Handler innerHandler) {
        return (Request request) async {
          if (request.method == 'OPTIONS') {
            return Response.ok(
              '',
              headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods':
                    'GET, POST, PUT, DELETE, OPTIONS',
                'Access-Control-Allow-Headers':
                    'Origin, Content-Type, Accept, Authorization',
              },
            );
          }

          final response = await innerHandler(request);

          return response.change(
            headers: {
              ...response.headers,
              'Access-Control-Allow-Origin': '*',
              'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
              'Access-Control-Allow-Headers':
                  'Origin, Content-Type, Accept, Authorization',
            },
          );
        };
      })
      .addHandler((Request request) async {
        final path = request.url.path;
        final method = request.method;

        if (method == 'GET' && path == 'health') {
          return jsonResponse({'status': 'ok'});
        }

        if (method == 'GET' && path == 'events') {
          return getEvents(connection);
        }

        if (method == 'POST' && path == 'events') {
          return createEvent(connection, request);
        }

        if (method == 'GET' && path.startsWith('events/')) {
          final parts = path.split('/');

          if (parts.length == 2) {
            return getEvent(connection, int.parse(parts[1]));
          }

          if (parts.length == 3 && parts[2] == 'attendees') {
            return getEventAttendees(connection, int.parse(parts[1]));
          }

          if (parts.length == 3 && parts[2] == 'groups') {
            return getEventGroups(connection, int.parse(parts[1]));
          }
        }

        if (method == 'POST' && path.startsWith('events/')) {
          final parts = path.split('/');

          if (parts.length == 3 && parts[2] == 'register') {
            return registerStudentForEvent(
              connection,
              request,
              int.parse(parts[1]),
            );
          }

          if (parts.length == 3 && parts[2] == 'attendees') {
            return addAttendeeToEvent(connection, request, int.parse(parts[1]));
          }

          if (parts.length == 3 && parts[2] == 'groups') {
            return createGroupsForEvent(
              connection,
              request,
              int.parse(parts[1]),
            );
          }
        }

        if (method == 'GET' && path == 'attendees') {
          return getAllAttendees(connection);
        }

        if (method == 'POST' && path == 'student/register') {
          return registerStudentForEvent(connection, request, 1);
        }

        return jsonResponse({'message': 'Route not found'}, statusCode: 404);
      });

  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final server = await shelf_io.serve(handler, '0.0.0.0', port);

  print('Server running at http://${server.address.host}:${server.port}');
}

Future<Connection> openDatabaseConnection() async {
  final databaseUrl = Platform.environment['DATABASE_URL'];

  if (databaseUrl != null && databaseUrl.isNotEmpty) {
    final uri = Uri.parse(databaseUrl);
    final userInfo = uri.userInfo.split(':');

    return Connection.open(
      Endpoint(
        host: uri.host,
        port: uri.hasPort ? uri.port : 5432,
        database: uri.pathSegments.first,
        username: userInfo[0],
        password: userInfo.length > 1 ? userInfo[1] : '',
      ),
      settings: const ConnectionSettings(sslMode: SslMode.require),
    );
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

Future<void> ensureDatabaseSchema(Connection connection) async {
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS events (
      id SERIAL PRIMARY KEY,
      event_name VARCHAR(255) NOT NULL,
      event_date DATE,
      venue VARCHAR(255),
      start_time TIME,
      end_time TIME,
      requires_registration BOOLEAN DEFAULT true,
      requires_seat_plan BOOLEAN DEFAULT false,
      seat_plan_type VARCHAR(20) DEFAULT 'none',
      created_at TIMESTAMP DEFAULT NOW()
    );
  ''');

  await connection.execute('''
    CREATE TABLE IF NOT EXISTS event_groups (
      id SERIAL PRIMARY KEY,
      event_id INT REFERENCES events(id) ON DELETE CASCADE,
      group_name VARCHAR(100) NOT NULL,
      max_members INT NOT NULL,
      created_at TIMESTAMP DEFAULT NOW()
    );
  ''');

  await connection.execute('''
    CREATE TABLE IF NOT EXISTS attendees (
      id SERIAL PRIMARY KEY,
      event_id INT REFERENCES events(id) ON DELETE CASCADE,
      student_no VARCHAR(50),
      seat_no INT,
      full_name VARCHAR(255) NOT NULL,
      status VARCHAR(30) DEFAULT 'Pending',
      group_id INT REFERENCES event_groups(id),
      group_seat_no INT,
      created_at TIMESTAMP DEFAULT NOW()
    );
  ''');

  await connection.execute('''
    CREATE TABLE IF NOT EXISTS attendance_logs (
      id SERIAL PRIMARY KEY,
      event_id INT REFERENCES events(id) ON DELETE CASCADE,
      attendee_id INT REFERENCES attendees(id) ON DELETE CASCADE,
      checked_in_at TIMESTAMP DEFAULT NOW()
    );
  ''');

  await connection.execute('''
  ALTER TABLE attendance_logs
  ADD COLUMN IF NOT EXISTS event_id INT REFERENCES events(id) ON DELETE CASCADE;
  ''');

  await connection.execute('''
  ALTER TABLE attendance_logs
  ADD COLUMN IF NOT EXISTS attendee_id INT REFERENCES attendees(id) ON DELETE CASCADE;
  ''');

  await connection.execute('''
  ALTER TABLE attendance_logs
  ADD COLUMN IF NOT EXISTS checked_in_at TIMESTAMP DEFAULT NOW();
  ''');
}

Response jsonResponse(dynamic data, {int statusCode = 200}) {
  return Response(
    statusCode,
    body: jsonEncode(data),
    headers: {'Content-Type': 'application/json'},
  );
}

Future<Map<String, dynamic>> readJson(Request request) async {
  final body = await request.readAsString();
  if (body.trim().isEmpty) return {};
  return jsonDecode(body) as Map<String, dynamic>;
}

Future<Response> getEvents(Connection connection) async {
  final result = await connection.execute('''
    SELECT 
      id,
      event_name,
      event_date,
      venue,
      start_time,
      end_time,
      requires_registration,
      requires_seat_plan,
      seat_plan_type,
      created_at
    FROM events
    ORDER BY event_date DESC, id DESC
  ''');

  return jsonResponse(
    result.map((row) {
      return {
        'id': row[0],
        'event_name': row[1],
        'event_date': row[2]?.toString(),
        'venue': row[3],
        'start_time': row[4]?.toString(),
        'end_time': row[5]?.toString(),
        'requires_registration': row[6],
        'requires_seat_plan': row[7],
        'seat_plan_type': row[8],
        'created_at': row[9]?.toString(),
      };
    }).toList(),
  );
}

Future<Response> getEvent(Connection connection, int eventId) async {
  final result = await connection.execute(
    Sql.named('''
      SELECT 
        id,
        event_name,
        event_date,
        venue,
        start_time,
        end_time,
        requires_registration,
        requires_seat_plan,
        seat_plan_type,
        created_at
      FROM events
      WHERE id = @id
      LIMIT 1
    '''),
    parameters: {'id': eventId},
  );

  if (result.isEmpty) {
    return jsonResponse({'message': 'Event not found'}, statusCode: 404);
  }

  final row = result.first;

  return jsonResponse({
    'id': row[0],
    'event_name': row[1],
    'event_date': row[2]?.toString(),
    'venue': row[3],
    'start_time': row[4]?.toString(),
    'end_time': row[5]?.toString(),
    'requires_registration': row[6],
    'requires_seat_plan': row[7],
    'seat_plan_type': row[8],
    'created_at': row[9]?.toString(),
  });
}

Future<Response> createEvent(Connection connection, Request request) async {
  final data = await readJson(request);

  final eventName = data['event_name']?.toString().trim() ?? '';
  final eventDate = data['event_date']?.toString().trim();
  final venue = data['venue']?.toString().trim();
  final startTime = data['start_time']?.toString().trim();
  final endTime = data['end_time']?.toString().trim();
  final requiresRegistration = data['requires_registration'] ?? true;
  final requiresSeatPlan = data['requires_seat_plan'] ?? false;
  final seatPlanType = data['seat_plan_type']?.toString() ?? 'none';

  if (eventName.isEmpty) {
    return jsonResponse({'message': 'Event name is required'}, statusCode: 400);
  }

  final result = await connection.execute(
    Sql.named('''
      INSERT INTO events (
        event_name,
        event_date,
        venue,
        start_time,
        end_time,
        requires_registration,
        requires_seat_plan,
        seat_plan_type
      )
      VALUES (
        @event_name,
        @event_date,
        @venue,
        @start_time,
        @end_time,
        @requires_registration,
        @requires_seat_plan,
        @seat_plan_type
      )
      RETURNING id
    '''),
    parameters: {
      'event_name': eventName,
      'event_date': eventDate,
      'venue': venue,
      'start_time': startTime,
      'end_time': endTime,
      'requires_registration': requiresRegistration,
      'requires_seat_plan': requiresSeatPlan,
      'seat_plan_type': seatPlanType,
    },
  );

  return jsonResponse({
    'message': 'Event created',
    'event_id': result.first[0],
  });
}

Future<Response> getEventAttendees(Connection connection, int eventId) async {
  final result = await connection.execute(
    Sql.named('''
      SELECT 
        a.id,
        a.event_id,
        a.student_no,
        a.seat_no,
        a.full_name,
        a.status,
        g.group_name,
        a.group_seat_no,
        a.created_at
      FROM attendees a
      LEFT JOIN event_groups g ON g.id = a.group_id
      WHERE a.event_id = @event_id
      ORDER BY 
        g.group_name NULLS LAST,
        a.group_seat_no NULLS LAST,
        a.seat_no NULLS LAST,
        a.full_name ASC
    '''),
    parameters: {'event_id': eventId},
  );

  return jsonResponse(
    result.map((row) {
      return {
        'id': row[0],
        'event_id': row[1],
        'student_no': row[2],
        'seat_no': row[3],
        'full_name': row[4],
        'status': row[5],
        'group_name': row[6],
        'group_seat_no': row[7],
        'created_at': row[8]?.toString(),
      };
    }).toList(),
  );
}

Future<Response> getAllAttendees(Connection connection) async {
  final result = await connection.execute('''
    SELECT 
      id,
      event_id,
      student_no,
      seat_no,
      full_name,
      status,
      created_at
    FROM attendees
    ORDER BY event_id DESC, seat_no ASC
  ''');

  return jsonResponse(
    result.map((row) {
      return {
        'id': row[0],
        'event_id': row[1],
        'student_no': row[2],
        'seat_no': row[3],
        'full_name': row[4],
        'status': row[5],
        'created_at': row[6]?.toString(),
      };
    }).toList(),
  );
}

Future<Response> addAttendeeToEvent(
  Connection connection,
  Request request,
  int eventId,
) async {
  final data = await readJson(request);

  final studentNo = data['student_no']?.toString().trim() ?? '';
  final fullName = data['full_name']?.toString().trim() ?? '';
  final groupId = data['group_id'];

  if (studentNo.isEmpty || fullName.isEmpty) {
    return jsonResponse({
      'message': 'Student number and full name are required',
    }, statusCode: 400);
  }

  final event = await getEventSettings(connection, eventId);
  if (event == null) {
    return jsonResponse({'message': 'Event not found'}, statusCode: 404);
  }

  int? seatNo;
  int? groupSeatNo;

  if (event.requiresSeatPlan && event.seatPlanType == 'individual') {
    seatNo = await getNextSeatNo(connection, eventId);
  }

  if (event.requiresSeatPlan && event.seatPlanType == 'group') {
    if (groupId == null) {
      return jsonResponse({'message': 'Group is required'}, statusCode: 400);
    }
    groupSeatNo = await getNextGroupSeatNo(connection, groupId as int);
  }

  final result = await connection.execute(
    Sql.named('''
      INSERT INTO attendees (
        event_id,
        student_no,
        seat_no,
        full_name,
        group_id,
        group_seat_no
      )
      VALUES (
        @event_id,
        @student_no,
        @seat_no,
        @full_name,
        @group_id,
        @group_seat_no
      )
      RETURNING id
    '''),
    parameters: {
      'event_id': eventId,
      'student_no': studentNo,
      'seat_no': seatNo,
      'full_name': fullName,
      'group_id': groupId,
      'group_seat_no': groupSeatNo,
    },
  );

  return jsonResponse({
    'message': 'Attendee added',
    'attendee_id': result.first[0],
    'seat_no': seatNo,
    'group_seat_no': groupSeatNo,
  });
}

Future<Response> registerStudentForEvent(
  Connection connection,
  Request request,
  int eventId,
) async {
  final data = await readJson(request);
  final studentNo = data['student_no']?.toString().trim() ?? '';

  if (studentNo.isEmpty) {
    return jsonResponse({
      'message': 'Student number is required',
    }, statusCode: 400);
  }

  final result = await connection.execute(
    Sql.named('''
      SELECT 
        a.id,
        a.student_no,
        a.seat_no,
        a.full_name,
        a.status,
        g.group_name,
        a.group_seat_no
      FROM attendees a
      LEFT JOIN event_groups g ON g.id = a.group_id
      WHERE a.event_id = @event_id
      AND a.student_no = @student_no
      LIMIT 1
    '''),
    parameters: {'event_id': eventId, 'student_no': studentNo},
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
        INSERT INTO attendance_logs (event_id, attendee_id)
        VALUES (@event_id, @attendee_id)
      '''),
      parameters: {'event_id': eventId, 'attendee_id': attendeeId},
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
    'group_name': attendee[5],
    'group_seat_no': attendee[6],
  });
}

Future<Response> createGroupsForEvent(
  Connection connection,
  Request request,
  int eventId,
) async {
  final data = await readJson(request);

  final numberOfGroups = int.tryParse(data['number_of_groups'].toString()) ?? 0;
  final membersPerGroup =
      int.tryParse(data['members_per_group'].toString()) ?? 0;
  final naming = data['naming']?.toString() ?? 'numeric';

  if (numberOfGroups <= 0 || membersPerGroup <= 0) {
    return jsonResponse({
      'message': 'Number of groups and members per group are required',
    }, statusCode: 400);
  }

  await connection.execute(
    Sql.named('DELETE FROM event_groups WHERE event_id = @event_id'),
    parameters: {'event_id': eventId},
  );

  for (var i = 1; i <= numberOfGroups; i++) {
    final groupName = naming == 'alphabet'
        ? String.fromCharCode(64 + i)
        : 'Group $i';

    await connection.execute(
      Sql.named('''
        INSERT INTO event_groups (event_id, group_name, max_members)
        VALUES (@event_id, @group_name, @max_members)
      '''),
      parameters: {
        'event_id': eventId,
        'group_name': groupName,
        'max_members': membersPerGroup,
      },
    );
  }

  return jsonResponse({
    'message': 'Groups created',
    'number_of_groups': numberOfGroups,
    'members_per_group': membersPerGroup,
  });
}

Future<Response> getEventGroups(Connection connection, int eventId) async {
  final result = await connection.execute(
    Sql.named('''
      SELECT id, event_id, group_name, max_members, created_at
      FROM event_groups
      WHERE event_id = @event_id
      ORDER BY id ASC
    '''),
    parameters: {'event_id': eventId},
  );

  return jsonResponse(
    result.map((row) {
      return {
        'id': row[0],
        'event_id': row[1],
        'group_name': row[2],
        'max_members': row[3],
        'created_at': row[4]?.toString(),
      };
    }).toList(),
  );
}

Future<EventSettings?> getEventSettings(
  Connection connection,
  int eventId,
) async {
  final result = await connection.execute(
    Sql.named('''
      SELECT requires_seat_plan, seat_plan_type
      FROM events
      WHERE id = @id
      LIMIT 1
    '''),
    parameters: {'id': eventId},
  );

  if (result.isEmpty) return null;

  return EventSettings(
    requiresSeatPlan: result.first[0] == true,
    seatPlanType: result.first[1]?.toString() ?? 'none',
  );
}

Future<int> getNextSeatNo(Connection connection, int eventId) async {
  final result = await connection.execute(
    Sql.named('''
      SELECT COALESCE(MAX(seat_no), 0) + 1
      FROM attendees
      WHERE event_id = @event_id
    '''),
    parameters: {'event_id': eventId},
  );

  return result.first[0] as int;
}

Future<int> getNextGroupSeatNo(Connection connection, int groupId) async {
  final result = await connection.execute(
    Sql.named('''
      SELECT COALESCE(MAX(group_seat_no), 0) + 1
      FROM attendees
      WHERE group_id = @group_id
    '''),
    parameters: {'group_id': groupId},
  );

  return result.first[0] as int;
}

class EventSettings {
  final bool requiresSeatPlan;
  final String seatPlanType;

  EventSettings({required this.requiresSeatPlan, required this.seatPlanType});
}
