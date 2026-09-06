import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'models.dart';

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

class ChatApi {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);
  String server = 'http://localhost:8080';
  String? token;

  static String normalizeServer(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw ApiException(
        'Вкажіть адресу сервера, наприклад https://chat.example.com',
      );
    }
    return uri.replace(path: '').toString().replaceFirst(RegExp(r'/$'), '');
  }

  Future<dynamic> request(String method, String path, [Json? body]) async {
    try {
      final req = await _client
          .openUrl(method, Uri.parse('$server$path'))
          .timeout(const Duration(seconds: 12));
      req.headers.contentType = ContentType.json;
      if (token != null) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) req.write(jsonEncode(body));
      final response = await req.close().timeout(const Duration(seconds: 15));
      final raw = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
      dynamic data;
      try {
        data = jsonDecode(raw);
      } catch (_) {
        throw ApiException(
          'За цією адресою немає сервера Spayr',
          response.statusCode,
        );
      }
      if (response.statusCode >= 400) {
        throw ApiException(
          data is Map
              ? (data['error'] ?? 'Помилка сервера')
              : 'Помилка сервера',
          response.statusCode,
        );
      }
      return data;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Сервер не відповідає. Перевірте з’єднання.');
    } on HandshakeException {
      throw ApiException('Не вдалося перевірити HTTPS-сертифікат сервера.');
    } on SocketException {
      throw ApiException(
        'Не вдалося підключитися до сервера. Перевірте адресу та мережу.',
      );
    } on HttpException {
      throw ApiException('З’єднання перервано. Спробуйте знову.');
    }
  }

  Future<WebSocket> connect() async {
    final uri = Uri.parse(
      server,
    ).replace(scheme: server.startsWith('https:') ? 'wss' : 'ws', path: '/ws');
    final ws = await WebSocket.connect(
      uri.toString(),
      headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
    ).timeout(const Duration(seconds: 12));
    ws.pingInterval = const Duration(seconds: 20);
    return ws;
  }

  void dispose() => _client.close(force: true);
}
