part of 'settings_screen.dart';

/// Robot microphone and speaker selection, shown under the connection cards.
class _AudioDevicesCard extends ConsumerWidget {
  const _AudioDevicesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioDevicesProvider);
    final controller = ref.read(audioDevicesProvider.notifier);
    final notice = !state.available
        ? (state.unavailableReason!, Icons.info_outline_rounded, _warning)
        : state.error != null
        ? (state.error!, Icons.error_outline_rounded, _danger)
        : state.simulated
        ? (
            'Demo Mode · simulated devices. Nothing is recorded or played.',
            Icons.science_outlined,
            _muted,
          )
        : null;

    return _GlassCard(
      key: const Key('audio-devices-card'),
      radius: AppSpacing.radiusLarge,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final refresh = OutlinedButton.icon(
                key: const Key('audio-refresh'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  backgroundColor: _control.withValues(alpha: .5),
                ),
                onPressed: state.loading || !state.available
                    ? null
                    : controller.refresh,
                icon: state.loading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh devices'),
              );
              final heading = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _RobotConnectionIcon(Icons.volume_up_outlined),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Audio devices',
                          style: _text(
                            20,
                            height: 1.3,
                            weight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Configure microphone and speaker devices connected '
                          'to your Unitree G1.',
                          style: _text(14, height: 1.5, color: _muted),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    const SizedBox(height: AppSpacing.sm),
                    refresh,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: AppSpacing.md),
                  refresh,
                ],
              );
            },
          ),
          if (notice != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              key: const Key('audio-notice'),
              children: [
                Icon(notice.$2, size: 16, color: notice.$3),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    notice.$1,
                    style: _text(13, height: 1.4, color: notice.$3),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              const input = _AudioDeviceColumn(AudioDeviceDirection.input);
              const output = _AudioDeviceColumn(AudioDeviceDirection.output);
              if (constraints.maxWidth < 720) {
                return const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    input,
                    Divider(height: AppSpacing.xl, color: _outline),
                    output,
                  ],
                );
              }
              return Row(
                key: const Key('audio-two-columns'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: DecoratedBox(
                      // Subtle divider between input and output.
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: _outline)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(right: AppSpacing.lg),
                        child: input,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  const Expanded(child: output),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AudioDeviceColumn extends ConsumerWidget {
  const _AudioDeviceColumn(this.direction);

  final AudioDeviceDirection direction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioDevicesProvider);
    final controller = ref.read(audioDevicesProvider.notifier);
    final input = direction == AudioDeviceDirection.input;
    final name = input ? 'input' : 'output';
    final devices = state.devicesFor(direction);
    final selectedId = state.selectedId(direction);
    final selected = state.device(direction, selectedId);
    final activeId = state.activeId(direction);
    final test = state.test(direction);
    final running = test == AudioTestState.running;
    final busy = state.loading || state.applying;
    // Keep an unplugged or vanished selection visible instead of hiding it.
    final missing = selectedId != null && selected == null && !state.loading;

    final items = [
      for (final device in devices)
        DropdownMenuItem(
          value: device.id,
          enabled: device.connected,
          child: Text(
            '${device.name}'
            '${device.simulated ? ' (simulated)' : ''}'
            '${device.connected ? '' : ' — disconnected'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: device.connected ? null : const TextStyle(color: _muted),
          ),
        ),
      if (missing && state.available)
        DropdownMenuItem(
          value: selectedId,
          enabled: false,
          child: const Text(
            'Saved device not found',
            style: TextStyle(color: _muted),
          ),
        ),
    ];
    final hint = !state.available
        ? 'Unavailable'
        : state.loading && devices.isEmpty
        ? 'Discovering devices…'
        : devices.isEmpty
        ? (input ? 'No microphones found' : 'No speakers found')
        : (input ? 'Select a microphone' : 'Select a speaker');

    final (status, statusColor) = switch (null) {
      _ when !state.available => ('Not available on the robot.', _muted),
      _ when running => (state.testMessage(direction) ?? 'Testing…', _purple),
      _ when state.applying && selectedId != activeId => (
        'Applying on the robot…',
        _purple,
      ),
      _ when missing || (selected != null && !selected.connected) => (
        'Selected device is disconnected. The robot keeps its current device.',
        _warning,
      ),
      _
          when test != AudioTestState.idle &&
              state.testMessage(direction) != null =>
        (
          state.testMessage(direction)!,
          test == AudioTestState.failed ? _danger : _muted,
        ),
      _ when selectedId != null && selectedId == activeId => (
        state.simulated ? 'Active (simulated).' : 'Active on the robot.',
        _success,
      ),
      _ when selectedId != null && activeId != selectedId => (
        'Not active yet. The robot reports '
            '${state.device(direction, activeId)?.name ?? 'its own default'}.',
        _warning,
      ),
      _ => ('', _muted),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _purple.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall + 2),
          ),
          child: Icon(
            input ? Icons.mic_none_rounded : Icons.volume_up_outlined,
            size: 20,
            color: _purple,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                input ? 'Microphone (Input)' : 'Speaker (Output)',
                style: _text(
                  16,
                  height: 1.4,
                  weight: FontWeight.w600,
                  color: _ink,
                ),
              ),
              Text(
                input ? 'Select microphone device.' : 'Select speaker device.',
                style: _text(13, height: 1.4, color: _muted),
              ),
              const SizedBox(height: AppSpacing.sm),
              // initialValue is read once; rebuild when discovery or the
              // confirmed selection changes.
              KeyedSubtree(
                key: ValueKey(
                  '$selectedId|${state.available}|'
                  '${items.map((i) => '${i.value}:${i.enabled}').join(',')}',
                ),
                child: DropdownButtonFormField<String>(
                  key: Key('audio-$name-select'),
                  initialValue: items.any((i) => i.value == selectedId)
                      ? selectedId
                      : null,
                  isExpanded: true,
                  hint: Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: _surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMedium,
                      ),
                      borderSide: const BorderSide(color: _outline),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMedium,
                      ),
                      borderSide: const BorderSide(color: _outline),
                    ),
                  ),
                  items: items,
                  onChanged: state.available && !busy && !running
                      ? (id) {
                          if (id != null) controller.select(direction, id);
                        }
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  key: Key('audio-$name-test'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    backgroundColor: _control.withValues(alpha: .5),
                  ),
                  onPressed:
                      running ||
                          (state.available &&
                              !busy &&
                              selected != null &&
                              selected.connected)
                      ? () => controller.toggleTest(direction)
                      : null,
                  icon: Icon(
                    running
                        ? Icons.stop_rounded
                        : input
                        ? Icons.mic_none_rounded
                        : Icons.play_arrow_rounded,
                    size: 18,
                  ),
                  label: Text(
                    running
                        ? 'Cancel test'
                        : input
                        ? 'Test microphone'
                        : 'Test speaker',
                  ),
                ),
              ),
              if (status.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  status,
                  key: Key('audio-$name-status'),
                  style: _text(12.5, height: 1.4, color: statusColor),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
