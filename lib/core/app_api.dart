import 'package:http/http.dart' as http;

import 'admin_session.dart';

class AppApi {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.wildpulse.ink/api',
  );
  static const String _fallbackBaseUrlsRaw = String.fromEnvironment(
    'API_BASE_URL_FALLBACKS',
    defaultValue: 'https://wildpulse-backend-production.up.railway.app/api',
  );
  static final List<String> _fallbackBaseUrls =
      _normalizeBaseUrls(_fallbackBaseUrlsRaw);
  static String _activeBaseUrl = _normalizeBaseUrl(baseUrl);

  static String resolveBaseUrl() {
    return _activeBaseUrl;
  }

  static List<String> get fallbackBaseUrls =>
      List.unmodifiable(_fallbackBaseUrls);

  static const String deviceId = 'wildpulse-001';

  static Uri uri(String path, [Map<String, String>? queryParameters]) {
    return _buildUri(_activeBaseUrl, path, queryParameters);
  }

  static Uri _buildUri(
    String baseUrl,
    String path,
    Map<String, String>? queryParameters,
  ) {
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
    return _sendWithFallback(
      (baseUrl) =>
          http.get(_buildUri(baseUrl, path, queryParameters), headers: adminHeaders()),
    );
  }

  static Future<http.Response> postAdmin(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _sendWithFallback(
      (baseUrl) =>
          http.post(_buildUri(baseUrl, path, null), headers: adminHeaders(headers), body: body),
    );
  }

  static Future<http.Response> patchAdmin(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _sendWithFallback(
      (baseUrl) =>
          http.patch(_buildUri(baseUrl, path, null), headers: adminHeaders(headers), body: body),
    );
  }

  static Future<http.Response> _sendWithFallback(
    Future<http.Response> Function(String baseUrl) sender,
  ) async {
    final candidates = <String>[
      _activeBaseUrl,
      ..._fallbackBaseUrls.where((base) => base != _activeBaseUrl),
    ];
    Object? lastError;
    for (final baseUrl in candidates) {
      try {
        final response = await sender(baseUrl);
        _activeBaseUrl = baseUrl;
        return response;
      } catch (error) {
        if (_isDnsFailure(error)) {
          lastError = error;
          continue;
        }
        rethrow;
      }
    }
    throw Exception(
      lastError == null
          ? 'All API base URLs failed'
          : 'All API base URLs failed: $lastError',
    );
  }

  static bool _isDnsFailure(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('failed host lookup') ||
        message.contains('no address associated with hostname') ||
        message.contains('name resolution') ||
        message.contains('temporary failure in name resolution');
  }

  static String _normalizeBaseUrl(String baseUrl) {
    var trimmed = baseUrl.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  static List<String> _normalizeBaseUrls(String raw) {
    if (raw.trim().isEmpty) {
      return [];
    }
    final parts = raw
        .split(',')
        .map(_normalizeBaseUrl)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    return parts;
  }
}
