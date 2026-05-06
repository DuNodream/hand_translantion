import 'package:web_socket_channel/web_socket_channel.dart';

Future<WebSocketChannel> connectPlatformWebSocketChannel(Uri uri) {
  return Future<WebSocketChannel>.value(WebSocketChannel.connect(uri));
}
