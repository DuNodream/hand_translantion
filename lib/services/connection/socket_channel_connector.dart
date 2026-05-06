import 'package:web_socket_channel/web_socket_channel.dart';

import 'socket_channel_connector_stub.dart'
    if (dart.library.io) 'socket_channel_connector_io.dart'
    if (dart.library.html) 'socket_channel_connector_web.dart';

typedef ChannelConnector = Future<WebSocketChannel> Function(Uri uri);

Future<WebSocketChannel> connectWebSocketChannel(Uri uri) {
  return connectPlatformWebSocketChannel(uri);
}
