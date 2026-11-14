class AppConfig {
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://api.myclinic.myenum.in',
  );

  static const String loginEndpoint = String.fromEnvironment(
    'LOGIN_ENDPOINT',
    defaultValue: '/api/auth/login',
  );

  static const String apiKey = String.fromEnvironment('API_KEY');

  static Uri get loginUri => Uri.parse('$backendUrl$loginEndpoint');
}
