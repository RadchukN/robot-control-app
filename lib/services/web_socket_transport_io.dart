import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectSocket(Uri uri, Map<String, String> headers) =>
    IOWebSocketChannel.connect(uri, headers: headers);

bool isUnauthorizedUpgrade(Object error) {
  final cause = error is WebSocketChannelException ? error.inner : error;
  if (cause is! WebSocketException) return false;
  // Older supported Dart SDKs may not expose this structured status property.
  // Never infer credentials failure by parsing untrusted exception messages.
  try {
    return (cause as dynamic).httpStatusCode == HttpStatus.unauthorized;
  } on NoSuchMethodError {
    return false;
  }
}
