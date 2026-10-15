import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:robot_control_app/services/robot_connection.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum RobotCredentialFailure { missing, storage, unsupportedWeb, invalidFormat }

class RobotCredentialException implements Exception {
  const RobotCredentialException(this.reason);
  final RobotCredentialFailure reason;
  @override
  String toString() => switch (reason) {
    RobotCredentialFailure.missing =>
      'A saved token is required for LAN connectivity.',
    RobotCredentialFailure.storage =>
      'Secure credential storage is unavailable. Retry after restoring access.',
    RobotCredentialFailure.unsupportedWeb =>
      'Authenticated LAN connections are unavailable in Flutter Web.',
    RobotCredentialFailure.invalidFormat =>
      'Enter a valid bearer token without spaces or control characters.',
  };
}

abstract interface class RobotTokenStore {
  Future<String?> read(Uri endpoint);
  Future<void> write(Uri endpoint, String token);
  Future<void> delete(Uri endpoint);
}

class OsRobotTokenStore implements RobotTokenStore {
  const OsRobotTokenStore(this.storage);
  final FlutterSecureStorage storage;
  String _key(Uri endpoint) => 'robot.bearer.${endpoint.host}.${endpoint.port}';

  void _checkPlatform() {
    if (kIsWeb) {
      throw const RobotCredentialException(
        RobotCredentialFailure.unsupportedWeb,
      );
    }
  }

  @override
  Future<String?> read(Uri endpoint) async {
    _checkPlatform();
    try {
      return await storage.read(key: _key(endpoint));
    } on Object {
      throw const RobotCredentialException(RobotCredentialFailure.storage);
    }
  }

  @override
  Future<void> write(Uri endpoint, String token) async {
    _checkPlatform();
    try {
      await storage.write(key: _key(endpoint), value: token);
    } on Object {
      throw const RobotCredentialException(RobotCredentialFailure.storage);
    }
  }

  @override
  Future<void> delete(Uri endpoint) async {
    _checkPlatform();
    try {
      await storage.delete(key: _key(endpoint));
    } on Object {
      throw const RobotCredentialException(RobotCredentialFailure.storage);
    }
  }
}

final robotTokenStoreProvider = Provider<RobotTokenStore>(
  (ref) => const OsRobotTokenStore(FlutterSecureStorage()),
  name: 'RobotTokenStoreProvider',
);

bool isValidRobotToken(String token) =>
    RegExp(r'^[A-Za-z0-9\-._~+/]+=*$').hasMatch(token);

class RobotCredentialChange {
  const RobotCredentialChange(this.endpoint);
  final Uri endpoint;
}

class RobotCredentialsNotifier extends Notifier<RobotCredentialChange?> {
  @override
  RobotCredentialChange? build() => null;

  Future<void> save(RobotEndpoint endpoint, String? token) async {
    final uri = endpoint.uri;
    if (token != null && !isValidRobotToken(token)) {
      throw const RobotCredentialException(
        RobotCredentialFailure.invalidFormat,
      );
    }
    try {
      final store = ref.read(robotTokenStoreProvider);
      if (await store.read(uri) == token) return;
      if (token == null) {
        await store.delete(uri);
      } else {
        await store.write(uri, token);
      }
      if (ref.mounted) state = RobotCredentialChange(uri);
    } on RobotCredentialException {
      rethrow;
    } on Object {
      throw const RobotCredentialException(RobotCredentialFailure.storage);
    }
  }
}

final robotCredentialsProvider =
    NotifierProvider<RobotCredentialsNotifier, RobotCredentialChange?>(
      RobotCredentialsNotifier.new,
      name: 'RobotCredentialsProvider',
    );

class BearerRobotAuthentication implements RobotAuthenticationAdapter {
  const BearerRobotAuthentication(this.store);
  final RobotTokenStore store;

  @override
  Future<Map<String, String>> upgradeHeaders(RobotEndpoint endpoint) async {
    // Browsers cannot implement the approved header contract or OS-backed storage.
    if (kIsWeb) {
      if (endpoint.mode == RobotNetworkMode.lanWifi) {
        throw const RobotCredentialException(
          RobotCredentialFailure.unsupportedWeb,
        );
      }
      return const {};
    }
    String? token;
    try {
      token = await store.read(endpoint.uri);
    } on Object {
      throw const RobotCredentialException(RobotCredentialFailure.storage);
    }
    if (token == null || token.isEmpty) {
      if (endpoint.mode == RobotNetworkMode.lanWifi) {
        throw const RobotCredentialException(RobotCredentialFailure.missing);
      }
      return const {}; // Preserve legacy Ethernet servers without authentication.
    }
    if (!isValidRobotToken(token)) {
      throw const RobotCredentialException(
        RobotCredentialFailure.invalidFormat,
      );
    }
    return {'Authorization': 'Bearer $token'};
  }

  @override
  Future<void> authenticate(WebSocketChannel channel) => channel.ready;
}
