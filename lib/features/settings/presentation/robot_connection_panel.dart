part of 'settings_screen.dart';

class RobotConnectionPanel extends ConsumerStatefulWidget {
  const RobotConnectionPanel({super.key});
  @override
  ConsumerState<RobotConnectionPanel> createState() =>
      _RobotConnectionPanelState();
}

class _RobotConnectionPanelState extends ConsumerState<RobotConnectionPanel> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _ip;
  final _port = TextEditingController(text: '8765');
  final _token = TextEditingController();
  bool _credentialBusy = false;
  bool _showToken = false;
  bool? _tokenSaved;
  bool _tokenReadError = false;
  int _lookupGeneration = 0;
  Timer? _lookupTimer;
  String? _credentialMessage;
  RobotNetworkMode _mode = RobotNetworkMode.ethernet;
  String _ethernetIp = '';
  String _lanIp = '';

  @override
  void initState() {
    super.initState();
    final endpoint = ref.read(selectedRobotEndpointProvider);
    _mode = endpoint.mode;
    _ethernetIp = endpoint.mode == RobotNetworkMode.ethernet
        ? endpoint.ip
        : ref.read(robotEndpointProvider).ip;
    _lanIp = endpoint.mode == RobotNetworkMode.lanWifi
        ? endpoint.ip
        : '192.168.188.50';
    _ip = TextEditingController(text: endpoint.ip);
    _port.text = '${endpoint.port}';
    scheduleMicrotask(() => unawaited(_loadSavedToken()));
  }

  RobotEndpoint get _draftEndpoint => RobotEndpoint(
    ip: _ip.text.trim(),
    port: int.tryParse(_port.text) ?? 0,
    mode: _mode,
  );

  Future<void> _loadSavedToken() async {
    if (!mounted || kIsWeb) return;
    final generation = ++_lookupGeneration;
    try {
      final uri = _draftEndpoint.uri;
      final value = await ref.read(robotTokenStoreProvider).read(uri);
      if (!mounted || generation != _lookupGeneration) return;
      setState(() {
        _tokenSaved = value != null && value.isNotEmpty;
        _tokenReadError = false;
      });
    } on FormatException {
      // Invalid drafts must not query storage or change the active endpoint.
    } on Object {
      if (mounted && generation == _lookupGeneration) {
        setState(() => _tokenReadError = true);
      }
    }
  }

  void _endpointEdited() {
    _lookupGeneration++;
    _lookupTimer?.cancel();
    setState(() {
      _tokenSaved = null;
      _tokenReadError = false;
      _credentialMessage = null;
    });
    _lookupTimer = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_loadSavedToken()),
    );
  }

  @override
  void dispose() {
    _lookupTimer?.cancel();
    _ip.dispose();
    _port.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _applyCredentials({
    bool connect = false,
    bool remove = false,
  }) async {
    if (!_form.currentState!.validate()) return;
    final endpoint = _draftEndpoint;
    if (!connect && !remove && _token.text.isEmpty) {
      setState(() => _credentialMessage = 'Enter a token to save.');
      return;
    }
    _lookupGeneration++;
    _lookupTimer?.cancel();
    final hasDraftToken = _token.text.isNotEmpty;
    setState(() {
      _credentialBusy = true;
      _credentialMessage = null;
    });
    try {
      if (remove || hasDraftToken) {
        await ref
            .read(robotCredentialsProvider.notifier)
            .save(endpoint, remove ? null : _token.text);
      }
      if (!mounted) return;
      _token.clear();
      _showToken = false;
      if (connect) {
        ref.read(dashboardControllerProvider.notifier).connectRobot(endpoint);
      }
      setState(() {
        if (remove || hasDraftToken) _tokenSaved = !remove;
        _tokenReadError = false;
        _credentialMessage = remove
            ? 'Saved token removed.'
            : connect
            ? null
            : 'Token saved securely for this endpoint.';
      });
      if (remove || hasDraftToken) {
        context.notifications.success(
          remove ? 'Token removed' : 'Token saved',
          description: remove
              ? 'The saved token for this endpoint was removed.'
              : 'Stored securely for this robot endpoint.',
          key: 'robot-credentials',
        );
      }
    } on RobotCredentialException catch (error) {
      if (mounted) {
        setState(() => _credentialMessage = error.toString());
        context.notifications.error(
          'Credentials not updated',
          description: error.toString(),
          key: 'robot-credentials',
        );
      }
    } on Object {
      if (mounted) {
        setState(
          () => _credentialMessage = 'Could not update connection credentials.',
        );
        context.notifications.error(
          'Credentials not updated',
          description: 'Could not update connection credentials.',
          key: 'robot-credentials',
        );
      }
    } finally {
      if (mounted) setState(() => _credentialBusy = false);
    }
  }

  InputDecoration _decoration(String label, {String? hint, Widget? suffix}) =>
      InputDecoration(
        labelText: hint ?? label,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        hintText: hint,
        suffixIcon: suffix,
        filled: true,
        fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          borderSide: const BorderSide(color: _outline),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          borderSide: const BorderSide(color: _outline),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardControllerProvider);
    final link = ref.watch(robotLinkProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);
    final healthy =
        link.status == RobotLinkStatus.connected &&
        dashboard.value?.telemetryConnected == true &&
        link.lastTelemetryAt != null &&
        DateTime.now().difference(link.lastTelemetryAt!) <
            ref.watch(robotConnectionTimingProvider).staleAfter;
    final status = link.status == RobotLinkStatus.connected && !healthy
        ? RobotLinkStatus.degraded
        : link.status;
    final active = const {
      RobotLinkStatus.connecting,
      RobotLinkStatus.awaitingTelemetry,
      RobotLinkStatus.connected,
      RobotLinkStatus.degraded,
      RobotLinkStatus.reconnecting,
    }.contains(status);
    final tokenNotice =
        _credentialMessage ??
        (_tokenReadError
            ? 'Secure storage is unavailable. Please try again.'
            : _tokenSaved == true
            ? 'Token saved securely for this endpoint.'
            : _tokenSaved == false
            ? 'No saved token for this endpoint.'
            : 'Saved tokens are scoped to robot IP and port.');

    final connectionCard = _RobotConnectionSection(
      key: const Key('robot-connection-card'),
      icon: Icons.wifi_rounded,
      title: 'Robot connection',
      subtitle: 'Configure how this app connects to your robot.',
      child: Column(
        children: [
          _ConnectionFieldRow(
            title: 'Network profile',
            description: 'Select the network profile to use.',
            child: DropdownButtonFormField<RobotNetworkMode>(
              key: const Key('robot-network-profile'),
              initialValue: _mode,
              isExpanded: true,
              decoration: _decoration('Network profile'),
              items: const [
                DropdownMenuItem(
                  value: RobotNetworkMode.ethernet,
                  child: Text('Ethernet'),
                ),
                DropdownMenuItem(
                  value: RobotNetworkMode.lanWifi,
                  child: Text('LAN / Wi-Fi'),
                ),
              ],
              onChanged: _credentialBusy
                  ? null
                  : (mode) {
                      if (mode == null) return;
                      setState(() {
                        if (_mode == RobotNetworkMode.ethernet) {
                          _ethernetIp = _ip.text;
                        } else {
                          _lanIp = _ip.text;
                        }
                        _mode = mode;
                        _ip.text = mode == RobotNetworkMode.ethernet
                            ? _ethernetIp
                            : _lanIp;
                      });
                      _endpointEdited();
                    },
            ),
          ),
          const Divider(height: AppSpacing.xl, color: _outline),
          _ConnectionFieldRow(
            title: 'Robot IP address',
            description: 'Private IPv4 address on your router.',
            child: TextFormField(
              key: const Key('robot-ip-field'),
              controller: _ip,
              readOnly: _credentialBusy,
              decoration: _decoration('Robot IP address'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => _endpointEdited(),
              validator: (value) {
                try {
                  RobotEndpoint(ip: value ?? '').uri;
                  return null;
                } on FormatException catch (error) {
                  return error.message;
                }
              },
            ),
          ),
          const Divider(height: AppSpacing.xl, color: _outline),
          _ConnectionFieldRow(
            title: 'WebSocket port',
            description: 'Port used for robot communication.',
            child: TextFormField(
              key: const Key('robot-port-field'),
              controller: _port,
              readOnly: _credentialBusy,
              decoration: _decoration('WebSocket port'),
              keyboardType: TextInputType.number,
              onChanged: (_) => _endpointEdited(),
              validator: (value) {
                final port = int.tryParse(value ?? '');
                return port == null || port < 1 || port > 65535
                    ? 'Enter a port from 1 to 65535.'
                    : null;
              },
            ),
          ),
        ],
      ),
    );

    final tokenCard = _RobotConnectionSection(
      key: const Key('bearer-token-card'),
      icon: Icons.lock_outline_rounded,
      title: 'Bearer token',
      subtitle:
          'Blank keeps the saved token. Tokens are scoped to robot IP and port.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('robot-token-field'),
            controller: _token,
            enabled: !kIsWeb,
            readOnly: _credentialBusy,
            obscureText: !_showToken,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            onChanged: (_) => setState(() {}),
            decoration: _decoration(
              'Bearer token',
              hint: 'Enter bearer token (optional)',
              suffix: IconButton(
                tooltip: _showToken ? 'Hide token' : 'Show token',
                onPressed: _credentialBusy || kIsWeb
                    ? null
                    : () => setState(() => _showToken = !_showToken),
                icon: Icon(
                  _showToken
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _muted,
                ),
              ),
            ),
            validator: (value) =>
                value == null || value.isEmpty || isValidRobotToken(value)
                ? null
                : 'Enter a token without spaces or control characters.',
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              tokenNotice,
              style: _text(
                13,
                height: 1.5,
                color: _tokenReadError ? AppColors.error : _muted,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton(
                onPressed: kIsWeb || _credentialBusy || _token.text.isEmpty
                    ? null
                    : () => _applyCredentials(),
                child: const Text('Save token'),
              ),
              OutlinedButton(
                onPressed: kIsWeb || _credentialBusy || _tokenSaved == false
                    ? null
                    : () => _applyCredentials(remove: true),
                child: const Text('Remove saved token'),
              ),
            ],
          ),
        ],
      ),
    );

    final statusCard = _RobotConnectionStatusCard(status: status, link: link);
    final actionsCard = _RobotConnectionSection(
      key: const Key('connection-actions-card'),
      icon: Icons.power_rounded,
      title: 'Connection actions',
      subtitle: active
          ? 'Disconnect before starting another connection.'
          : 'Connect or disconnect from your robot.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final connect = FilledButton.icon(
            key: const Key('robot-connect-button'),
            onPressed: _credentialBusy || active
                ? null
                : () => _applyCredentials(connect: true),
            icon:
                status == RobotLinkStatus.connecting ||
                    status == RobotLinkStatus.reconnecting ||
                    status == RobotLinkStatus.awaitingTelemetry ||
                    _credentialBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(
              status == RobotLinkStatus.connecting
                  ? 'Connecting…'
                  : status == RobotLinkStatus.reconnecting
                  ? 'Reconnecting…'
                  : status == RobotLinkStatus.awaitingTelemetry
                  ? 'Waiting for telemetry…'
                  : 'Connect',
            ),
          );
          final disconnect = OutlinedButton.icon(
            key: const Key('robot-disconnect-button'),
            onPressed:
                _credentialBusy ||
                    (status == RobotLinkStatus.disconnected &&
                        link.message == null)
                ? null
                : controller.disconnectRobot,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Disconnect'),
          );
          if (constraints.maxWidth < 420 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                connect,
                const SizedBox(height: AppSpacing.sm),
                disconnect,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: connect),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: disconnect),
            ],
          );
        },
      ),
    );

    return Theme(
      data: Theme.of(context).copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _purple,
            foregroundColor: _surface,
            minimumSize: const Size(64, 52),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _purple,
            minimumSize: const Size(64, 52),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            side: BorderSide(color: _purple.withValues(alpha: .5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            ),
          ),
        ),
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _RobotConnectionSection(
              icon: Icons.cloud_outlined,
              title: 'Connectivity',
              subtitle:
                  'Manage Wi-Fi, Bluetooth, and platform connections for G1 Gustav.',
            ),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 760) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      connectionCard,
                      const SizedBox(height: AppSpacing.lg),
                      tokenCard,
                      const SizedBox(height: AppSpacing.lg),
                      statusCard,
                      const SizedBox(height: AppSpacing.lg),
                      actionsCard,
                    ],
                  );
                }
                return Row(
                  key: const Key('connection-two-columns'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          connectionCard,
                          const SizedBox(height: AppSpacing.lg),
                          tokenCard,
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          statusCard,
                          const SizedBox(height: AppSpacing.lg),
                          actionsCard,
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RobotConnectionSection extends StatelessWidget {
  const _RobotConnectionSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.child,
    super.key,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? child;
  @override
  Widget build(BuildContext context) => _GlassCard(
    radius: AppSpacing.radiusLarge,
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RobotConnectionIcon(icon),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: _text(
                      title == 'Connectivity' ? 26 : 20,
                      height: 1.3,
                      weight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(subtitle, style: _text(14, height: 1.5, color: _muted)),
                ],
              ),
            ),
          ],
        ),
        if (child != null) ...[const SizedBox(height: AppSpacing.lg), child!],
      ],
    ),
  );
}

class _RobotConnectionIcon extends StatelessWidget {
  const _RobotConnectionIcon(this.icon);
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: _purple.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
    ),
    child: Icon(icon, size: 28, color: _purple),
  );
}

class _ConnectionFieldRow extends StatelessWidget {
  const _ConnectionFieldRow({
    required this.title,
    required this.description,
    required this.child,
  });
  final String title;
  final String description;
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final label = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: _text(16, height: 1.4, weight: FontWeight.w600, color: _ink),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(description, style: _text(13, height: 1.5, color: _muted)),
        ],
      );
      if (constraints.maxWidth < 520 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            label,
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 6, child: label),
          const SizedBox(width: AppSpacing.md),
          Expanded(flex: 5, child: child),
        ],
      );
    },
  );
}

class _RobotConnectionStatusCard extends StatelessWidget {
  const _RobotConnectionStatusCard({required this.status, required this.link});
  final RobotLinkStatus status;
  final RobotLinkState link;
  @override
  Widget build(BuildContext context) {
    final error =
        status == RobotLinkStatus.disconnected &&
        link.message != null &&
        !link.message!.startsWith('App suspended');
    final (title, description, color) = switch (status) {
      RobotLinkStatus.connected => (
        'Connected',
        'Robot is connected and telemetry is current.',
        AppColors.success,
      ),
      RobotLinkStatus.connecting => (
        'Connecting',
        'Opening a connection to the robot.',
        _purple,
      ),
      RobotLinkStatus.awaitingTelemetry => (
        'Waiting for telemetry',
        'WebSocket is open. Waiting for fresh robot telemetry.',
        AppColors.warning,
      ),
      RobotLinkStatus.reconnecting => (
        'Reconnecting',
        'Retrying the connection. Commands are never replayed.',
        AppColors.warning,
      ),
      RobotLinkStatus.degraded => (
        'Degraded',
        'Telemetry is stale. Robot commands are disabled.',
        AppColors.warning,
      ),
      RobotLinkStatus.authenticationRequired => (
        'Authentication required',
        'Update the saved token to authenticate.',
        AppColors.error,
      ),
      RobotLinkStatus.disconnected when error => (
        'Error',
        'Robot connection is unavailable.',
        AppColors.error,
      ),
      RobotLinkStatus.disconnected => (
        'Disconnected',
        'Robot is disconnected. Connect to receive telemetry.',
        _muted,
      ),
    };
    final timestamp = link.lastTelemetryAt?.toLocal();
    String digits(int value) => value.toString().padLeft(2, '0');
    final time = timestamp == null
        ? 'No telemetry yet'
        : '${digits(timestamp.hour)}:${digits(timestamp.minute)}:${digits(timestamp.second)}';
    return _GlassCard(
      key: const Key('connection-status-card'),
      radius: AppSpacing.radiusLarge,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Icon(Icons.circle, size: 20, color: color),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          key: const Key('robot-status-title'),
                          style: _text(
                            22,
                            height: 1.3,
                            weight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          description,
                          style: _text(14, height: 1.5, color: _muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _ConnectionStatusRow(
            icon: Icons.monitor_heart_outlined,
            title: 'Connection status',
            description: 'Current connection state.',
            value: Text(title, style: _text(14, height: 1.5, color: color)),
          ),
          const Divider(height: AppSpacing.xl, color: _outline),
          _ConnectionStatusRow(
            icon: Icons.access_time_rounded,
            title: 'Last telemetry',
            description: 'Timestamp of last received data.',
            value: Tooltip(
              message: timestamp?.toIso8601String() ?? 'No telemetry received',
              child: Text(
                time,
                key: const Key('last-telemetry-time'),
                style: _text(14, height: 1.5, color: _ink),
              ),
            ),
          ),
          if (link.message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              link.message!,
              style: _text(
                13,
                height: 1.5,
                color: error || status == RobotLinkStatus.authenticationRequired
                    ? AppColors.error
                    : _muted,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: _purple),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Endpoints apply to this app session.',
                        style: _text(
                          14,
                          height: 1.5,
                          weight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        kIsWeb
                            ? 'Flutter Web cannot send the required Authorization header. Use the native app for authenticated LAN connections.'
                            : 'Tokens persist in OS-backed secure storage. Wi-Fi is configured in device settings.',
                        style: _text(13, height: 1.5, color: _muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionStatusRow extends StatelessWidget {
  const _ConnectionStatusRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
  });
  final IconData icon;
  final String title;
  final String description;
  final Widget value;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stacked =
          constraints.maxWidth < 500 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RobotConnectionIcon(icon),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _text(
                    16,
                    height: 1.4,
                    weight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(description, style: _text(13, height: 1.5, color: _muted)),
                if (stacked) ...[const SizedBox(height: AppSpacing.xs), value],
              ],
            ),
          ),
          if (!stacked) ...[const SizedBox(width: AppSpacing.md), value],
        ],
      );
    },
  );
}
