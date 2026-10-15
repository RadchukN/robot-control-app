part of 'voice_studio_screen.dart';

class _TranscriptPanel extends ConsumerStatefulWidget {
  const _TranscriptPanel();

  @override
  ConsumerState<_TranscriptPanel> createState() => _TranscriptPanelState();
}

class _TranscriptPanelState extends ConsumerState<_TranscriptPanel> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(realtimeVoiceProvider.select((state) => state.transcript), (
      previous,
      next,
    ) {
      if (next.isNotEmpty) _scrollToEnd();
    });
    final state = ref.watch(realtimeVoiceProvider);
    final controller = ref.read(realtimeVoiceProvider.notifier);
    final entries = state.transcript;
    return _Card(
      minHeight: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            icon: Icons.forum_outlined,
            title: 'Conversation Transcript',
            subtitle: state.simulated
                ? 'Simulated conversation · not stored'
                : 'Live transcript · not stored',
            trailing: [
              IconButton(
                key: const Key('transcript-copy'),
                tooltip: 'Copy transcript',
                visualDensity: VisualDensity.compact,
                onPressed: entries.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(text: state.transcriptText),
                        );
                        if (context.mounted) {
                          _notify(context).success(
                            'Transcript copied',
                            description: 'Copied to the clipboard.',
                          );
                        }
                      },
                icon: const Icon(Icons.copy_rounded, size: 18, color: _body),
              ),
              const SizedBox(width: 4),
              _SoftButton(
                key: const Key('transcript-clear'),
                label: 'Clear',
                icon: Icons.delete_outline_rounded,
                color: _body,
                background: const Color(0xFFF2F4FA),
                height: 34,
                onTap: entries.isEmpty ? null : controller.clearTranscript,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet. Start an AI conversation.',
                      textAlign: TextAlign.center,
                      style: _text(12, height: 16 / 12, color: _muted),
                    ),
                  )
                : Scrollbar(
                    controller: _scroll,
                    child: ListView.separated(
                      key: const Key('transcript-list'),
                      controller: _scroll,
                      padding: const EdgeInsets.only(right: 10),
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _TranscriptMessage(entry: entries[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TranscriptMessage extends StatelessWidget {
  const _TranscriptMessage({required this.entry});

  final TranscriptEntry entry;

  @override
  Widget build(BuildContext context) {
    final user = entry.role == TranscriptRole.user;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: user ? const Color(0xFF8FB2FF) : _ink,
          child: Icon(
            user ? Icons.person_rounded : Icons.smart_toy_outlined,
            size: 17,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: BoxDecoration(
              color: user ? _blueSoft : const Color(0xFFF4F5FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      user ? 'You' : 'G1',
                      style: _text(
                        12,
                        height: 16 / 12,
                        weight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      clockTime(entry.timestamp),
                      style: _text(11, height: 14 / 11, color: _muted),
                    ),
                    if (entry.simulated)
                      Text(
                        'simulated',
                        style: _text(10, height: 13 / 10, color: _amberText),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  entry.isFinal ? entry.text : '${entry.text}…',
                  style: _text(
                    13,
                    height: 18 / 13,
                    color: entry.isFinal ? _ink : _muted,
                    style: entry.isFinal ? null : FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
