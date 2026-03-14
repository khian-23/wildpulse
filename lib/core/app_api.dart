import 'package:http/http.dart' as http;

import 'admin_session.dart';

class AppApi {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.wildpulse.ink/api',
  );

  static const String deviceId = 'wildpulse-001';

  static Uri uri(String path, [Map<String, String>? queryParameters]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse(
      '$baseUrl$normalizedPath',
    ).replace(queryParameters: queryParameters);
  }

  static Map<String, String> adminHeaders([Map<String, String>? extra]) {
    return {
      if ((AdminSession.adminKey ?? '').isNotEmpty)
        'x-admin-key': AdminSession.adminKey!,
      ...?extra,
    };
  }

  static Map<String, String> reportQuery([Map<String, String>? extra]) {
    return {
      'tzOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes.toString(),
      ...?extra,
    };
  }

  static Future<http.Response> getAdmin(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    return http.get(uri(path, queryParameters), headers: adminHeaders());
  }

  static Future<http.Response> postAdmin(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return http.post(uri(path), headers: adminHeaders(headers), body: body);
  }

  static Future<http.Response> patchAdmin(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return http.patch(uri(path), headers: adminHeaders(headers), body: body);
  }
}
