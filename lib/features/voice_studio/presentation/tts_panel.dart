part of 'voice_studio_screen.dart';

class _TtsPanel extends ConsumerStatefulWidget {
  const _TtsPanel({required this.fill});

  final bool fill;

  @override
  ConsumerState<_TtsPanel> createState() => _TtsPanelState();
}

class _TtsPanelState extends ConsumerState<_TtsPanel> {
  late final TextEditingController _editor;

  @override
  void initState() {
    super.initState();
    _editor = TextEditingController(text: ref.read(ttsProvider).draft);
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  void _load(String text) {
    _editor.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    ref.read(ttsProvider.notifier).setDraft(text);
  }

  void _clear() {
    _editor.clear();
    ref.read(ttsProvider.notifier).clearDraft();
  }

  void _savePhrase() {
    final error = ref.read(savedPhrasesProvider.notifier).add(_editor.text);
    if (error == null) {
      _notify(context).success(
        'Phrase saved',
        description: 'Saved locally on this device.',
        key: 'saved-phrase',
      );
    } else {
      _notify(
        context,
      ).warning('Phrase not saved', description: error, key: 'saved-phrase');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ttsProvider);
    final controller = ref.read(ttsProvider.notifier);
    final phrases = ref.watch(savedPhrasesProvider);
    final length = ttsLength(state.draft);
    final over = length > state.maxLength;
    final editor = Stack(
      children: [
        Positioned.fill(
          child: TextField(
            key: const Key('tts-text'),
            controller: _editor,
            onChanged: controller.setDraft,
            enabled: !state.isBusy,
            expands: true,
            maxLines: null,
            textAlignVertical: TextAlignVertical.top,
            style: _text(13, height: 18 / 13),
            decoration: _fieldDecoration('Type what the robot should say...'),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 8,
          child: Text(
            '$length/${state.maxLength}',
            key: const Key('tts-counter'),
            style: _text(11, height: 14 / 11, color: over ? _red : _muted),
          ),
        ),
      ],
    );
    final speakButton = state.canStop || state.phase == TtsPhase.stopping
        ? _SoftButton(
            key: const Key('tts-stop'),
            label: state.phase == TtsPhase.stopping
                ? 'Stopping…'
                : 'Stop Speaking',
            icon: Icons.stop_rounded,
            color: _red,
            background: _redSoft,
            height: 46,
            onTap: state.canStop ? controller.stopSpeaking : null,
          )
        : _PrimaryButton(
            key: const Key('tts-speak'),
            label: 'Speak on G1',
            icon: Icons.play_arrow_rounded,
            height: 46,
            onTap: state.canSpeak ? controller.speak : null,
          );
    final status = _TtsStatusLine(state: state);

    return _Card(
      fill: widget.fill,
      minHeight: 340,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            icon: Icons.record_voice_over_outlined,
            title: 'Speak Custom Text',
            subtitle:
                'Type text and make the robot speak using text-to-speech.',
            trailing: [if (state.simulated) const _DemoBadge()],
          ),
          const SizedBox(height: 12),
          if (widget.fill)
            Expanded(child: editor)
          else
            SizedBox(height: 120, child: editor),
          const SizedBox(height: 10),
          _TtsSelectors(state: state),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final secondary = [
                Expanded(
                  flex: 3,
                  child: _SoftButton(
                    key: const Key('tts-save-phrase'),
                    label: 'Save phrase',
                    icon: Icons.bookmark_add_outlined,
                    height: 46,
                    onTap: validateTtsText(state.draft) == null
                        ? _savePhrase
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: _SoftButton(
                    key: const Key('tts-clear'),
                    label: 'Clear',
                    icon: Icons.delete_outline_rounded,
                    color: _red,
                    background: _redSoft,
                    height: 46,
                    onTap: state.draft.isEmpty || state.isBusy ? null : _clear,
                  ),
                ),
              ];
              // Phones get a full-width Speak button above the secondary actions.
              if (constraints.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    speakButton,
                    const SizedBox(height: 8),
                    Row(children: secondary),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 4, child: speakButton),
                  const SizedBox(width: 10),
                  ...secondary,
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          status,
          const SizedBox(height: 8),
          _SavedPhrases(
            phrases: phrases,
            enabled: !state.isBusy,
            onSelect: _load,
          ),
        ],
      ),
    );
  }
}

InputDecoration _fieldDecoration(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: _text(13, height: 18 / 13, color: _muted),
  contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 26),
  filled: true,
  fillColor: const Color(0xFFF6F7FC),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: _outline),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: _outline),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: _purple, width: 1.4),
  ),
);

class _TtsSelectors extends ConsumerWidget {
  const _TtsSelectors({required this.state});

  final TtsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(ttsProvider.notifier);
    final enabled = !state.isBusy && state.capabilities != null;
    final language = _Selector<String>(
      label: 'Language',
      icon: Icons.language_rounded,
      value: state.language,
      hint: 'Unavailable',
      items: [
        for (final language in displayLanguages)
          (
            language.code,
            state.supportsLanguage(language.code)
                ? language.label
                : '${language.label} (unsupported)',
            state.supportsLanguage(language.code),
          ),
      ],
      onChanged: enabled ? controller.setLanguage : null,
    );
    final voice = _Selector<String>(
      label: 'Voice',
      icon: Icons.graphic_eq_rounded,
      value: state.voice,
      hint: 'Unavailable',
      items: [for (final voice in state.voices) (voice, voice, true)],
      onChanged: enabled ? controller.setVoice : null,
    );
    final speed = _Selector<double>(
      label: 'Speed',
      icon: Icons.speed_rounded,
      value: state.speed,
      hint: 'Unavailable',
      items: [
        for (final speed in state.speeds)
          (speed, speed == 1.0 ? '1.0x (Normal)' : '${speed}x', true),
      ],
      onChanged: enabled ? controller.setSpeed : null,
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 420
          ? Column(
              children: [
                language,
                const SizedBox(height: 8),
                voice,
                const SizedBox(height: 8),
                speed,
              ],
            )
          : Row(
              children: [
                Expanded(child: language),
                const SizedBox(width: 10),
                Expanded(child: voice),
                const SizedBox(width: 10),
                Expanded(child: speed),
              ],
            ),
    );
  }
}

class _Selector<T> extends StatelessWidget {
  const _Selector({
    required this.label,
    required this.icon,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final T? value;
  final String hint;

  /// (value, label, enabled)
  final List<(T, String, bool)> items;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: _text(
          12,
          height: 16 / 12,
          weight: FontWeight.w500,
          color: _body,
        ),
      ),
      const SizedBox(height: 4),
      Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _outline),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: _muted),
            const SizedBox(width: 6),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  value: items.any((item) => item.$1 == value) ? value : null,
                  isExpanded: true,
                  hint: Text(
                    hint,
                    style: _text(12, height: 16 / 12, color: _muted),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: _body,
                  ),
                  style: _text(12, height: 16 / 12, color: _ink),
                  items: [
                    for (final (itemValue, itemLabel, enabled) in items)
                      DropdownMenuItem<T>(
                        value: itemValue,
                        enabled: enabled,
                        child: Text(
                          itemLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: enabled
                              ? null
                              : _text(12, height: 16 / 12, color: _muted),
                        ),
                      ),
                  ],
                  onChanged: onChanged == null
                      ? null
                      : (next) {
                          if (next != null) onChanged!(next);
                        },
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _TtsStatusLine extends StatelessWidget {
  const _TtsStatusLine({required this.state});

  final TtsState state;

  @override
  Widget build(BuildContext context) {
    final (message, color) = switch (state) {
      TtsState(lastError: final error?) => (error, _red),
      TtsState(unavailableReason: final reason?) => (reason, _amberText),
      TtsState(phase: TtsPhase.requesting, simulated: true) => (
        'Demo Mode — preparing simulated speech. The robot is not speaking.',
        _amberText,
      ),
      TtsState(phase: TtsPhase.speaking, simulated: true) => (
        'Demo Mode — simulating speech. The robot is not speaking.',
        _amberText,
      ),
      TtsState(phase: TtsPhase.requesting) => ('Sending to robot…', _blue),
      TtsState(phase: TtsPhase.speaking) => ('G1 is speaking…', _purple),
      TtsState(phase: TtsPhase.stopping) => ('Stopping speech…', _amberText),
      TtsState(lastResult: final result?) => (result, _green),
      TtsState(simulated: true) => (
        'Demo Mode — the robot will not speak.',
        _amberText,
      ),
      _ => (state.validationError ?? 'Ready', _muted),
    };
    return Text(
      message,
      key: const Key('tts-status'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _text(12, height: 16 / 12, weight: FontWeight.w500, color: color),
    );
  }
}

class _SavedPhrases extends ConsumerWidget {
  const _SavedPhrases({
    required this.phrases,
    required this.enabled,
    required this.onSelect,
  });

  final List<SavedPhrase> phrases;
  final bool enabled;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Saved Phrases',
        style: _text(12, height: 16 / 12, weight: FontWeight.w600),
      ),
      const SizedBox(height: 6),
      SizedBox(
        height: 34,
        child: ListView(
          key: const Key('tts-phrases'),
          scrollDirection: Axis.horizontal,
          children: [
            for (final phrase in phrases) ...[
              _PhraseChip(
                phrase: phrase,
                enabled: enabled,
                onSelect: () => onSelect(phrase.text),
              ),
              const SizedBox(width: 6),
            ],
            IconButton.filledTonal(
              key: const Key('tts-add-phrase'),
              tooltip: 'Add phrase',
              visualDensity: VisualDensity.compact,
              onPressed: () => _editPhrase(context, ref, null),
              icon: const Icon(Icons.add_rounded, size: 18),
            ),
          ],
        ),
      ),
    ],
  );
}

class _PhraseChip extends ConsumerWidget {
  const _PhraseChip({
    required this.phrase,
    required this.enabled,
    required this.onSelect,
  });

  final SavedPhrase phrase;
  final bool enabled;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Material(
    color: const Color(0xFFF2F3FA),
    borderRadius: BorderRadius.circular(999),
    child: InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: enabled ? onSelect : null,
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                phrase.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _text(12, height: 16 / 12, color: _body),
              ),
            ),
            PopupMenuButton<String>(
              key: Key('phrase-menu-${phrase.id}'),
              tooltip: 'Phrase options',
              padding: EdgeInsets.zero,
              iconSize: 16,
              icon: const Icon(Icons.more_vert_rounded, color: _muted),
              onSelected: (action) {
                if (action == 'edit') {
                  _editPhrase(context, ref, phrase);
                } else {
                  ref.read(savedPhrasesProvider.notifier).remove(phrase.id);
                  _notify(context).info(
                    'Phrase deleted',
                    description: phrase.text,
                    key: 'saved-phrase',
                  );
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _editPhrase(
  BuildContext context,
  WidgetRef ref,
  SavedPhrase? phrase,
) async {
  final controller = TextEditingController(text: phrase?.text ?? '');
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(phrase == null ? 'Add phrase' : 'Edit phrase'),
      content: TextField(
        key: const Key('phrase-editor'),
        controller: controller,
        autofocus: true,
        maxLines: 3,
        minLines: 1,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (result == null || !context.mounted) return;
  final phrases = ref.read(savedPhrasesProvider.notifier);
  final error = phrase == null
      ? phrases.add(result)
      : phrases.edit(phrase.id, result);
  if (!context.mounted) return;
  if (error != null) {
    _notify(
      context,
    ).warning('Phrase not saved', description: error, key: 'saved-phrase');
  } else {
    _notify(context).success(
      phrase == null ? 'Phrase added' : 'Phrase updated',
      key: 'saved-phrase',
    );
  }
}
