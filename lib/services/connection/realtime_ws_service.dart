import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../debug/debug_log_service.dart';
import '../session/session_service.dart';
import '../settings/runtime_settings_service.dart';
import 'socket_channel_connector.dart';

enum WsState { idle, connecting, connected, reconnecting, disconnected, error }

class RealtimeWsService extends GetxService with WidgetsBindingObserver {
  RealtimeWsService({
    SessionService? sessionService,
    DebugLogService? debugLogService,
    Future<WebSocketChannel> Function(Uri uri)? connector,
  }) : _sessionService = sessionService,
       _debugLogService = debugLogService,
       _connector = connector ?? connectWebSocketChannel;

  final SessionService? _sessionService;
  final DebugLogService? _debugLogService;
  final Future<WebSocketChannel> Function(Uri uri) _connector;

  final Rx<WsState> state = WsState.idle.obs;
  final RxString statusText = 'Not connected'.obs;
  final RxnString errorText = RxnString();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;
  Timer? _pongTimeoutTimer;
  Timer? _reconnectTimer;

  String _baseUrl = '';
  String? _token;
  RuntimeSettingsService? _settingsService;
  bool _manuallyClosed = false;
  bool _handshakeCompleted = false;
  int _retryAttempt = 0;
  bool _requireHandshake = true;
  bool _enableHeartbeat = true;
  bool _supportTextMessaging = true;

  // 房间管理用的 Completer（配合 _onMessage 使用，避免重复监听 stream）
  Completer<String?>? _roomCreateCompleter;
  Completer<bool>? _roomJoinCompleter;

  Future<RealtimeWsService> initialize({
    required String baseUrl,
    String? token,
    RuntimeSettingsService? settingsService,
    bool requireHandshake = true,
    bool enableHeartbeat = true,
    bool supportTextMessaging = true,
  }) async {
    _baseUrl = baseUrl;
    _token = token;
    _settingsService = settingsService;
    _requireHandshake = requireHandshake;
    _enableHeartbeat = enableHeartbeat;
    _supportTextMessaging = supportTextMessaging;
    WidgetsBinding.instance.addObserver(this);
    _log('init baseUrl=$baseUrl handshake=$requireHandshake heartbeat=$enableHeartbeat');
    return this;
  }

  String get activeUrl => _settingsService?.resolveWsUrl(_baseUrl) ?? _baseUrl;

  Future<void> connect() async {
    if (state.value == WsState.connecting || state.value == WsState.connected) {
      _log('connect skipped because state=${state.value.name}');
      return;
    }

    _manuallyClosed = false;
    _setState(
      _retryAttempt == 0 ? WsState.connecting : WsState.reconnecting,
      _retryAttempt == 0 ? 'Connecting...' : 'Reconnecting...',
    );
    _log('connect start url=$activeUrl');

    try {
      _cleanupSocket();
      final uri = Uri.parse(activeUrl).replace(
        queryParameters: {
          if (_token != null && _token!.isNotEmpty) 'token': _token!,
        },
      );

      _channel = await _connector(uri);
      _log('socket open success');
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: (Object error) {
          _handleDisconnect(_describeConnectionError(error), isError: true);
        },
        onDone: () {
          _handleDisconnect('Socket closed');
        },
        cancelOnError: true,
      );

      if (_requireHandshake) {
        _startHandshakeTimer();
        _sendJson({
          'type': 'hello',
          'client': 'flutter',
          'version': '1.0.0',
          'ts': DateTime.now().toIso8601String(),
        });
        _log('hello sent');
      } else {
        _handshakeCompleted = true;
        _retryAttempt = 0;
        _setState(WsState.connected, 'Connected');
        _log('legacy mode connected');
      }
    } catch (error) {
      _handleDisconnect(_describeConnectionError(error), isError: true);
    }
  }

  bool sendTextMessage(String text, {required String messageId}) {
    if (!_supportTextMessaging) {
      errorText.value = 'Current backend does not support text message channel';
      _log(errorText.value!);
      return false;
    }
    if (state.value != WsState.connected || _channel == null) {
      errorText.value = 'WebSocket not connected';
      _log(errorText.value!);
      return false;
    }

    _sendJson({
      'type': 'chat_message',
      'message_id': messageId,
      'session_id': _sessionService?.sessionId.value ?? 'default-session',
      'content': text,
      'ts': DateTime.now().toIso8601String(),
    });
    _log('text message sent: $messageId');
    return true;
  }

  // ======================== 双设备房间管理 ========================

  /// 创建房间，返回 room_id 或 null（失败）
  Future<String?> createRoom(String role) async {
    if (state.value != WsState.connected || _channel == null) {
      _log('createRoom failed: not connected');
      return null;
    }

    _roomCreateCompleter = Completer<String?>();
    _sendJson({'type': 'create_room', 'role': role});

    final result = await _roomCreateCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
    _roomCreateCompleter = null;
    return result;
  }

  /// 加入已有房间，返回是否成功
  Future<bool> joinRoom(String roomId, String role) async {
    if (state.value != WsState.connected || _channel == null) {
      _log('joinRoom failed: not connected');
      return false;
    }

    _roomJoinCompleter = Completer<bool>();
    _sendJson({'type': 'join_room', 'room_id': roomId, 'role': role});

    final result = await _roomJoinCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => false,
    );
    _roomJoinCompleter = null;
    return result;
  }

  bool sendFrame(Uint8List bytes) {
    if (state.value != WsState.connected || _channel == null) {
      _log('frame dropped: ws not connected');
      return false;
    }
    _channel!.sink.add(bytes);
    return true;
  }

  void requestSessionReset() {
    if (state.value != WsState.connected || _channel == null) return;
    _sendJson({
      'type': 'reset',
      'session_id': _sessionService?.sessionId.value ?? 'default-session',
    });
    _log('reset sent');
  }

  Future<void> disconnect({bool manual = true}) async {
    _manuallyClosed = manual;
    _cleanupAll();
    _handshakeCompleted = false;
    _setState(WsState.disconnected, manual ? 'Closed manually' : 'Disconnected');
    _log('disconnect called manual=$manual');
  }

  void _onMessage(dynamic raw) {
    _log('message received runtime=${raw.runtimeType}');
    if (raw is! String) return;

    final payload = jsonDecode(raw) as Map<String, dynamic>;
    final type = payload['type']?.toString() ?? '';

    if (type == 'hello_ack' || type == 'ready') {
      _handshakeCompleted = true;
      _retryAttempt = 0;
      _setState(WsState.connected, 'Connected');
      _log('handshake ack: $type');
      if (_enableHeartbeat) {
        _startHeartbeat();
      }
      return;
    }

    if (type == 'pong') {
      _pongTimeoutTimer?.cancel();
      _log('pong received');
      return;
    }

    if (type == 'room_created') {
      _roomCreateCompleter?.complete(payload['room_id'] as String?);
      return;
    }

    if (type == 'room_joined') {
      _roomJoinCompleter?.complete(true);
      return;
    }

    if (type == 'error') {
      errorText.value = payload['message']?.toString() ?? 'Server error';
      _log('server error: ${errorText.value}');
      _roomCreateCompleter?.complete(null);
      _roomJoinCompleter?.complete(false);
    }

    _sessionService?.onRecognitionPayload(payload);
  }

  void _sendJson(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }

  void _startHandshakeTimer() {
    Future<void>.delayed(const Duration(seconds: 5), () {
      if (!_requireHandshake) return;
      if (!_handshakeCompleted &&
          !_manuallyClosed &&
          (state.value == WsState.connecting || state.value == WsState.reconnecting)) {
        _log('handshake timeout');
        _handleDisconnect('Handshake timeout', isError: true);
      }
    });
  }

  void _startHeartbeat() {
    if (!_enableHeartbeat) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (state.value != WsState.connected) return;
      _sendJson({
        'type': 'ping',
        'ts': DateTime.now().toIso8601String(),
      });
      _log('ping sent');
      _pongTimeoutTimer?.cancel();
      _pongTimeoutTimer = Timer(const Duration(seconds: 8), () {
        _handleDisconnect('Heartbeat timeout', isError: true);
      });
    });
  }

  void _handleDisconnect(String message, {bool isError = false}) {
    _cleanupSocket();
    _handshakeCompleted = false;

    // 断开连接时，提前 complete 房间 Completer，避免等待超时
    _roomCreateCompleter?.complete(null);
    _roomCreateCompleter = null;
    _roomJoinCompleter?.complete(false);
    _roomJoinCompleter = null;

    if (_manuallyClosed) {
      _setState(WsState.disconnected, 'Closed manually');
      _log('manual disconnect finished');
      return;
    }

    errorText.value = isError ? message : null;
    _setState(isError ? WsState.error : WsState.disconnected, message);
    _log('disconnect: $message');
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delays = <int>[1, 2, 4, 8, 15];
    final index = _retryAttempt < delays.length ? _retryAttempt : delays.length - 1;
    final delaySeconds = delays[index];
    _retryAttempt++;
    _setState(WsState.reconnecting, 'Reconnect in ${delaySeconds}s');
    _log('reconnect scheduled in ${delaySeconds}s');
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), connect);
  }

  String _describeConnectionError(Object error) {
    final url = activeUrl;
    final raw = error.toString();

    if (_isAndroidLocalhost(url)) {
      return 'Android device cannot use localhost directly. Use your PC LAN IP or adb reverse. Raw: $raw';
    }

    if (_isAndroidLocalhost(url)) {
      return 'Android emulator should use 10.0.2.2 instead of localhost. Raw: $raw';
    }

    return 'Connect failed: $raw';
  }

  bool _isAndroidLocalhost(String url) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    final host = Uri.tryParse(url)?.host ?? '';
    return host == '127.0.0.1' || host == 'localhost';
  }

  void _setState(WsState next, String text) {
    state.value = next;
    statusText.value = text;
    _log('state => ${next.name}: $text');
  }

  void _cleanupSocket() {
    _subscription?.cancel();
    _subscription = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _pongTimeoutTimer?.cancel();
    _pongTimeoutTimer = null;
    _channel?.sink.close();
    _channel = null;
  }

  void _cleanupAll() {
    _cleanupSocket();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _log(String message) {
    _debugLogService?.log('ws', message);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_manuallyClosed) {
      _log('app resumed, try reconnect');
      connect();
    }
    if (state == AppLifecycleState.paused) {
      _log('app paused');
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupAll();
    super.onClose();
  }
}
