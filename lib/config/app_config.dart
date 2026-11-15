class AppConfig {
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://api.myclinic.myenum.in',
  );

  static const String loginEndpoint = String.fromEnvironment(
    'LOGIN_ENDPOINT',
    defaultValue: '/api/clinics/auth/login',
  );

  static const String forgotPasswordEndpoint = String.fromEnvironment(
    'FORGOT_PASSWORD_ENDPOINT',
    defaultValue: '/api/clinics/auth/forgot-password',
  );

  static const String apiKey = String.fromEnvironment('API_KEY');

  static Uri get loginUri => Uri.parse('$backendUrl$loginEndpoint');

  static Uri get forgotPasswordUri =>
      Uri.parse('$backendUrl$forgotPasswordEndpoint');
}
