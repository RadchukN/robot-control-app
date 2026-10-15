import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/core/theme/app_spacing.dart';
import 'package:robot_control_app/features/ai_workspace/application/ai_workspace_state.dart';

class AiWorkspaceScreen extends ConsumerWidget {
  const AiWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AiWorkspaceView(state: ref.watch(aiWorkspaceStateProvider));
}

class AiWorkspaceView extends StatelessWidget {
  const AiWorkspaceView({
    required this.state,
    this.onSend,
    this.onConfirm,
    this.onCancel,
    super.key,
  });

  final AiWorkspaceState state;
  final ValueChanged<String>? onSend;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 600;
    final showInspector = screenWidth >= 1200;
    final outerGutter = compact ? 16.0 : (showInspector ? 0.0 : 24.0);

    return Container(
      key: const Key('ai-workspace-screen'),
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF7FAFF), Color(0xFFECF1FF), Color(0xFFFEFEFF)],
          stops: [0, .54, 1],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: outerGutter),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF7FAFF), Color(0xFFF5EDFF)],
            ),
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: 'Inter'),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 12 : 20,
                compact ? 12 : 20,
                compact ? 12 : 20,
                compact ? 12 : (showInspector ? 12 : 20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WorkspaceHeader(compact: compact),
                  const SizedBox(height: 14),
                  _ContextBar(state: state, compact: compact),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _MainWorkspace(
                      state: state,
                      compact: compact,
                      showInspector: showInspector,
                      onConfirm: onConfirm,
                      onCancel: onCancel,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Composer(compact: compact, onSend: onSend),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: compact ? 47 : 53,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Workspace',
                maxLines: 1,
                style: TextStyle(
                  color: compact
                      ? const Color(0xFF333B57)
                      : const Color(0xFF252A42),
                  fontSize: compact ? 20 : 24,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                compact
                    ? 'Operational copilot'
                    : 'Ask, understand, preview and safely execute',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF68708A),
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const _StatusPill(
          label: 'Context live',
          foreground: Color(0xFF1FAD6E),
          background: Color(0xE6E0FFF0),
        ),
      ],
    ),
  );
}

class _ContextBar extends StatelessWidget {
  const _ContextBar({required this.state, required this.compact});

  final AiWorkspaceState state;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 56),
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: const Color(0xA3FFFFFF),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xE6FFFFFF)),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: Row(
        children: [
          _StatusPill(
            label: state.robotStatus,
            foreground: const Color(0xFF1FAD6E),
            background: const Color(0xE6E0FFF0),
          ),
          if (!compact) ...[
            const SizedBox(width: 10),
            _StatusPill(
              label: state.mission,
              foreground: const Color(0xFF267AFA),
              background: const Color(0xE6E5F2FF),
            ),
            const SizedBox(width: 10),
            _StatusPill(
              label: state.motionStatus,
              foreground: const Color(0xFF8526ED),
              background: const Color(0xE6F2EBFF),
            ),
          ],
        ],
      ),
    ),
  );
}

class _MainWorkspace extends StatelessWidget {
  const _MainWorkspace({
    required this.state,
    required this.compact,
    required this.showInspector,
    required this.onConfirm,
    required this.onCancel,
  });

  final AiWorkspaceState state;
  final bool compact;
  final bool showInspector;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final conversation = _Conversation(
      state: state,
      compact: compact,
      expanded: showInspector,
      onConfirm: onConfirm,
      onCancel: onCancel,
    );
    if (!showInspector) {
      return conversation;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: conversation),
        const SizedBox(width: AppSpacing.md),
        _ContextInspector(entries: state.contextEntries),
      ],
    );
  }
}

class _Conversation extends StatelessWidget {
  const _Conversation({
    required this.state,
    required this.compact,
    required this.expanded,
    required this.onConfirm,
    required this.onCancel,
  });

  final AiWorkspaceState state;
  final bool compact;
  final bool expanded;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final welcomeWidth = math.min(
        compact ? 302.0 : 450.0,
        constraints.maxWidth,
      );
      final responseWidth = math.min(
        compact ? 310.0 : (expanded ? 812.0 : 488.0),
        constraints.maxWidth,
      );
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: welcomeWidth,
              child: _WelcomeCard(state: state, compact: compact),
            ),
            const SizedBox(height: 14),
            if (!compact) ...[
              SizedBox(
                width: responseWidth,
                child: _AssessmentCard(state: state),
              ),
              const SizedBox(height: 14),
            ],
            SizedBox(
              width: responseWidth,
              child: _CommandPreviewCard(
                state: state,
                compact: compact,
                onConfirm: onConfirm,
                onCancel: onCancel,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.state, required this.compact});

  final AiWorkspaceState state;
  final bool compact;

  @override
  Widget build(BuildContext context) => _GlassCard(
    padding: EdgeInsets.all(compact ? 16 : 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AiOrb(size: compact ? 48 : 60),
        SizedBox(width: compact ? AppSpacing.sm : AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                compact ? state.compactWelcomeTitle : state.welcomeTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF333B57),
                  fontSize: compact ? 17 : 18,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: compact ? 2 : AppSpacing.xxs),
              Text(
                compact ? state.compactWelcomeBody : state.welcomeBody,
                style: TextStyle(
                  color: const Color(0xFF68708A),
                  fontSize: compact ? 12 : 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({required this.state});

  final AiWorkspaceState state;

  @override
  Widget build(BuildContext context) => _GlassCard(
    constraints: const BoxConstraints(minHeight: 142),
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ResponseHeader(title: state.assessmentTitle),
        const SizedBox(height: AppSpacing.sm),
        Text(
          state.assessmentBody,
          style: const TextStyle(
            color: Color(0xFF3F4661),
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ],
    ),
  );
}

class _CommandPreviewCard extends StatelessWidget {
  const _CommandPreviewCard({
    required this.state,
    required this.compact,
    required this.onConfirm,
    required this.onCancel,
  });

  final AiWorkspaceState state;
  final bool compact;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => _GlassCard(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ResponseHeader(
          title: state.proposalTitle,
          allowFigmaOverflow: compact,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          state.proposalBody,
          style: const TextStyle(
            color: Color(0xFF3F4661),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const _CommandParameters(),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 10,
          runSpacing: AppSpacing.xs,
          children: [
            _GradientButton(label: 'Confirm & execute', onPressed: onConfirm),
            _OutlineButton(label: 'Cancel', onPressed: onCancel),
          ],
        ),
      ],
    ),
  );
}

class _ResponseHeader extends StatelessWidget {
  const _ResponseHeader({required this.title, this.allowFigmaOverflow = false});

  final String title;
  final bool allowFigmaOverflow;

  Widget _buildRow() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _AiOrb(size: 36),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF333B57),
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Text(
              'Based on current robot and mission context',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF68708A),
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (!allowFigmaOverflow) {
      return _buildRow();
    }
    return SizedBox(
      height: 40,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: SizedBox(width: 276, height: 40, child: _buildRow()),
      ),
    );
  }
}

class _CommandParameters extends StatelessWidget {
  const _CommandParameters();

  Widget _buildRow() => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _StatusPill(
        label: '2.0 m',
        foreground: Color(0xFF8526ED),
        background: Color(0xE6F2EBFF),
      ),
      SizedBox(width: AppSpacing.xs),
      _StatusPill(
        label: '0.42 m/s',
        foreground: Color(0xFF267AFA),
        background: Color(0xE6E5F2FF),
      ),
      SizedBox(width: AppSpacing.xs),
      _StatusPill(
        label: 'Obstacle stop · On',
        foreground: Color(0xFF1FAD6E),
        background: Color(0xE6E0FFF0),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 35,
    child: LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: _buildRow(),
        );
      },
    ),
  );
}

class _ContextInspector extends StatelessWidget {
  const _ContextInspector({required this.entries});

  final List<AiContextEntry> entries;

  @override
  Widget build(BuildContext context) => Container(
    width: 308,
    height: 540,
    clipBehavior: Clip.antiAlias,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xCCFFFFFF),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFAFFFFFF)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A292E6B),
          blurRadius: 14,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Context inspector',
            style: TextStyle(
              color: Color(0xFF333B57),
              fontSize: 18,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          const _InspectorSection(
            height: 122,
            title: 'Why this answer',
            titleColor: Color(0xFF8526ED),
            child: Text(
              'Robot telemetry, mission state and safety constraints were checked before producing this response.',
              style: TextStyle(
                color: Color(0xFF68708A),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _LiveContext(entries: entries),
          const SizedBox(height: 10),
          const _StatusPill(
            label: 'Sources · 5 live signals',
            foreground: Color(0xFF267AFA),
            background: Color(0xE6E5F2FF),
            fontSize: 13,
          ),
        ],
      ),
    ),
  );
}

class _InspectorSection extends StatelessWidget {
  const _InspectorSection({
    required this.height,
    required this.title,
    required this.child,
    this.titleColor = const Color(0xFF333B57),
  });

  final double height;
  final String title;
  final Color titleColor;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    height: height,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0x9EFFFFFF),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xA6D1D6EB)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1233296B),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontSize: 13,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _LiveContext extends StatelessWidget {
  const _LiveContext({required this.entries});

  final List<AiContextEntry> entries;

  @override
  Widget build(BuildContext context) => _InspectorSection(
    height: 290,
    title: 'Live context',
    child: Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final entry in entries)
            SizedBox(
              height: 36,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.label,
                      style: const TextStyle(
                        color: Color(0xFF68708A),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      entry.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: Color(0xFF3F4661),
                        fontSize: 12,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _Composer extends StatefulWidget {
  const _Composer({required this.compact, required this.onSend});

  final bool compact;
  final ValueChanged<String>? onSend;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) {
      widget.onSend?.call(value);
      _controller.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    height: widget.compact ? 64 : 72,
    padding: widget.compact
        ? const EdgeInsets.fromLTRB(14, 14, 14, 7)
        : const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xE0FFFFFF),
      borderRadius: BorderRadius.circular(widget.compact ? 22 : 26),
      border: Border.all(color: Colors.white),
      boxShadow: const [
        BoxShadow(
          color: Color(0x21713894),
          blurRadius: 15,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _controller,
                onSubmitted: (_) => _submit(),
                maxLines: 1,
                cursorColor: const Color(0xFF267AFA),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFF3F4661),
                  fontSize: 18,
                  height: 1.3,
                ),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  fillColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  hintText: 'Ask Gustav or describe an action…',
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF68708A),
                    fontSize: 18,
                    height: 1.3,
                  ),
                ),
              ),
              if (!widget.compact)
                const Text(
                  'AI can explain, propose and execute only after confirmation',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF68708A),
                    fontSize: 10,
                    height: 1.45,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _GradientButton(label: 'Send', onPressed: _submit),
      ],
    ),
  );
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    required this.padding,
    this.constraints,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) => Container(
    constraints: constraints,
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0xB8FFFFFF),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xE6FFFFFF)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A403399),
          blurRadius: 14,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: child,
  );
}

class _AiOrb extends StatelessWidget {
  const _AiOrb({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [Color(0xFF7B2CFF), Color(0xFF287CFA), Color(0xFF22C8EE)],
      ),
      border: Border.all(color: Colors.white, width: 1.5),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.foreground,
    required this.background,
    this.fontSize = 12,
  });

  final String label;
  final Color foreground;
  final Color background;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      maxLines: 1,
      style: TextStyle(
        color: foreground,
        fontSize: fontSize,
        height: 1.45,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => _ActionSurface(
    label: label,
    foreground: Colors.white,
    onPressed: onPressed,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF8526ED), Color(0xFF267AFA), Color(0xFF2EC7F2)],
        stops: [0, .55, 1],
      ),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xE6DBDEF0)),
    ),
  );
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => _ActionSurface(
    label: label,
    foreground: const Color(0xFF8526ED),
    onPressed: onPressed,
    decoration: BoxDecoration(
      color: const Color(0xE0FFFFFF),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xE6DBDEF0)),
    ),
  );
}

class _ActionSurface extends StatelessWidget {
  const _ActionSurface({
    required this.label,
    required this.foreground,
    required this.decoration,
    required this.onPressed,
  });

  final String label;
  final Color foreground;
  final BoxDecoration decoration;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: label,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          height: 43,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: decoration,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
