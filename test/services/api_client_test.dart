import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/services/api_client.dart';

void main() {
  test('normalizes the API URL and builds endpoint URIs', () {
    final client = ApiClient(
      baseUrl: ' http://localhost:5000/api/ ',
      tokenProvider: () => 'token',
    );

    expect(client.baseUrl, 'http://localhost:5000/api');
    expect(
      client.uri('/users/login'),
      Uri.parse('http://localhost:5000/api/users/login'),
    );
    expect(client.headers()['Authorization'], 'Bearer token');
  });

  test('rejects an invalid API URL early with a useful error', () {
    expect(
      () => ApiClient(baseUrl: '', tokenProvider: () => null),
      throwsArgumentError,
    );
    expect(
      () => ApiClient(baseUrl: '/api', tokenProvider: () => null),
      throwsArgumentError,
    );
  });
}
