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
    if (_allowInsecureDefaults) {
      return null;
    }
    if (_configuredAdminKey.isEmpty || _loginPasscode.isEmpty) {
      return 'Admin access is not configured.';
    }
    return null;
  }

  static bool login(String passcode) {
    final configuredKey =
        _configuredAdminKey.isNotEmpty
            ? _configuredAdminKey
            : (_allowInsecureDefaults ? '1234' : '');
    final configuredPasscode =
        _loginPasscode.isNotEmpty
            ? _loginPasscode
            : (_allowInsecureDefaults ? '1234' : '');

    if (configuredKey.isEmpty || configuredPasscode.isEmpty) {
      return false;
    }
    if (passcode != configuredPasscode) {
      return false;
    }

    adminKey = configuredKey;
    return true;
  }

  static void logout() {
    adminKey = null;
  }
}
