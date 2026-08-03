import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/services/api_client.dart';
import 'package:myapp/services/media_service.dart';

void main() {
  final client = ApiClient(
    baseUrl: 'http://localhost:5000/api',
    tokenProvider: () => 'token',
  );

  test('routes external Web images through the API media proxy', () {
    final media = MediaService(client: client, useWebProxy: true);
    const source = 'https://dmc.tatdataapi.io/assets/photo.jpeg';

    final proxied = Uri.parse(media.fullUrl(source));

    expect(proxied.origin, 'http://localhost:5000');
    expect(proxied.path, '/api/mobile/media');
    expect(proxied.queryParameters['url'], source);
    expect(media.headersFor(proxied.toString()), isEmpty);
  });

  test('keeps same-origin private media URLs and their auth header', () {
    final media = MediaService(client: client, useWebProxy: true);

    final resolved = media.fullUrl('/uploads/profile.jpg');

    expect(resolved, 'http://localhost:5000/uploads/profile.jpg');
    expect(media.headersFor(resolved), {'Authorization': 'Bearer token'});
  });

  test('drops documentation-only placeholder image URLs', () {
    final media = MediaService(client: client, useWebProxy: true);

    expect(media.fullUrl('https://example.com/invented.jpg'), isEmpty);
    expect(media.fullUrl('https://images.example.org/invented.jpg'), isEmpty);
  });
}
