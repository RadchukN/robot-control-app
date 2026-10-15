part of 'voice_studio_screen.dart';

// Mirrors the Motion page palette so both pages read as one product.
const _backgroundTop = Color(0xFFFBFCFF);
const _backgroundBottom = Color(0xFFEFF2FF);
const _surface = Color(0xF2FFFFFF);
const _ink = Color(0xFF171A35);
const _body = Color(0xFF404867);
const _muted = Color(0xFF75809F);
const _outline = Color(0x80D7DCEF);
const _purple = Color(0xFF6F2CF4);
const _purpleSoft = Color(0xFFF0EBFF);
const _blue = Color(0xFF2F5BEA);
const _blueSoft = Color(0xFFEAF0FF);
const _green = Color(0xFF0BA968);
const _red = Color(0xFFE5364F);
const _redSoft = Color(0xFFFFECEF);
const _amber = Color(0xFFF5A400);
const _amberSoft = Color(0xFFFFF4D6);
const _amberText = Color(0xFF9A6A00);
const _grey = Color(0xFF8A93AD);

TextStyle _text(
  double size, {
  required double height,
  Color color = _ink,
  FontWeight weight = FontWeight.w400,
  FontStyle? style,
}) => TextStyle(
  fontSize: size,
  height: height,
  fontWeight: weight,
  color: color,
  fontStyle: style,
);

/// Distinct status tones used for every connection and device indicator.
enum _Tone {
  connected('Connected', _green),
  disconnected('Disconnected', _red),
  connecting('Connecting', _blue),
  unknown('Unknown', _grey),
  unavailable('Unavailable', _amber),
  demo('Demo', _purple);

  const _Tone(this.label, this.color);

  final String label;
  final Color color;
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.fill = true, this.minHeight = 0});

  static const padding = EdgeInsets.all(16);

  final Widget child;

  /// When true the card fills its parent and scrolls rather than overflow
  /// if the parent is shorter than [minHeight].
  final bool fill;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _outline),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x122E2767),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: fill
          ? LayoutBuilder(
              builder: (context, constraints) {
                final inner = constraints.maxHeight - padding.vertical;
                if (inner >= minHeight) {
                  return Padding(padding: padding, child: child);
                }
                return SingleChildScrollView(
                  padding: padding,
                  child: SizedBox(height: minHeight, child: child),
                );
              },
            )
          : Padding(padding: padding, child: child),
    );
    return decorated;
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing = const [],
    this.large = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> trailing;
  final bool large;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: large ? 26 : 22, color: _purple),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _text(
                large ? 20 : 16,
                height: large ? 26 / 20 : 22 / 16,
                weight: FontWeight.w700,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _text(12, height: 16 / 12, color: _muted),
              ),
          ],
        ),
      ),
      ...trailing,
    ],
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.height = 48,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2D6BFF), Color(0xFF5B3BF0)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x332D6BFF),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: _ButtonLabel(label: label, icon: icon, color: Colors.white),
          ),
        ),
      ),
    ),
  );
}

class _SoftButton extends StatelessWidget {
  const _SoftButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color = _purple,
    this.background = _purpleSoft,
    this.height = 44,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color color;
  final Color background;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _ButtonLabel(label: label, icon: icon, color: color),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final text = Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _text(
          13,
          height: 17 / 13,
          weight: FontWeight.w600,
          color: color,
        ),
      );
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
          ],
          // Shrink-wrap inside unbounded rows, ellipsize when constrained.
          if (constraints.hasBoundedWidth) Flexible(child: text) else text,
        ],
      );
    },
  );
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.label,
    required this.color,
    required this.background,
    this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _text(
              11,
              height: 14 / 11,
              weight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DemoBadge extends StatelessWidget {
  const _DemoBadge();

  @override
  Widget build(BuildContext context) => _Pill(
    key: const Key('voice-demo-badge'),
    label: 'Demo Mode',
    icon: Icons.science_outlined,
    color: _amberText,
    background: _amberSoft,
  );
}

class _ToneDot extends StatelessWidget {
  const _ToneDot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

AppNotificationService _notify(BuildContext context) => context.notifications;
