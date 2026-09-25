import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AiInteractionState {
  welcome,
  processing,
  informational,
  commandProposal,
  confirmation,
  executing,
  success,
  failed,
  warning,
  criticalSafety,
  offline,
  noRobot,
  clarification,
}

@immutable
class AiContextEntry {
  const AiContextEntry(this.label, this.value);

  final String label;
  final String value;
}

@immutable
class AiWorkspaceState {
  const AiWorkspaceState({
    required this.interactionState,
    required this.robotStatus,
    required this.mission,
    required this.motionStatus,
    required this.welcomeTitle,
    required this.welcomeBody,
    required this.compactWelcomeTitle,
    required this.compactWelcomeBody,
    required this.assessmentTitle,
    required this.assessmentBody,
    required this.proposalTitle,
    required this.proposalBody,
    required this.contextEntries,
  });

  final AiInteractionState interactionState;
  final String robotStatus;
  final String mission;
  final String motionStatus;
  final String welcomeTitle;
  final String welcomeBody;
  final String compactWelcomeTitle;
  final String compactWelcomeBody;
  final String assessmentTitle;
  final String assessmentBody;
  final String proposalTitle;
  final String proposalBody;
  final List<AiContextEntry> contextEntries;

  static const commandProposal = AiWorkspaceState(
    interactionState: AiInteractionState.commandProposal,
    robotStatus: 'Gustav · Ready',
    mission: 'Mission: Warehouse inspection',
    motionStatus: 'Motion enabled',
    welcomeTitle: 'Good afternoon. Gustav is ready.',
    welcomeBody:
        'Ask about status, mission context, or propose a robot action.',
    compactWelcomeTitle: 'How can I help?',
    compactWelcomeBody: 'I can explain robot state or prepare a safe action.',
    assessmentTitle: 'Operational assessment',
    assessmentBody:
        'Gustav is ready. Battery and connectivity are nominal. The current mission can continue without operator intervention.',
    proposalTitle: 'Proposed robot action',
    proposalBody:
        'Move Gustav forward 2.0 m at 0.42 m/s. Clearance is verified and obstacle stop remains enabled.',
    contextEntries: [
      AiContextEntry('Robot', 'Gustav · Ready'),
      AiContextEntry('Mission', 'Warehouse inspection'),
      AiContextEntry('Battery', '78% · 2 h 06 m'),
      AiContextEntry('Network', '24 ms · Stable'),
      AiContextEntry('Safety', 'Nominal'),
    ],
  );
}

final aiWorkspaceStateProvider = Provider<AiWorkspaceState>(
  (ref) => AiWorkspaceState.commandProposal,
  name: 'AiWorkspaceStateProvider',
);
