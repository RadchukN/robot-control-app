import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  const WebSocketService();

  WebSocketChannel connect(Uri uri) => WebSocketChannel.connect(uri);
}
