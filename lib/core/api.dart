import 'dart:convert';

import 'package:http/http.dart' as http;

/// Default server address. Override at build time:
///   --dart-define=API_BASE_URL=https://your-server
/// or at run time on the sign-in screen (saved on the device).
const kDefaultApiBase = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080');

class ApiException implements Exception {
  ApiException(this.message, [this.status]);
  final String message;
  final int? status;
  @override
  String toString() => message;
}

/// Thin REST client for the Spring Boot backend (bellavistaerp).
class ApiClient {
  ApiClient(String base) : base = base.trim().replaceAll(RegExp(r'/+$'), '');
  final String base;

  Uri _u(String path, [Map<String, String?>? q]) {
    final uri = Uri.parse('$base/api/procurement$path');
    final params = <String, String>{
      if (q != null)
        for (final e in q.entries)
          if (e.value != null && e.value!.trim().isNotEmpty) e.key: e.value!.trim(),
    };
    return params.isEmpty ? uri : uri.replace(queryParameters: params);
  }

  static const _h = {'Content-Type': 'application/json', 'Accept': 'application/json'};

  dynamic _decode(http.Response r) {
    dynamic body;
    if (r.body.isNotEmpty) {
      try {
        body = jsonDecode(utf8.decode(r.bodyBytes));
      } catch (_) {
        body = r.body;
      }
    }
    if (r.statusCode >= 400) {
      String msg = 'Request failed (${r.statusCode}).';
      if (body is Map) {
        final m = body['message'] ?? body['detail'] ?? body['error'];
        if (m != null && '$m'.trim().isNotEmpty) msg = '$m';
        if (r.statusCode == 500 && body['message'] == null) {
          msg = 'The server returned an error (500). Apply the backend patch (see the instructions).';
        }
      }
      throw ApiException(msg, r.statusCode);
    }
    return body;
  }

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Cannot reach the server at $base. Is the backend running? ($e)');
    }
  }

  Future<dynamic> get(String path, {Map<String, String?>? query}) =>
      _guard(() async => _decode(await http.get(_u(path, query), headers: _h)));

  Future<dynamic> post(String path, {Map<String, String?>? query, Object? body}) => _guard(() async =>
      _decode(await http.post(_u(path, query), headers: _h, body: body == null ? null : jsonEncode(body))));

  Future<dynamic> put(String path, {Map<String, String?>? query, Object? body}) => _guard(() async =>
      _decode(await http.put(_u(path, query), headers: _h, body: body == null ? null : jsonEncode(body))));

  Future<dynamic> patch(String path, {Map<String, String?>? query}) =>
      _guard(() async => _decode(await http.patch(_u(path, query), headers: _h)));
}
