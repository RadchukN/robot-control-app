import 'package:robot_control_app/features/voice_studio/domain/voice_models.dart';

/// Bounded, ordered transcript that tolerates duplicate and late events.
///
/// Each utterance is identified by [TranscriptEntry.id]; [TranscriptEntry.sequence]
/// increases with every partial update. Stale or repeated updates are ignored
/// and a final utterance is never downgraded back to partial.
class TranscriptBuffer {
  TranscriptBuffer({this.maxEntries = 200});

  final int maxEntries;
  final List<TranscriptEntry> _entries = [];

  List<TranscriptEntry> get entries => List.unmodifiable(_entries);

  /// Returns true when the transcript changed.
  bool apply(TranscriptEntry update) {
    if (update.text.trim().isEmpty && !update.isFinal) return false;
    final index = _entries.indexWhere((entry) => entry.id == update.id);
    if (index >= 0) {
      final current = _entries[index];
      if (update.sequence <= current.sequence) return false;
      if (current.isFinal && !update.isFinal) return false;
      _entries[index] = TranscriptEntry(
        id: current.id,
        role: current.role,
        text: update.text,
        isFinal: update.isFinal,
        // Keep the utterance's original position in the conversation.
        timestamp: current.timestamp,
        sequence: update.sequence,
        simulated: current.simulated || update.simulated,
      );
      return true;
    }
    var insertAt = _entries.length;
    while (insertAt > 0 &&
        _entries[insertAt - 1].timestamp.isAfter(update.timestamp)) {
      insertAt--;
    }
    _entries.insert(insertAt, update);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    return true;
  }

  void clear() => _entries.clear();

  static String format(Iterable<TranscriptEntry> entries) => entries
      .map(
        (entry) =>
            '[${clockTime(entry.timestamp)}] '
            '${entry.role == TranscriptRole.user ? 'You' : 'G1'}'
            '${entry.simulated ? ' (simulated)' : ''}'
            '${entry.isFinal ? '' : ' (partial)'}: ${entry.text}',
      )
      .join('\n');
}

String clockTime(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}:'
    '${time.second.toString().padLeft(2, '0')}';
