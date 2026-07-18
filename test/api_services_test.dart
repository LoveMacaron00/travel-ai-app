import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/services/api_client.dart';
import 'package:myapp/services/activity_service.dart';
import 'package:myapp/services/auth_service.dart';
import 'package:myapp/services/destination_service.dart';
import 'package:myapp/services/session_store.dart';

class _MemorySessionStore implements SessionStore {
  StoredSession stored = const StoredSession();

  @override
  Future<StoredSession> load() async => stored;

  @override
  Future<void> save(String token, Map<String, dynamic> user) async {
    stored = StoredSession(token: token, user: user);
  }

  @override
  Future<void> saveUser(Map<String, dynamic> user) async {
    stored = StoredSession(token: stored.token, user: user);
  }

  @override
  Future<void> clear() async => stored = const StoredSession();
}

void main() {
  group('ApiClient media policy', () {
    late SessionState session;
    late ApiClient client;

    setUp(() {
      session = SessionState()..token = 'user-token';
      client = ApiClient(
        baseUrl: 'https://api.example.com/api',
        tokenProvider: () => session.token,
      );
    });

    test('sends token only to private uploads on the API origin', () {
      expect(
        client.mediaHeaders('https://api.example.com/uploads/profile.jpg'),
        {'Authorization': 'Bearer user-token'},
      );
      expect(
        client.mediaHeaders('https://images.tat.or.th/place.jpg'),
        isEmpty,
      );
      expect(client.mediaHeaders('/uploads/profile.jpg'), {
        'Authorization': 'Bearer user-token',
      });
    });
  });

  test('ApiClient sends the selected locale as Accept-Language', () async {
    var languageCode = 'th';
    final requests = <http.Request>[];
    final client = ApiClient(
      baseUrl: 'https://api.example.com/api',
      tokenProvider: () => null,
      languageProvider: () => languageCode,
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('{}', 200);
      }),
    );

    await client.get('/v2/places');
    languageCode = 'en';
    await client.get('/v2/places/123');

    expect(requests[0].headers['Accept-Language'], 'th');
    expect(requests[1].headers['Accept-Language'], 'en');
  });

  test(
    'DestinationService caches by language and serves limited views',
    () async {
      var requests = 0;
      var languageCode = 'th';
      final client = ApiClient(
        baseUrl: 'https://api.example.com/api',
        tokenProvider: () => null,
        languageProvider: () => languageCode,
        httpClient: MockClient((request) async {
          requests++;
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 1},
                {'id': 2},
                {'id': 3},
              ],
            }),
            200,
          );
        }),
      );
      final service = DestinationService(client: client);

      final full = await service.getDestinations();
      final limited = await service.getDestinations(limit: 2);
      languageCode = 'en';
      final english = await service.getDestinations();

      expect(full['success'], isTrue);
      expect((limited['data'] as List), hasLength(2));
      expect(limited['cached'], isTrue);
      expect(english['cached'], isNot(true));
      expect(requests, 2);
    },
  );

  test(
    'AuthService persists a successful login through its store boundary',
    () async {
      final session = SessionState();
      final store = _MemorySessionStore();
      final client = ApiClient(
        baseUrl: 'https://api.example.com/api',
        tokenProvider: () => session.token,
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/users/login');
          return http.Response(
            jsonEncode({
              'token': 'signed-token',
              'user': {'id': 7, 'email': 'traveler@example.com'},
            }),
            200,
          );
        }),
      );
      final service = AuthService(
        client: client,
        session: session,
        store: store,
      );

      final result = await service.login(
        email: 'traveler@example.com',
        password: 'secret',
      );

      expect(result['success'], isTrue);
      expect(session.token, 'signed-token');
      expect(store.stored.user?['id'], 7);
    },
  );

  test('ActivityService reuses the heartbeat session and closes it', () async {
    final requests = <Map<String, dynamic>>[];
    final client = ApiClient(
      baseUrl: 'https://api.example.com/api',
      tokenProvider: () => 'user-token',
      httpClient: MockClient((request) async {
        final body = request.body.isEmpty
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(jsonDecode(request.body));
        requests.add({'path': request.url.path, 'body': body});

        if (request.url.path.endsWith('/heartbeat')) {
          return http.Response(jsonEncode({'sessionId': 42}), 200);
        }
        if (request.url.path.endsWith('/view')) {
          return http.Response(jsonEncode({'recorded': true}), 201);
        }
        return http.Response('', 204);
      }),
    );
    final service = ActivityService(
      client: client,
      isAuthenticated: () => true,
      heartbeatInterval: const Duration(hours: 1),
    );

    await service.resume();
    final recorded = await service.recordDestinationView(7);
    await service.pause();

    expect(recorded, isTrue);
    expect(requests, [
      {'path': '/api/activity/heartbeat', 'body': <String, dynamic>{}},
      {
        'path': '/api/mobile/destinations/7/view',
        'body': {'sessionId': 42},
      },
      {
        'path': '/api/activity/end',
        'body': {'sessionId': 42},
      },
    ]);
  });
}
