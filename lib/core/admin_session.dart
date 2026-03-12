class AdminSession {
  static const String _configuredAdminKey = String.fromEnvironment(
    'ADMIN_SECRET',
    defaultValue: '1234',
  );
  static const String _loginPasscode = String.fromEnvironment(
    'ADMIN_PASSCODE',
    defaultValue: '1234',
  );

  static String? adminKey;

  static bool get isLoggedIn => (adminKey ?? '').isNotEmpty;

  static bool login(String passcode) {
    if (passcode != _loginPasscode) {
      return false;
    }

    adminKey = _configuredAdminKey;
    return true;
  }

  static void logout() {
    adminKey = null;
  }
}
