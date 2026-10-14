import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectSocket(Uri uri, Map<String, String> headers) {
  if (headers.isNotEmpty) {
    throw UnsupportedError(
      'Browser WebSockets cannot send Authorization headers.',
    );
  }
  return WebSocketChannel.connect(uri);
}

bool isUnauthorizedUpgrade(Object error) => false;
