import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_browser/local_server.dart';

void main() {
  test('local server serves only its declared sites and supports restart', () async {
    final dir = await Directory.systemTemp.createTemp('manager-sites-test-');
    final site = Directory('${dir.path}/custom_search_page');
    await site.create();
    await File('${site.path}/index.html').writeAsString('<h1>Local site</h1>');
    await File('${dir.path}/private.txt').writeAsString('private');
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();
    final server = LocalSiteServer();
    final client = HttpClient();
    addTearDown(() async { client.close(force: true); await server.stop(); await dir.delete(recursive: true); });
    await server.start(dir.path, port);
    expect(server.running, isTrue);
    expect(server.port, port);
    Future<HttpClientResponse> get(String path) async => (await client.getUrl(Uri.parse('http://127.0.0.1:$port$path'))).close();
    final response = await get('/custom_search_page/');
    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.value('x-content-type-options'), 'nosniff');
    expect(await response.transform(utf8.decoder).join(), '<h1>Local site</h1>');
    for (final path in ['/private.txt', '/noteview/missing.html', '/unregistered/']) {
      final missing = await get(path);
      expect(missing.statusCode, HttpStatus.notFound);
      await missing.drain<void>();
    }
    Future<String> raw(String path) async {
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
      socket.write('GET $path HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n');
      final response = await utf8.decoder.bind(socket).join();
      socket.destroy();
      return response.split('\r\n').first;
    }
    for (final path in ['/custom_search_page/%2e%2e/private.txt', '/custom_search_page/%2fprivate.txt', '/custom_search_page/%5cprivate.txt']) {
      expect(await raw(path), contains(' 404 '));
    }
    final outside = await Directory.systemTemp.createTemp('manager-sites-outside-');
    addTearDown(() => outside.delete(recursive: true));
    await File('${outside.path}/secret.txt').writeAsString('outside root');
    await Link('${site.path}/outside').create(outside.path);
    expect(await raw('/custom_search_page/outside/secret.txt'), contains(' 404 '));
    await expectLater(server.start(dir.path, port), throwsA(isA<FileSystemException>()));
    await server.stop();
    expect(server.running, isFalse);
    expect(server.port, isNull);
    await server.start(dir.path, port);
    expect(server.running, isTrue);
  });
  test('local server rejects invalid ports and missing directories', () async {
    final server = LocalSiteServer();
    await expectLater(server.start('/missing', 80), throwsFormatException);
    await expectLater(server.start('/missing-manager-sites-directory', 8080), throwsA(isA<FileSystemException>()));
    await server.stop();
    expect(server.running, isFalse);
  });
}
