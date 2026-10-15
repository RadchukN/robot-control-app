import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SettingsCategory {
  general('General', 'Identity, region and startup'),
  robot('Robot', 'Hardware, firmware and calibration'),
  connectivity('Connectivity', 'Wi-Fi, Ethernet and remote access'),
  safety('Safety', 'Limits, stop behavior and authority'),
  ai('AI', 'Models, privacy and confirmation'),
  vision('Vision', 'Cameras, overlays and retention'),
  audio('Audio', 'Devices, monitoring and recording'),
  controller('Controller', 'Input devices and mappings'),
  automation('Automation', 'Defaults, approvals and notifications'),
  storage('Storage', 'Capacity, cleanup and export'),
  notifications('Notifications', 'Channels and severity'),
  appearance('Appearance', 'Theme, density and contrast'),
  accessibility('Accessibility', 'Scale, motion and focus'),
  integrations('Integrations', 'API access and connected services'),
  diagnostics('Diagnostics', 'Health, tests and support bundle'),
  about('About', 'Version, licenses and updates');

  const SettingsCategory(this.label, this.description);

  final String label;
  final String description;

  bool get hasPanel =>
      this == SettingsCategory.general ||
      this == SettingsCategory.connectivity ||
      this == SettingsCategory.safety ||
      this == SettingsCategory.appearance;
}

enum SettingsSyncStatus {
  saved('Saved', 'Changes are synchronized.'),
  unsaved('Unsaved', 'Review or discard edits.'),
  restartRequired('Restart required', 'Apply after safe restart.'),
  warning('Warning', 'Setting reduces protection.'),
  danger('Danger', 'Elevated authority required.'),
  offline('Offline', 'Editing is read-only.'),
  noRobot('No robot', 'Robot-specific fields unavailable.');

  const SettingsSyncStatus(this.label, this.description);

  final String label;
  final String description;
}

class SettingsState {
  const SettingsState({
    this.category = SettingsCategory.general,
    this.searchQuery = '',
    this.searchVisible = false,
    this.robotDisplayName = 'G1 Gustav',
    this.defaultWorkspace = 'Dashboard',
    this.startupModule = 'Last used',
    this.timeZone = 'Europe / Prague',
    this.units = 'Metric',
    this.language = 'English',
    this.restoreLastRobot = true,
    this.openLastWorkspace = true,
    this.collisionAvoidance = true,
    this.humanProximityStop = true,
    this.maximumRobotSpeed = '0.60 m/s',
    this.commandConfirmation = true,
    this.controlOwnership = 'Exclusive',
    this.syncStatus = SettingsSyncStatus.saved,
    this.audioInputDeviceId,
    this.audioOutputDeviceId,
  });

  final SettingsCategory category;
  final String searchQuery;
  final bool searchVisible;
  final String robotDisplayName;
  final String defaultWorkspace;
  final String startupModule;
  final String timeZone;
  final String units;
  final String language;
  final bool restoreLastRobot;
  final bool openLastWorkspace;
  final bool collisionAvoidance;
  final bool humanProximityStop;
  final String maximumRobotSpeed;
  final bool commandConfirmation;
  final String controlOwnership;
  final SettingsSyncStatus syncStatus;

  /// Desired robot audio devices as stable backend ids. Null means the
  /// robot's own configuration. What is active is reported by the backend.
  final String? audioInputDeviceId;
  final String? audioOutputDeviceId;

  SettingsState copyWith({
    SettingsCategory? category,
    String? searchQuery,
    bool? searchVisible,
    bool? restoreLastRobot,
    bool? openLastWorkspace,
    bool? collisionAvoidance,
    bool? humanProximityStop,
    bool? commandConfirmation,
    SettingsSyncStatus? syncStatus,
    Object? audioInputDeviceId = _unsetDevice,
    Object? audioOutputDeviceId = _unsetDevice,
  }) {
    return SettingsState(
      category: category ?? this.category,
      searchQuery: searchQuery ?? this.searchQuery,
      searchVisible: searchVisible ?? this.searchVisible,
      robotDisplayName: robotDisplayName,
      defaultWorkspace: defaultWorkspace,
      startupModule: startupModule,
      timeZone: timeZone,
      units: units,
      language: language,
      restoreLastRobot: restoreLastRobot ?? this.restoreLastRobot,
      openLastWorkspace: openLastWorkspace ?? this.openLastWorkspace,
      collisionAvoidance: collisionAvoidance ?? this.collisionAvoidance,
      humanProximityStop: humanProximityStop ?? this.humanProximityStop,
      maximumRobotSpeed: maximumRobotSpeed,
      commandConfirmation: commandConfirmation ?? this.commandConfirmation,
      controlOwnership: controlOwnership,
      syncStatus: syncStatus ?? this.syncStatus,
      audioInputDeviceId: identical(audioInputDeviceId, _unsetDevice)
          ? this.audioInputDeviceId
          : audioInputDeviceId as String?,
      audioOutputDeviceId: identical(audioOutputDeviceId, _unsetDevice)
          ? this.audioOutputDeviceId
          : audioOutputDeviceId as String?,
    );
  }
}

const _unsetDevice = Object();

/// Integration boundary for durable settings. It remains unbound until the API
/// exposes a settings contract; the current screen edits only a local draft.
abstract interface class SettingsPersistence {
  Future<void> save(SettingsState settings);
}

final settingsPersistenceProvider = Provider<SettingsPersistence?>(
  (ref) => null,
);

class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() => const SettingsState();

  void selectCategory(SettingsCategory category) {
    state = state.copyWith(category: category, searchVisible: false);
  }

  void setSearchVisible(bool visible) {
    state = state.copyWith(searchVisible: visible);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setAudioInputDevice(String? deviceId) =>
      state = state.copyWith(audioInputDeviceId: deviceId);

  void setAudioOutputDevice(String? deviceId) =>
      state = state.copyWith(audioOutputDeviceId: deviceId);

  void toggleRestoreLastRobot() {
    state = state.copyWith(
      restoreLastRobot: !state.restoreLastRobot,
      syncStatus: SettingsSyncStatus.unsaved,
    );
  }

  void toggleOpenLastWorkspace() {
    state = state.copyWith(
      openLastWorkspace: !state.openLastWorkspace,
      syncStatus: SettingsSyncStatus.unsaved,
    );
  }

  void toggleCollisionAvoidance() {
    final enabled = !state.collisionAvoidance;
    state = state.copyWith(
      collisionAvoidance: enabled,
      syncStatus: enabled
          ? SettingsSyncStatus.unsaved
          : SettingsSyncStatus.warning,
    );
  }

  void toggleHumanProximityStop() {
    final enabled = !state.humanProximityStop;
    state = state.copyWith(
      humanProximityStop: enabled,
      syncStatus: enabled
          ? SettingsSyncStatus.unsaved
          : SettingsSyncStatus.danger,
    );
  }

  void toggleCommandConfirmation() {
    final enabled = !state.commandConfirmation;
    state = state.copyWith(
      commandConfirmation: enabled,
      syncStatus: enabled
          ? SettingsSyncStatus.unsaved
          : SettingsSyncStatus.warning,
    );
  }
}

final settingsProvider = NotifierProvider<SettingsController, SettingsState>(
  SettingsController.new,
  name: 'SettingsProvider',
);
