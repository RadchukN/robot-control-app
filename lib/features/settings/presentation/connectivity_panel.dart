part of 'settings_screen.dart';

const _connectivityTint = Color(0xFFF6F2FF);
const _connectivityGreenTint = Color(0xFFEAF9F1);
const _connectivityRedTint = Color(0xFFFFF1F0);

class _DesktopConnectivityLayout extends StatelessWidget {
  const _DesktopConnectivityLayout({
    required this.settingsState,
    required this.state,
    required this.controller,
    required this.wide,
    required this.onCategorySelected,
  });

  final SettingsState settingsState;
  final ConnectivityState state;
  final ConnectivityController controller;
  final bool wide;
  final ValueChanged<SettingsCategory> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('connectivity-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: wide ? 250 : 228,
                child: _CategoryRail(
                  selected: settingsState.category,
                  query: settingsState.searchQuery,
                  onSelected: onCategorySelected,
                ),
              ),
              SizedBox(width: wide ? 20 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _ConnectivityOverview(),
                    const SizedBox(height: 12),
                    _ConnectivityCore(state: state, controller: controller),
                    if (!wide) ...[
                      const SizedBox(height: 14),
                      _ConnectivitySidebar(state: state, horizontal: true),
                    ],
                  ],
                ),
              ),
              if (wide) ...[
                const SizedBox(width: 18),
                SizedBox(width: 334, child: _ConnectivitySidebar(state: state)),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _PortsAndPeripherals(state: state, controller: controller),
        ],
      ),
    );
  }
}

class _ConnectivityResponsivePanel extends StatelessWidget {
  const _ConnectivityResponsivePanel({
    required this.state,
    required this.controller,
    this.compact = false,
  });

  final ConnectivityState state;
  final ConnectivityController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('connectivity-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ConnectivityOverview(),
          const SizedBox(height: 12),
          _ConnectivityCore(state: state, controller: controller),
          const SizedBox(height: 12),
          _ConnectivitySidebar(state: state, horizontal: !compact),
          const SizedBox(height: 12),
          _PortsAndPeripherals(
            state: state,
            controller: controller,
            compact: compact,
          ),
        ],
      ),
    );
  }
}

class _ConnectivityOverview extends StatelessWidget {
  const _ConnectivityOverview();

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connectivity',
            style: _text(
              22,
              height: 28 / 22,
              weight: FontWeight.w600,
              color: _ink,
            ),
          ),
          Text(
            'Manage Wi-Fi, Bluetooth, and platform connections for G1 Gustav.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _text(11, height: 15 / 11, color: _muted),
          ),
        ],
      ),
    );
  }
}

class _ConnectivityCore extends StatelessWidget {
  const _ConnectivityCore({required this.state, required this.controller});

  final ConnectivityState state;
  final ConnectivityController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wifi = _WifiCard(state: state, controller: controller);
        final secondary = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BluetoothCard(state: state, controller: controller),
            const SizedBox(height: 10),
            _PlatformConnectivityCard(state: state, controller: controller),
          ],
        );
        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [wifi, const SizedBox(height: 12), secondary],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 11, child: wifi),
            const SizedBox(width: 12),
            Expanded(flex: 10, child: secondary),
          ],
        );
      },
    );
  }
}

class _WifiCard extends StatelessWidget {
  const _WifiCard({required this.state, required this.controller});

  final ConnectivityState state;
  final ConnectivityController controller;

  @override
  Widget build(BuildContext context) {
    final connected = state.wifiNetworks
        .where((item) => item.status == ConnectivityItemStatus.connected)
        .firstOrNull;
    return _GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ConnectivityHeader(
            icon: Icons.wifi_rounded,
            title: 'Wi-Fi',
            subtitle: 'Connect to wireless networks',
            trailing: KeyedSubtree(
              key: const Key('connectivity-wifi-switch'),
              child: _SettingsSwitch(
                value: state.wifiEnabled,
                onTap: controller.toggleWifi,
                compact: true,
              ),
            ),
          ),
          const SizedBox(height: 10),
          AnimatedOpacity(
            opacity: state.wifiEnabled ? 1 : 0.48,
            duration: const Duration(milliseconds: 160),
            child: IgnorePointer(
              ignoring: !state.wifiEnabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ConnectedWifiBanner(
                    network: connected,
                    onDisconnect: connected == null
                        ? null
                        : () => controller.disconnectWifi(connected.id),
                  ),
                  const SizedBox(height: 8),
                  _WifiMetrics(network: connected),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: _outline),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Available networks',
                          style: _text(
                            12,
                            height: 16 / 12,
                            weight: FontWeight.w600,
                            color: _body,
                          ),
                        ),
                      ),
                      _TextAction(
                        icon: Icons.refresh_rounded,
                        label: 'Refresh',
                        onTap: () => _runConnectivityAction(
                          context,
                          controller.refresh(),
                          success: 'Networks refreshed',
                          unavailable: 'Network refresh is not connected yet',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final network in state.wifiNetworks)
                    _WifiNetworkRow(
                      network: network,
                      selected: network.id == state.selectedWifiId,
                      onSelect: () => controller.selectWifi(network.id),
                      onAction:
                          network.status == ConnectivityItemStatus.connected
                          ? () => controller.disconnectWifi(network.id)
                          : () => controller.connectWifi(network.id),
                    ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: _outline),
                  const SizedBox(height: 8),
                  _SelectRow(
                    label: 'Preferred network',
                    helper: 'Automatically connect when available',
                    child: _ConnectivityDropdown(
                      key: const Key('connectivity-preferred-wifi'),
                      value: state.preferredWifiId,
                      items: {
                        for (final network in state.wifiNetworks)
                          network.id: network.name,
                      },
                      onChanged: controller.setPreferredWifi,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SelectRow(
                    label: 'Auto connect',
                    helper: 'Connect automatically to known networks',
                    child: _SettingsSwitch(
                      value: state.autoConnect,
                      onTap: controller.toggleAutoConnect,
                      compact: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!state.wifiEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Wi-Fi is turned off',
                textAlign: TextAlign.center,
                style: _text(11, height: 15 / 11, color: _muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConnectedWifiBanner extends StatelessWidget {
  const _ConnectedWifiBanner({required this.network, this.onDisconnect});

  final WifiNetwork? network;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _connectivityGreenTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.wb_sunny_outlined, size: 20, color: _success),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  network == null ? 'Not connected' : 'Connected',
                  style: _text(
                    11,
                    height: 14 / 11,
                    weight: FontWeight.w600,
                    color: network == null ? _muted : _success,
                  ),
                ),
                Text(
                  network?.name ?? 'Choose an available network',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(
                    13,
                    height: 17 / 13,
                    weight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                if (network != null)
                  Text(
                    'Strong signal · 5 GHz',
                    style: _text(10, height: 13 / 10, color: _muted),
                  ),
              ],
            ),
          ),
          if (onDisconnect != null)
            _SoftButton(label: 'Disconnect', onTap: onDisconnect!),
        ],
      ),
    );
  }
}

class _WifiMetrics extends StatelessWidget {
  const _WifiMetrics({required this.network});

  final WifiNetwork? network;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _Metric(
          icon: Icons.signal_cellular_alt_rounded,
          label: 'Signal strength',
          value: network?.signalDescription ?? '—',
        ),
        _Metric(
          icon: Icons.desktop_windows_outlined,
          label: 'IP address',
          value: network?.ipAddress ?? '—',
        ),
        _Metric(
          icon: Icons.lock_outline_rounded,
          label: 'Security',
          value: network?.security ?? '—',
        ),
        _Metric(
          icon: Icons.monitor_heart_outlined,
          label: 'Connection quality',
          value: network?.connectionQuality ?? '—',
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 178,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: _body),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: _text(10, height: 13 / 10, color: _body),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(10, height: 13 / 10, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WifiNetworkRow extends StatelessWidget {
  const _WifiNetworkRow({
    required this.network,
    required this.selected,
    required this.onSelect,
    required this.onAction,
  });

  final WifiNetwork network;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final connected = network.status == ConnectivityItemStatus.connected;
    return Material(
      color: selected ? _connectivityTint : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Row(
            children: [
              Icon(
                Icons.wifi_rounded,
                size: 17,
                color: connected ? _purple : _body,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      network.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _text(
                        11,
                        height: 14 / 11,
                        weight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                    Text(
                      network.details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _text(9, height: 12 / 9, color: _muted),
                    ),
                  ],
                ),
              ),
              if (network.secured)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: _body,
                  ),
                ),
              Icon(
                Icons.signal_cellular_alt_rounded,
                size: 16,
                color: network.signalLevel >= 4 ? _success : _body,
              ),
              const SizedBox(width: 8),
              _SoftButton(
                label: connected ? 'Connected' : 'Connect',
                onTap: onAction,
                success: connected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BluetoothCard extends StatelessWidget {
  const _BluetoothCard({required this.state, required this.controller});

  final ConnectivityState state;
  final ConnectivityController controller;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ConnectivityHeader(
            icon: Icons.bluetooth_rounded,
            title: 'Bluetooth',
            subtitle: 'Pair and manage Bluetooth devices',
            trailing: KeyedSubtree(
              key: const Key('connectivity-bluetooth-switch'),
              child: _SettingsSwitch(
                value: state.bluetoothEnabled,
                onTap: controller.toggleBluetooth,
                compact: true,
              ),
            ),
          ),
          const SizedBox(height: 9),
          AnimatedOpacity(
            opacity: state.bluetoothEnabled ? 1 : 0.48,
            duration: const Duration(milliseconds: 160),
            child: IgnorePointer(
              ignoring: !state.bluetoothEnabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _connectivityGreenTint,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 11, color: _success),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.discoverable ? 'On' : 'Hidden',
                                style: _text(
                                  10,
                                  height: 13 / 10,
                                  weight: FontWeight.w600,
                                  color: _success,
                                ),
                              ),
                              Text(
                                state.discoverable
                                    ? 'Discoverable as “G1 Gustav”'
                                    : 'Bluetooth remains connected',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _text(
                                  11,
                                  height: 14 / 11,
                                  weight: FontWeight.w600,
                                  color: _ink,
                                ),
                              ),
                              Text(
                                state.discoverable
                                    ? 'Visible to nearby devices for 2 minutes'
                                    : 'Not visible to new devices',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _text(9, height: 12 / 9, color: _muted),
                              ),
                            ],
                          ),
                        ),
                        _SoftButton(
                          label: state.discoverable
                              ? 'Stop discoverable'
                              : 'Make discoverable',
                          onTap: controller.toggleDiscoverable,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Paired devices',
                          style: _text(
                            12,
                            height: 16 / 12,
                            weight: FontWeight.w600,
                            color: _body,
                          ),
                        ),
                      ),
                      _TextAction(
                        icon: Icons.refresh_rounded,
                        label: 'Scan for devices',
                        onTap: () => _showConnectivityMessage(
                          context,
                          'Device scanning is not connected yet',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  for (final device in state.bluetoothDevices)
                    _BluetoothDeviceRow(
                      device: device,
                      selected: state.selectedBluetoothId == device.id,
                      onTap: () => controller.selectBluetoothDevice(device.id),
                    ),
                  const SizedBox(height: 8),
                  _PrimaryConnectivityButton(
                    icon: Icons.add_rounded,
                    label: 'Pair new device',
                    onTap: () => _showConnectivityMessage(
                      context,
                      'Device pairing is ready for a connectivity service',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!state.bluetoothEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Bluetooth is turned off',
                textAlign: TextAlign.center,
                style: _text(11, height: 15 / 11, color: _muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _BluetoothDeviceRow extends StatelessWidget {
  const _BluetoothDeviceRow({
    required this.device,
    required this.selected,
    required this.onTap,
  });

  final BluetoothDevice device;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final connected = device.status == ConnectivityItemStatus.connected;
    return Material(
      color: selected ? _connectivityTint : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _outline)),
          ),
          child: Row(
            children: [
              Icon(_bluetoothIcon(device.kind), size: 19, color: _body),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _text(
                        11,
                        height: 14 / 11,
                        weight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                    Text(
                      '${device.details} · ${connected ? 'Connected' : 'Not connected'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _text(
                        9,
                        height: 12 / 9,
                        color: connected ? _success : _muted,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusDot(active: connected),
              const SizedBox(width: 5),
              Text(
                connected ? 'Connected' : 'Not connected',
                style: _text(
                  9,
                  height: 12 / 9,
                  color: connected ? _body : _muted,
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.chevron_right_rounded, size: 17, color: _muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformConnectivityCard extends StatelessWidget {
  const _PlatformConnectivityCard({
    required this.state,
    required this.controller,
  });

  final ConnectivityState state;
  final ConnectivityController controller;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ConnectivityHeader(
            icon: Icons.cloud_outlined,
            title: 'Platform & API Connectivity',
            subtitle: 'Connect to Unitree services and cloud platform',
            compact: true,
            trailing: _SoftButton(
              label: 'Run diagnostic',
              icon: Icons.monitor_heart_outlined,
              onTap: () => _runConnectivityAction(
                context,
                controller.runDiagnostic(),
                success: 'Connectivity diagnostic completed',
                unavailable: 'Diagnostics are not connected yet',
              ),
            ),
          ),
          const SizedBox(height: 6),
          for (final connection in state.platformConnections)
            _PlatformRow(connection: connection),
        ],
      ),
    );
  }
}

class _PlatformRow extends StatelessWidget {
  const _PlatformRow({required this.connection});

  final PlatformConnection connection;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 29),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _outline)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Text(
              connection.label,
              style: _text(10, height: 13 / 10, color: _body),
            ),
          ),
          _StatusDot(
            active:
                connection.status == ConnectivityItemStatus.connected ||
                connection.status == ConnectivityItemStatus.active ||
                connection.status == ConnectivityItemStatus.available,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              connection.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _text(10, height: 13 / 10, color: _ink),
            ),
          ),
          Flexible(
            child: Text(
              connection.detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: _text(9, height: 12 / 9, color: _muted),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 16, color: _muted),
        ],
      ),
    );
  }
}

class _ConnectivitySidebar extends StatelessWidget {
  const _ConnectivitySidebar({required this.state, this.horizontal = false});

  final ConnectivityState state;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _ConnectivityStatusCard(state: state),
      const _NetworkAttentionCard(),
      _RecentConnectionsCard(items: state.recentConnections),
    ];
    if (!horizontal) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i != cards.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i != cards.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
            const SizedBox(width: 12),
            Expanded(child: cards[2]),
          ],
        );
      },
    );
  }
}

class _ConnectivityStatusCard extends StatelessWidget {
  const _ConnectivityStatusCard({required this.state});

  final ConnectivityState state;

  @override
  Widget build(BuildContext context) {
    final wifiConnected =
        state.wifiEnabled &&
        state.wifiNetworks.any(
          (item) => item.status == ConnectivityItemStatus.connected,
        );
    final bluetoothActive =
        state.bluetoothEnabled &&
        state.bluetoothDevices.any(
          (item) => item.status == ConnectivityItemStatus.connected,
        );
    final platformOnline = state.platformConnections.any(
      (item) =>
          item.label == 'Backend status' &&
          item.status == ConnectivityItemStatus.connected,
    );
    final online = wifiConnected && bluetoothActive && platformOnline;
    return _GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: () => _showConnectivityMessage(
          context,
          online
              ? 'All local connectivity systems are active'
              : 'Review disabled connections',
        ),
        borderRadius: BorderRadius.circular(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConnectivityIcon(
              icon: Icons.wifi_rounded,
              color: online ? _success : _warning,
              background: online
                  ? _connectivityGreenTint
                  : const Color(0xFFFFF5D9),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connectivity status',
                    style: _text(
                      13,
                      height: 17 / 13,
                      weight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    online
                        ? 'Online · Wi-Fi and Bluetooth active'
                        : 'Attention required',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _text(
                      10,
                      height: 14 / 10,
                      weight: FontWeight.w600,
                      color: online ? _success : _warning,
                    ),
                  ),
                  Text(
                    online
                        ? 'All systems connected'
                        : 'One or more radios are off',
                    style: _text(10, height: 14 / 10, color: _muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 19, color: _body),
          ],
        ),
      ),
    );
  }
}

class _NetworkAttentionCard extends StatelessWidget {
  const _NetworkAttentionCard();

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      radius: 20,
      color: _connectivityRedTint.withValues(alpha: 0.82),
      borderColor: const Color(0x66FF4C45),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ConnectivityIcon(
                icon: Icons.warning_amber_rounded,
                color: _danger,
                background: Color(0xFFFFDEDB),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Network attention',
                      style: _text(
                        13,
                        height: 17 / 13,
                        weight: FontWeight.w600,
                        color: _danger,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Guest networks may limit platform access. For full functionality, use a trusted network with internet access.',
                      style: _text(10, height: 15 / 10, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: _SoftButton(
              label: 'Learn more',
              danger: true,
              onTap: () => _showConnectivityMessage(
                context,
                'Trusted networks allow complete platform access',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentConnectionsCard extends StatelessWidget {
  const _RecentConnectionsCard({required this.items});

  final List<RecentConnection> items;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _ConnectivityIcon(
                icon: Icons.history_rounded,
                color: _purple,
                background: _connectivityTint,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Recent connections',
                  style: _text(
                    13,
                    height: 17 / 13,
                    weight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ),
              _SoftButton(
                label: 'View all',
                onTap: () => _showConnectivityMessage(
                  context,
                  'All recent connections are shown',
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          for (final item in items)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _outline)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _StatusDot(
                      active:
                          item.status != ConnectivityItemStatus.disconnected,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _text(10, height: 13 / 10, color: _body),
                        ),
                        Text(
                          item.details,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _text(9, height: 12 / 9, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    item.time,
                    style: _text(9, height: 12 / 9, color: _muted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PortsAndPeripherals extends StatelessWidget {
  const _PortsAndPeripherals({
    required this.state,
    required this.controller,
    this.compact = false,
  });

  final ConnectivityState state;
  final ConnectivityController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      radius: 20,
      padding: EdgeInsets.all(compact ? 12 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _ConnectivityIcon(
                icon: Icons.hub_outlined,
                color: _purple,
                background: _connectivityTint,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ports & peripherals',
                      style: _text(
                        15,
                        height: 20 / 15,
                        weight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                    Text(
                      'View and manage hardware ports and connected peripherals',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _text(10, height: 13 / 10, color: _muted),
                    ),
                  ],
                ),
              ),
              _SoftButton(
                label: 'Refresh',
                icon: Icons.refresh_rounded,
                onTap: () => _runConnectivityAction(
                  context,
                  controller.refresh(),
                  success: 'Peripherals refreshed',
                  unavailable: 'Peripheral refresh is not connected yet',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final portList = _PeripheralList(
                state: state,
                controller: controller,
              );
              final audio = _DefaultAudioCard(
                state: state,
                controller: controller,
              );
              if (constraints.maxWidth < 850 || compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [portList, const SizedBox(height: 12), audio],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: portList),
                  const SizedBox(width: 16),
                  SizedBox(width: 350, child: audio),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PeripheralList extends StatelessWidget {
  const _PeripheralList({required this.state, required this.controller});

  final ConnectivityState state;
  final ConnectivityController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) {
          return Column(
            children: [
              for (final port in state.peripherals)
                _PeripheralRow(
                  port: port,
                  selected: state.selectedPeripheralId == port.id,
                  onTap: () => controller.selectPeripheral(port.id),
                ),
            ],
          );
        }
        final split = (state.peripherals.length + 1) ~/ 2;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  for (final port in state.peripherals.take(split))
                    _PeripheralRow(
                      port: port,
                      selected: state.selectedPeripheralId == port.id,
                      onTap: () => controller.selectPeripheral(port.id),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(width: 1, height: 116, color: _outline),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  for (final port in state.peripherals.skip(split))
                    _PeripheralRow(
                      port: port,
                      selected: state.selectedPeripheralId == port.id,
                      onTap: () => controller.selectPeripheral(port.id),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PeripheralRow extends StatelessWidget {
  const _PeripheralRow({
    required this.port,
    required this.selected,
    required this.onTap,
  });

  final PeripheralPort port;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _connectivityTint : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          height: 34,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Row(
              children: [
                Icon(_peripheralIcon(port.kind), size: 18, color: _body),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        flex: 4,
                        child: Text(
                          port.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _text(
                            10,
                            height: 13 / 10,
                            weight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        flex: 5,
                        child: Text(
                          port.details,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _text(9, height: 12 / 9, color: _muted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _ConnectivityBadge(status: port.status),
                const SizedBox(width: 5),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: _muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DefaultAudioCard extends StatelessWidget {
  const _DefaultAudioCard({required this.state, required this.controller});

  final ConnectivityState state;
  final ConnectivityController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F6FF),
        border: Border.all(color: _outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_outlined, size: 17, color: _purple),
              const SizedBox(width: 9),
              Text(
                'Default audio devices',
                style: _text(
                  12,
                  height: 16 / 12,
                  weight: FontWeight.w600,
                  color: _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          _AudioSelectRow(
            label: 'Default input',
            child: _ConnectivityDropdown(
              key: const Key('connectivity-default-input'),
              value: state.defaultInput,
              items: {for (final item in state.inputOptions) item: item},
              onChanged: controller.setDefaultInput,
            ),
          ),
          const SizedBox(height: 7),
          _AudioSelectRow(
            label: 'Default output',
            child: _ConnectivityDropdown(
              key: const Key('connectivity-default-output'),
              value: state.defaultOutput,
              items: {for (final item in state.outputOptions) item: item},
              onChanged: controller.setDefaultOutput,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 15, color: _muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'These devices are used by default for system audio, voice assistant, and teleoperation.',
                  style: _text(9, height: 13 / 9, color: _muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AudioSelectRow extends StatelessWidget {
  const _AudioSelectRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: _text(10, height: 13 / 10, color: _body),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _ConnectivityHeader extends StatelessWidget {
  const _ConnectivityHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ConnectivityIcon(
          icon: icon,
          color: _purple,
          background: _connectivityTint,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _text(
                  compact ? 13 : 15,
                  height: compact ? 17 / 13 : 20 / 15,
                  weight: FontWeight.w600,
                  color: _ink,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _text(9, height: 12 / 9, color: _muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    );
  }
}

class _ConnectivityIcon extends StatelessWidget {
  const _ConnectivityIcon({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }
}

class _SelectRow extends StatelessWidget {
  const _SelectRow({
    required this.label,
    required this.helper,
    required this.child,
  });

  final String label;
  final String helper;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: _text(
                  11,
                  height: 14 / 11,
                  weight: FontWeight.w600,
                  color: _body,
                ),
              ),
              Text(
                helper,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _text(9, height: 12 / 9, color: _muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        child,
      ],
    );
  }
}

class _ConnectivityDropdown extends StatelessWidget {
  const _ConnectivityDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 142, maxWidth: 230),
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.9),
        border: Border.all(color: _outline),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 17),
          style: _text(10, height: 13 / 10, color: _body),
          items: [
            for (final item in items.entries)
              DropdownMenuItem(value: item.key, child: Text(item.value)),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

class _SoftButton extends StatelessWidget {
  const _SoftButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.success = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool success;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final foreground = danger
        ? _danger
        : success
        ? _success
        : _purple;
    final background = danger
        ? const Color(0xFFFFDEDB)
        : success
        ? _connectivityGreenTint
        : _control;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: foreground),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _text(
                      10,
                      height: 13 / 10,
                      weight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _purple),
            const SizedBox(width: 5),
            Text(
              label,
              style: _text(
                10,
                height: 13 / 10,
                weight: FontWeight.w600,
                color: _purple,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryConnectivityButton extends StatelessWidget {
  const _PrimaryConnectivityButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _purple,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 34,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 7),
              Text(
                label,
                style: _text(
                  11,
                  height: 14 / 11,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? _success : _dot,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ConnectivityBadge extends StatelessWidget {
  const _ConnectivityBadge({required this.status});

  final ConnectivityItemStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, foreground, background) = switch (status) {
      ConnectivityItemStatus.connected => (
        'Connected',
        _success,
        _connectivityGreenTint,
      ),
      ConnectivityItemStatus.active => (
        'Active',
        _success,
        _connectivityGreenTint,
      ),
      ConnectivityItemStatus.available => (
        'Available',
        _success,
        _connectivityGreenTint,
      ),
      ConnectivityItemStatus.idle => (
        'Available · Idle',
        _body,
        const Color(0xFFF0F3FA),
      ),
      ConnectivityItemStatus.disconnected => (
        'Not connected',
        _muted,
        const Color(0xFFF0F3FA),
      ),
      ConnectivityItemStatus.unavailable => (
        'Unavailable',
        _danger,
        _connectivityRedTint,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: _text(
          9,
          height: 11 / 9,
          weight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

IconData _bluetoothIcon(String kind) => switch (kind) {
  'controller' => Icons.sports_esports_outlined,
  'headphones' => Icons.headphones_outlined,
  'sensor' => Icons.memory_outlined,
  'tablet' => Icons.tablet_mac_outlined,
  _ => Icons.bluetooth_rounded,
};

IconData _peripheralIcon(String kind) => switch (kind) {
  'microphone' => Icons.mic_none_rounded,
  'speaker' => Icons.volume_up_outlined,
  'usb' => Icons.usb_rounded,
  'controller' => Icons.sports_esports_outlined,
  'camera' => Icons.camera_alt_outlined,
  'sensor' => Icons.sensors_outlined,
  'expansion' => Icons.memory_outlined,
  _ => Icons.cable_rounded,
};

Future<void> _runConnectivityAction(
  BuildContext context,
  Future<bool> action, {
  required String success,
  required String unavailable,
}) async {
  try {
    final completed = await action;
    if (!context.mounted) return;
    _showConnectivityMessage(context, completed ? success : unavailable);
  } on Object {
    if (!context.mounted) return;
    _showConnectivityMessage(context, 'Connectivity action failed');
  }
}

void _showConnectivityMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
}
