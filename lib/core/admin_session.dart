import 'package:flutter_dotenv/flutter_dotenv.dart';

class AdminSession {
  static const String _configuredAdminKey = String.fromEnvironment(
    'ADMIN_SECRET',
    defaultValue: '',
  );
  static const String _loginPasscode = String.fromEnvironment(
    'ADMIN_PASSCODE',
    defaultValue: '',
  );
  static const bool _allowInsecureDefaults = bool.fromEnvironment(
    'ALLOW_INSECURE_ADMIN',
    defaultValue: false,
  );

  static String? adminKey;

  static bool get isLoggedIn => (adminKey ?? '').isNotEmpty;

  static String? get configurationError {
    final envKey = dotenv.env['ADMIN_SECRET'];
    final envPasscode = dotenv.env['ADMIN_PASSCODE'];
    final hasDartDefine =
        _configuredAdminKey.isNotEmpty &&
        _loginPasscode.isNotEmpty &&
        _configuredAdminKey != 'PLACEHOLDER' &&
        _loginPasscode != 'PLACEHOLDER';
    final hasDotEnv =
        (envKey ?? '').isNotEmpty && (envPasscode ?? '').isNotEmpty;

    if (hasDartDefine || hasDotEnv || _allowInsecureDefaults) {
      return null;
    }

    return 'Admin access is not configured.';
  }

  static bool login(String passcode) {
    final configuredKey =
        _configuredAdminKey.isNotEmpty &&
                _configuredAdminKey != 'PLACEHOLDER'
            ? _configuredAdminKey
            : (dotenv.env['ADMIN_SECRET'] ?? '');
    final configuredPasscode =
        _loginPasscode.isNotEmpty &&
                _loginPasscode != 'PLACEHOLDER'
            ? _loginPasscode
            : (dotenv.env['ADMIN_PASSCODE'] ?? '');

    final fallbackKey = _allowInsecureDefaults ? '1234' : '';
    final fallbackPasscode = _allowInsecureDefaults ? '1234' : '';
    final resolvedKey = configuredKey.isNotEmpty ? configuredKey : fallbackKey;
    final resolvedPasscode =
        configuredPasscode.isNotEmpty ? configuredPasscode : fallbackPasscode;

    if (resolvedKey.isEmpty || resolvedPasscode.isEmpty) {
      return false;
    }
    if (passcode != resolvedPasscode) {
      return false;
    }

    adminKey = resolvedKey;
    return true;
  }

  static void logout() {
    adminKey = null;
  }
}
