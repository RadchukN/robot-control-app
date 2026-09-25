import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectivityItemStatus {
  connected,
  active,
  available,
  idle,
  disconnected,
  unavailable,
}

class WifiNetwork {
  const WifiNetwork({
    required this.id,
    required this.name,
    required this.details,
    required this.signalLevel,
    required this.secured,
    required this.status,
    this.signalDescription,
    this.ipAddress,
    this.security,
    this.connectionQuality,
  });

  final String id;
  final String name;
  final String details;
  final int signalLevel;
  final bool secured;
  final ConnectivityItemStatus status;
  final String? signalDescription;
  final String? ipAddress;
  final String? security;
  final String? connectionQuality;

  WifiNetwork copyWith({ConnectivityItemStatus? status}) => WifiNetwork(
    id: id,
    name: name,
    details: details,
    signalLevel: signalLevel,
    secured: secured,
    status: status ?? this.status,
    signalDescription: signalDescription,
    ipAddress: ipAddress,
    security: security,
    connectionQuality: connectionQuality,
  );
}

class PlatformConnection {
  const PlatformConnection({
    required this.label,
    required this.value,
    required this.detail,
    required this.status,
  });

  final String label;
  final String value;
  final String detail;
  final ConnectivityItemStatus status;
}

class BluetoothDevice {
  const BluetoothDevice({
    required this.id,
    required this.name,
    required this.details,
    required this.kind,
    required this.status,
  });

  final String id;
  final String name;
  final String details;
  final String kind;
  final ConnectivityItemStatus status;

  BluetoothDevice copyWith({ConnectivityItemStatus? status}) => BluetoothDevice(
    id: id,
    name: name,
    details: details,
    kind: kind,
    status: status ?? this.status,
  );
}

class PeripheralPort {
  const PeripheralPort({
    required this.id,
    required this.name,
    required this.details,
    required this.kind,
    required this.status,
  });

  final String id;
  final String name;
  final String details;
  final String kind;
  final ConnectivityItemStatus status;
}

class RecentConnection {
  const RecentConnection({
    required this.title,
    required this.details,
    required this.time,
    required this.status,
  });

  final String title;
  final String details;
  final String time;
  final ConnectivityItemStatus status;
}

class ConnectivityState {
  const ConnectivityState({
    this.wifiEnabled = true,
    this.bluetoothEnabled = true,
    this.discoverable = true,
    this.autoConnect = true,
    this.preferredWifiId = 'robotics-lab-5g',
    this.selectedWifiId = 'robotics-lab-5g',
    this.selectedBluetoothId,
    this.selectedPeripheralId,
    this.defaultInput = 'G1 Array Microphone',
    this.defaultOutput = 'Chest speaker',
    this.wifiNetworks = _initialWifiNetworks,
    this.bluetoothDevices = _initialBluetoothDevices,
    this.peripherals = _initialPeripherals,
    this.recentConnections = _initialRecentConnections,
    this.platformConnections = _initialPlatformConnections,
    this.inputOptions = _inputOptions,
    this.outputOptions = _outputOptions,
  });

  final bool wifiEnabled;
  final bool bluetoothEnabled;
  final bool discoverable;
  final bool autoConnect;
  final String preferredWifiId;
  final String selectedWifiId;
  final String? selectedBluetoothId;
  final String? selectedPeripheralId;
  final String defaultInput;
  final String defaultOutput;
  final List<WifiNetwork> wifiNetworks;
  final List<BluetoothDevice> bluetoothDevices;
  final List<PeripheralPort> peripherals;
  final List<RecentConnection> recentConnections;
  final List<PlatformConnection> platformConnections;
  final List<String> inputOptions;
  final List<String> outputOptions;

  ConnectivityState copyWith({
    bool? wifiEnabled,
    bool? bluetoothEnabled,
    bool? discoverable,
    bool? autoConnect,
    String? preferredWifiId,
    String? selectedWifiId,
    Object? selectedBluetoothId = _unset,
    Object? selectedPeripheralId = _unset,
    String? defaultInput,
    String? defaultOutput,
    List<WifiNetwork>? wifiNetworks,
    List<BluetoothDevice>? bluetoothDevices,
  }) => ConnectivityState(
    wifiEnabled: wifiEnabled ?? this.wifiEnabled,
    bluetoothEnabled: bluetoothEnabled ?? this.bluetoothEnabled,
    discoverable: discoverable ?? this.discoverable,
    autoConnect: autoConnect ?? this.autoConnect,
    preferredWifiId: preferredWifiId ?? this.preferredWifiId,
    selectedWifiId: selectedWifiId ?? this.selectedWifiId,
    selectedBluetoothId: identical(selectedBluetoothId, _unset)
        ? this.selectedBluetoothId
        : selectedBluetoothId as String?,
    selectedPeripheralId: identical(selectedPeripheralId, _unset)
        ? this.selectedPeripheralId
        : selectedPeripheralId as String?,
    defaultInput: defaultInput ?? this.defaultInput,
    defaultOutput: defaultOutput ?? this.defaultOutput,
    wifiNetworks: wifiNetworks ?? this.wifiNetworks,
    bluetoothDevices: bluetoothDevices ?? this.bluetoothDevices,
    peripherals: peripherals,
    recentConnections: recentConnections,
    platformConnections: platformConnections,
    inputOptions: inputOptions,
    outputOptions: outputOptions,
  );
}

const _unset = Object();

abstract interface class ConnectivityGateway {
  Future<ConnectivityState> refresh();
  Future<void> runDiagnostic();
}

final connectivityGatewayProvider = Provider<ConnectivityGateway?>(
  (ref) => null,
);

class ConnectivityController extends Notifier<ConnectivityState> {
  @override
  ConnectivityState build() => const ConnectivityState();

  void toggleWifi() => state = state.copyWith(wifiEnabled: !state.wifiEnabled);

  void toggleBluetooth() =>
      state = state.copyWith(bluetoothEnabled: !state.bluetoothEnabled);

  void toggleDiscoverable() =>
      state = state.copyWith(discoverable: !state.discoverable);

  void toggleAutoConnect() =>
      state = state.copyWith(autoConnect: !state.autoConnect);

  void selectWifi(String id) => state = state.copyWith(selectedWifiId: id);

  void connectWifi(String id) {
    state = state.copyWith(
      selectedWifiId: id,
      wifiNetworks: [
        for (final network in state.wifiNetworks)
          network.copyWith(
            status: network.id == id
                ? ConnectivityItemStatus.connected
                : ConnectivityItemStatus.available,
          ),
      ],
    );
  }

  void disconnectWifi(String id) {
    state = state.copyWith(
      wifiNetworks: [
        for (final network in state.wifiNetworks)
          network.id == id
              ? network.copyWith(status: ConnectivityItemStatus.available)
              : network,
      ],
    );
  }

  void setPreferredWifi(String id) =>
      state = state.copyWith(preferredWifiId: id);

  void selectBluetoothDevice(String id) =>
      state = state.copyWith(selectedBluetoothId: id);

  void toggleBluetoothDevice(String id) {
    state = state.copyWith(
      selectedBluetoothId: id,
      bluetoothDevices: [
        for (final device in state.bluetoothDevices)
          device.id == id
              ? device.copyWith(
                  status: device.status == ConnectivityItemStatus.connected
                      ? ConnectivityItemStatus.disconnected
                      : ConnectivityItemStatus.connected,
                )
              : device,
      ],
    );
  }

  void selectPeripheral(String id) =>
      state = state.copyWith(selectedPeripheralId: id);

  void setDefaultInput(String value) =>
      state = state.copyWith(defaultInput: value);

  void setDefaultOutput(String value) =>
      state = state.copyWith(defaultOutput: value);

  Future<bool> refresh() async {
    final gateway = ref.read(connectivityGatewayProvider);
    if (gateway == null) return false;
    state = await gateway.refresh();
    return true;
  }

  Future<bool> runDiagnostic() async {
    final gateway = ref.read(connectivityGatewayProvider);
    if (gateway == null) return false;
    await gateway.runDiagnostic();
    return true;
  }
}

final connectivityProvider =
    NotifierProvider<ConnectivityController, ConnectivityState>(
      ConnectivityController.new,
      name: 'ConnectivityProvider',
    );

const _initialWifiNetworks = [
  WifiNetwork(
    id: 'robotics-lab-5g',
    name: 'RoboticsLab_5G',
    details: 'Connected',
    signalLevel: 4,
    secured: true,
    status: ConnectivityItemStatus.connected,
    signalDescription: '-42 dBm (Excellent)',
    ipAddress: '192.168.1.104',
    security: 'WPA2 / WPA3',
    connectionQuality: 'Excellent',
  ),
  WifiNetwork(
    id: 'robotics-lab-24',
    name: 'RoboticsLab_2.4G',
    details: 'Secured · 2.4 GHz',
    signalLevel: 4,
    secured: true,
    status: ConnectivityItemStatus.available,
  ),
  WifiNetwork(
    id: 'office-wifi',
    name: 'Office_WiFi',
    details: 'Secured · 2.4 GHz',
    signalLevel: 4,
    secured: true,
    status: ConnectivityItemStatus.available,
  ),
  WifiNetwork(
    id: 'guest-network',
    name: 'Guest_Network',
    details: 'Open network',
    signalLevel: 3,
    secured: false,
    status: ConnectivityItemStatus.available,
  ),
  WifiNetwork(
    id: 'unitree-hotspot',
    name: 'Unitree_Hotspot',
    details: 'Secured · 5 GHz',
    signalLevel: 3,
    secured: true,
    status: ConnectivityItemStatus.available,
  ),
];

const _initialBluetoothDevices = [
  BluetoothDevice(
    id: 'g1-controller',
    name: 'G1 Controller',
    details: 'Paired',
    kind: 'controller',
    status: ConnectivityItemStatus.connected,
  ),
  BluetoothDevice(
    id: 'sony-headphones',
    name: 'Sony WH-1000XM5',
    details: 'Paired',
    kind: 'headphones',
    status: ConnectivityItemStatus.disconnected,
  ),
  BluetoothDevice(
    id: 'lidar-sensor',
    name: 'LiDAR Sensor',
    details: 'Paired',
    kind: 'sensor',
    status: ConnectivityItemStatus.connected,
  ),
  BluetoothDevice(
    id: 'operator-tablet',
    name: 'Operator Tablet',
    details: 'Paired',
    kind: 'tablet',
    status: ConnectivityItemStatus.disconnected,
  ),
];

const _initialPeripherals = [
  PeripheralPort(
    id: 'microphone',
    name: 'Microphone input',
    details: 'G1 array microphone (voice input)',
    kind: 'microphone',
    status: ConnectivityItemStatus.available,
  ),
  PeripheralPort(
    id: 'speaker',
    name: 'Speaker output',
    details: 'Chest speaker (audio output)',
    kind: 'speaker',
    status: ConnectivityItemStatus.active,
  ),
  PeripheralPort(
    id: 'usb-c',
    name: 'USB-C accessory port',
    details: 'USB 3.1 for accessories',
    kind: 'usb',
    status: ConnectivityItemStatus.idle,
  ),
  PeripheralPort(
    id: 'controller-dock',
    name: 'Controller dock',
    details: 'Gamepad receiver / charging dock',
    kind: 'controller',
    status: ConnectivityItemStatus.connected,
  ),
  PeripheralPort(
    id: 'external-camera',
    name: 'External camera port',
    details: 'USB camera input (vision)',
    kind: 'camera',
    status: ConnectivityItemStatus.disconnected,
  ),
  PeripheralPort(
    id: 'aux-sensor',
    name: 'Auxiliary sensor port',
    details: 'IMU / GPS / custom sensors',
    kind: 'sensor',
    status: ConnectivityItemStatus.available,
  ),
  PeripheralPort(
    id: 'expansion',
    name: 'Expansion port',
    details: 'GPIO / I2C / CAN (expansion)',
    kind: 'expansion',
    status: ConnectivityItemStatus.unavailable,
  ),
];

const _initialRecentConnections = [
  RecentConnection(
    title: 'Wi-Fi connected',
    details: 'RoboticsLab_5G',
    time: '14:18',
    status: ConnectivityItemStatus.connected,
  ),
  RecentConnection(
    title: 'Bluetooth device connected',
    details: 'G1 Controller',
    time: '14:16',
    status: ConnectivityItemStatus.connected,
  ),
  RecentConnection(
    title: 'Bluetooth device disconnected',
    details: 'Operator Tablet',
    time: '13:52',
    status: ConnectivityItemStatus.disconnected,
  ),
  RecentConnection(
    title: 'Platform synchronized',
    details: 'All data up to date',
    time: '13:27',
    status: ConnectivityItemStatus.connected,
  ),
  RecentConnection(
    title: 'Network scan completed',
    details: '5 networks found',
    time: '13:45',
    status: ConnectivityItemStatus.connected,
  ),
];

const _initialPlatformConnections = [
  PlatformConnection(
    label: 'Backend status',
    value: 'Online',
    detail: 'All services operational',
    status: ConnectivityItemStatus.connected,
  ),
  PlatformConnection(
    label: 'Robot link',
    value: 'Connected',
    detail: 'g1.unitree.com',
    status: ConnectivityItemStatus.connected,
  ),
  PlatformConnection(
    label: 'Latency (API)',
    value: '24 ms',
    detail: 'Excellent',
    status: ConnectivityItemStatus.connected,
  ),
  PlatformConnection(
    label: 'Sync mode',
    value: 'Real-time',
    detail: 'Bidirectional sync',
    status: ConnectivityItemStatus.connected,
  ),
];

const _inputOptions = [
  'G1 Array Microphone',
  'USB microphone',
  'Controller headset',
];

const _outputOptions = [
  'Chest speaker',
  'Sony WH-1000XM5',
  'Controller headset',
];
