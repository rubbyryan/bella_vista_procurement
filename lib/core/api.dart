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
///
/// Paths are relative to /api/procurement (e.g. '/users'). A path that already
/// starts with '/api/' is used as given (e.g. '/api/auth/login').
/// When a [token] is set it is sent as `Authorization: Bearer <token>`.
class ApiClient {
  ApiClient(String base, {this.token, this.onUnauthorized}) : base = base.trim().replaceAll(RegExp(r'/+$'), '');
  final String base;
  final String? token;

  /// Called when the server answers 401 to a request that carried a token
  /// (expired or invalid token), so the app can sign the user out.
  final void Function()? onUnauthorized;

  Uri _u(String path, [Map<String, String?>? q]) {
    final prefix = path.startsWith('/api/') ? '' : '/api/procurement';
    final uri = Uri.parse('$base$prefix$path');
    final params = <String, String>{
      if (q != null)
        for (final e in q.entries)
          if (e.value != null && e.value!.trim().isNotEmpty) e.key: e.value!.trim(),
    };
    return params.isEmpty ? uri : uri.replace(queryParameters: params);
  }

  Map<String, String> get _h => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  dynamic _decode(http.Response r) {
    dynamic body;
    if (r.body.isNotEmpty) {
      try {
        body = jsonDecode(utf8.decode(r.bodyBytes));
      } catch (_) {
        if (r.statusCode < 400) {
          throw ApiException(
              'The server sent a reply the app cannot read (invalid JSON). Check the backend console for an error.',
              r.statusCode);
        }
        body = r.body;
      }
    }
    if (r.statusCode >= 400) {
      if (r.statusCode == 401 && token != null && token!.isNotEmpty) {
        onUnauthorized?.call();
        throw ApiException('Your session has expired. Please sign in again.', 401);
      }
      String? msg;
      if (body is Map) {
        for (final k in ['message', 'detail', 'error']) {
          final v = body[k];
          if (v != null && '$v'.trim().isNotEmpty) {
            msg = '$v';
            break;
          }
        }
      }
      msg ??= switch (r.statusCode) {
        401 => 'Not signed in.',
        403 => 'You do not have permission to do that (or your session has expired).',
        404 => 'Not found.',
        500 => 'The server returned an error (500).',
        _ => 'Request failed (${r.statusCode}).',
      };
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

  Future<dynamic> delete(String path, {Map<String, String?>? query}) =>
      _guard(() async => _decode(await http.delete(_u(path, query), headers: _h)));

  /// Connection check that needs no login: the Swagger JSON is public.
  /// On Flutter web this also proves the browser is allowed to call the server (CORS).
  Future<void> ping() => _guard(() async {
    final r = await http.get(Uri.parse('$base/v3/api-docs'), headers: {'Accept': 'application/json'});
    if (r.statusCode >= 400) {
      throw ApiException('The server answered ${r.statusCode} for /v3/api-docs.', r.statusCode);
    }
  });
}