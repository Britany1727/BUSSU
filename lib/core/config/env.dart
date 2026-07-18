class Env {
  Env._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jzymlturrbekpwomiifc.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_JQ0biNHe3HpByYwPF--Lyw_IVMUxyKE',
  );

  static const String mqttBrokerHost = String.fromEnvironment(
    'MQTT_BROKER_HOST',
    defaultValue: 'broker.example.com',
  );

  static const int mqttBrokerPort = int.fromEnvironment(
    'MQTT_BROKER_PORT',
    defaultValue: 8883,
  );

  static const String mqttBrokerUsername = String.fromEnvironment(
    'MQTT_BROKER_USERNAME',
    defaultValue: '',
  );

  static const String mqttBrokerPassword = String.fromEnvironment(
    'MQTT_BROKER_PASSWORD',
    defaultValue: '',
  );

  static const String wsFallbackUrl = String.fromEnvironment(
    'WS_FALLBACK_URL',
    defaultValue: 'wss://fallback.example.com/ws',
  );

  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  static const bool isProduction = bool.fromEnvironment(
    'IS_PRODUCTION',
    defaultValue: false,
  );

  /// Habilita autenticación mock sin Supabase para desarrollo/pruebas.
  /// En producción siempre es false.
  static bool get enableMockAuth =>
      bool.fromEnvironment('ENABLE_MOCK_AUTH', defaultValue: false);
}
