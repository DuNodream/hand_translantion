import 'package:flutter/foundation.dart';

enum Env { dev, test, prod }

class AppConfig {
  final Env env;
  final String wsUrl;
  final String apiBaseUrl;
  final String? token;
  final bool requireWsHandshake;
  final bool enableWsHeartbeat;
  final bool supportTextMessaging;

  const AppConfig({
    required this.env,
    required this.wsUrl,
    required this.apiBaseUrl,
    this.token,
    required this.requireWsHandshake,
    required this.enableWsHeartbeat,
    required this.supportTextMessaging,
  });

  static AppConfig get current {
    const envString = String.fromEnvironment('ENV', defaultValue: 'dev');
    const wsOverride = String.fromEnvironment('WS_URL', defaultValue: '');
    const apiOverride = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    const token = String.fromEnvironment('AUTH_TOKEN', defaultValue: '');

    final env = Env.values.firstWhere(
      (item) => item.name == envString,
      orElse: () => Env.dev,
    );

    final preset = switch (env) {
      Env.dev => AppConfig(
        env: Env.dev,
        wsUrl: _defaultDevWsUrl(),
        apiBaseUrl: _defaultDevApiBaseUrl(),
        requireWsHandshake: false,
        enableWsHeartbeat: false,
        supportTextMessaging: true,
      ),
      Env.test => const AppConfig(
        env: Env.test,
        wsUrl: 'wss://test.example.com/ws/recognize',
        apiBaseUrl: 'https://test.example.com',
        requireWsHandshake: true,
        enableWsHeartbeat: true,
        supportTextMessaging: true,
      ),
      Env.prod => const AppConfig(
        env: Env.prod,
        wsUrl: 'wss://prod.example.com/ws/recognize',
        apiBaseUrl: 'https://prod.example.com',
        requireWsHandshake: true,
        enableWsHeartbeat: true,
        supportTextMessaging: true,
      ),
    };

    return AppConfig(
      env: preset.env,
      wsUrl: wsOverride.isNotEmpty ? wsOverride : preset.wsUrl,
      apiBaseUrl: apiOverride.isNotEmpty ? apiOverride : preset.apiBaseUrl,
      token: token.isEmpty ? null : token,
      requireWsHandshake: preset.requireWsHandshake,
      enableWsHeartbeat: preset.enableWsHeartbeat,
      supportTextMessaging: preset.supportTextMessaging,
    );
  }

  static String _defaultDevWsUrl() {
    if (kIsWeb) {
      return 'ws://127.0.0.1:8000/ws/recognize';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // 物理手机需要 adb reverse tcp:8000 tcp:8000
        return 'ws://localhost:8000/ws/recognize';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return 'ws://127.0.0.1:8000/ws/recognize';
      case TargetPlatform.fuchsia:
        return 'ws://127.0.0.1:8000/ws/recognize';
    }
  }

  static String _defaultDevApiBaseUrl() {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return 'http://127.0.0.1:8000';
      case TargetPlatform.fuchsia:
        return 'http://127.0.0.1:8000';
    }
  }
}
