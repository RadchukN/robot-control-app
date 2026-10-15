import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:robot_control_app/core/routing/app_routes.dart';
import 'package:robot_control_app/core/theme/app_colors.dart';
import 'package:robot_control_app/models/dashboard_data.dart';
import 'package:robot_control_app/shared/notifications/app_notification_service.dart';

void _showDashboardMessage(BuildContext context, String message) =>
    context.notifications.info(message);

class DashboardView extends StatelessWidget {
  const DashboardView({required this.data, required this.onRefresh, super.key});

  final DashboardData data;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final layout = switch (constraints.maxWidth) {
        < 600 => _DashboardLayout.compact,
        < 1100 => _DashboardLayout.medium,
        _ => _DashboardLayout.expanded,
      };
      final horizontalPadding = switch (layout) {
        _DashboardLayout.compact => constraints.maxWidth >= 390 ? 32.0 : 16.0,
        _DashboardLayout.medium => 44.0,
        _DashboardLayout.expanded => 28.0,
      };
      final topPadding = switch (layout) {
        _DashboardLayout.compact => 16.0,
        _DashboardLayout.medium => 20.0,
        _DashboardLayout.expanded => 24.0,
      };
      final gap = layout == _DashboardLayout.expanded ? 14.0 : 16.0;

      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          key: const Key('dashboard-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            topPadding,
            horizontalPadding,
            layout == _DashboardLayout.expanded ? 2 : 16,
          ),
          children: [
            _DashboardHeader(data: data, layout: layout),
            SizedBox(height: gap),
            _RobotOverview(data: data, layout: layout),
            SizedBox(height: gap),
            _PrimaryMetrics(data: data, layout: layout),
            SizedBox(height: gap),
            _OperationalGrid(layout: layout),
            SizedBox(height: gap),
            _RecentActivity(layout: layout),
          ],
        ),
      );
    },
  );
}

enum _DashboardLayout { compact, medium, expanded }

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.data, required this.layout});

  final DashboardData data;
  final _DashboardLayout layout;

  @override
  Widget build(BuildContext context) {
    final title = _DashboardTitle(updatedAt: data.updatedAt);
    return switch (layout) {
      _DashboardLayout.compact => SizedBox(
        height: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 56, child: title),
            const SizedBox(height: 16),
            const Expanded(child: _HeaderReadyState()),
          ],
        ),
      ),
      _DashboardLayout.medium => SizedBox(
        height: 100,
        child: Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            const SizedBox(width: 107, height: 100, child: _HeaderReadyState()),
          ],
        ),
      ),
      _DashboardLayout.expanded => SizedBox(height: 64, child: title),
    };
  }
}

class _DashboardTitle extends StatelessWidget {
  const _DashboardTitle({required this.updatedAt});

  final DateTime updatedAt;

  @override
  Widget build(BuildContext context) {
    final seconds = DateTime.now().difference(updatedAt).inSeconds;
    final freshness = seconds < 2 ? 'just now' : '$seconds seconds ago';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dashboard',
          style: TextStyle(
            color: Color(0xFF1B1B1F),
            fontSize: 28,
            height: 36 / 28,
          ),
        ),
        Text(
          'Live · Updated $freshness',
          style: const TextStyle(
            color: Color(0xFF49454F),
            fontSize: 12,
            height: 16 / 12,
          ),
        ),
      ],
    );
  }
}

class _HeaderReadyState extends StatelessWidget {
  const _HeaderReadyState();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xD9DDF8E8),
      border: Border.all(color: const Color(0x382DB46E)),
      borderRadius: BorderRadius.circular(13),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A24A05F),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: const Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: Color(0xFF1AAF68)),
          SizedBox(width: 8),
          Text(
            'Telemetry',
            style: TextStyle(
              color: Color(0xFF167A46),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

class _RobotOverview extends StatelessWidget {
  const _RobotOverview({required this.data, required this.layout});

  final DashboardData data;
  final _DashboardLayout layout;

  @override
  Widget build(BuildContext context) {
    final connected = data.telemetryConnected;
    final batterySoc = data.telemetry?.batterySoc;
    final batteryValue = batterySoc == null ? '--' : '$batterySoc%';
    final telemetry = data.telemetry;
    final signalPercent = telemetry?.networkSignalPercent;
    final signalLabel = switch (telemetry?.networkType) {
      'ethernet' => 'Ethernet',
      'wifi' => signalPercent == null ? 'Wi-Fi' : 'Wi-Fi $signalPercent%',
      _ => '--',
    };
    const nominal = false;
    final height = switch (layout) {
      _DashboardLayout.compact => 292.0,
      _DashboardLayout.medium => 180.0,
      _DashboardLayout.expanded => 136.0,
    };

    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(-.9, .9),
          end: Alignment(1, -.8),
          colors: [
            Color(0xFF330994),
            Color(0xFF851AF2),
            Color(0xFF1F57FF),
            Color(0xFF05ABE0),
          ],
          stops: [.05, .42, .75, 1],
        ),
        border: Border.all(color: const Color(0x61FFFFFF)),
        borderRadius: BorderRadius.circular(
          layout == _DashboardLayout.compact ? 12 : 24,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x38711FB8),
            blurRadius: 38,
            spreadRadius: -6,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            left: 260,
            right: -100,
            top: -120,
            height: 260,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0x55FF38E8), Color(0x001F57FF)],
                ),
              ),
            ),
          ),
          if (layout == _DashboardLayout.expanded)
            _ExpandedOverviewContent(
              connected: connected,
              nominal: nominal,
              batteryValue: batteryValue,
              signalLabel: signalLabel,
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Robot overview',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 24 / 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: layout == _DashboardLayout.compact
                        ? _CompactOverviewBody(
                            connected: connected,
                            nominal: nominal,
                            batteryValue: batteryValue,
                            signalLabel: signalLabel,
                          )
                        : _MediumOverviewBody(
                            connected: connected,
                            nominal: nominal,
                            batteryValue: batteryValue,
                            signalLabel: signalLabel,
                          ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ExpandedOverviewContent extends StatelessWidget {
  const _ExpandedOverviewContent({
    required this.connected,
    required this.nominal,
    required this.batteryValue,
    required this.signalLabel,
  });

  final bool connected;
  final bool nominal;
  final String batteryValue;
  final String signalLabel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      children: [
        const Positioned(
          left: 20,
          top: 16,
          child: Text(
            'Robot overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 24 / 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Positioned(left: 20, top: 54, child: _RobotIdentity()),
        const Positioned(
          left: 200,
          top: 11,
          width: 200,
          height: 112,
          child: Center(
            child: SizedBox.square(dimension: 112, child: _RobotCore()),
          ),
        ),
        Positioned(
          left: 400,
          right: 20,
          top: 44,
          height: 48,
          child: Row(
            children: [
              Expanded(
                flex: 136,
                child: _StatusChip(
                  icon: Icons.check_circle_outline,
                  label: connected ? 'Connected' : 'Offline',
                  positive: connected,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 162,
                child: _StatusChip(
                  icon: Icons.shield_outlined,
                  label: 'Safety unavailable',
                  positive: null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 122,
                child: _StatusChip(
                  icon: Icons.work,
                  label: 'Battery',
                  value: batteryValue,
                  positive: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 117,
                child: _StatusChip(
                  icon: Icons.signal_cellular_alt,
                  label: signalLabel,
                  positive: null,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(flex: 177, child: _EmergencyStop()),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CompactOverviewBody extends StatelessWidget {
  const _CompactOverviewBody({
    required this.connected,
    required this.nominal,
    required this.batteryValue,
    required this.signalLabel,
  });

  final bool connected;
  final bool nominal;
  final String batteryValue;
  final String signalLabel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 52, child: _RobotIdentity()),
      const SizedBox(height: 8),
      SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: _StatusChip(
                icon: Icons.check_circle_outline,
                label: connected ? 'Connected' : 'Offline',
                positive: connected,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatusChip(
                icon: Icons.shield_outlined,
                label: 'Safety unavailable',
                positive: null,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: _StatusChip(
                icon: Icons.work,
                label: 'Battery',
                value: batteryValue,
                positive: true,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _StatusChip(
                icon: Icons.signal_cellular_alt,
                label: signalLabel,
                positive: null,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      const Expanded(child: _EmergencyStop()),
    ],
  );
}

class _MediumOverviewBody extends StatelessWidget {
  const _MediumOverviewBody({
    required this.connected,
    required this.nominal,
    required this.batteryValue,
    required this.signalLabel,
  });

  final bool connected;
  final bool nominal;
  final String batteryValue;
  final String signalLabel;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 52,
        child: Row(
          children: [
            const Expanded(flex: 160, child: _RobotIdentity()),
            const SizedBox(width: 12),
            Expanded(
              flex: 136,
              child: _StatusChip(
                icon: Icons.check_circle_outline,
                label: connected ? 'Connected' : 'Offline',
                positive: connected,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 162,
              child: _StatusChip(
                icon: Icons.shield_outlined,
                label: 'Safety unavailable',
                positive: null,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: Row(
          children: [
            Expanded(
              flex: 122,
              child: _StatusChip(
                icon: Icons.work,
                label: 'Battery',
                value: batteryValue,
                positive: true,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              flex: 117,
              child: _StatusChip(
                icon: Icons.signal_cellular_alt,
                label: signalLabel,
                positive: null,
              ),
            ),
            SizedBox(width: 12),
            Expanded(flex: 177, child: _EmergencyStop()),
          ],
        ),
      ),
    ],
  );
}

class _RobotIdentity extends StatelessWidget {
  const _RobotIdentity();

  @override
  Widget build(BuildContext context) => const Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'G1 Gustav',
        maxLines: 1,
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          height: 28 / 20,
          fontWeight: FontWeight.w500,
        ),
      ),
      Text(
        'Unitree G1 · Telemetry',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Color(0xFFDCCEFF),
          fontSize: 12,
          height: 20 / 12,
        ),
      ),
    ],
  );
}

class _RobotCore extends StatelessWidget {
  const _RobotCore();

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Open robot overview',
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showDashboardMessage(context, 'G1 Gustav selected'),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Transform.translate(
                offset: const Offset(0, 9),
                child: Image.asset(
                  'assets/images/robot_core.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xA6A9C8FF), width: 2),
              ),
            ),
            const Icon(
              Icons.smart_toy_outlined,
              size: 30,
              color: Color(0xFF6330C7),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.positive,
    this.value,
  });

  final IconData icon;
  final String label;
  final bool? positive;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final foreground = positive == null
        ? const Color(0xFF49454F)
        : positive!
        ? const Color(0xFF146C2E)
        : AppColors.error;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => _showDashboardMessage(
          context,
          '$label${value == null ? '' : ' $value'}',
        ),
        child: Ink(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: positive == null
                ? const Color(0xFFE5E1E6)
                : positive!
                ? const Color(0xD9DDF8E8)
                : const Color(0xFFFFDAD6),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: positive == true
                  ? const Color(0x382DB46E)
                  : const Color(0x52BA1A1A),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A24A05F),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Dot(color: foreground),
              const SizedBox(width: 7),
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 6),
                Text(value!, style: TextStyle(color: foreground, fontSize: 11)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyStop extends StatelessWidget {
  const _EmergencyStop();

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _showDashboardMessage(
        context,
        'Emergency stop requires robot confirmation',
      ),
      child: Ink(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFFFDAD6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x78FFFFFF)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.stop_circle_outlined, size: 20, color: AppColors.error),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Emergency stop',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: const SizedBox(width: 8, height: 8),
  );
}

class _PrimaryMetrics extends StatelessWidget {
  const _PrimaryMetrics({required this.data, required this.layout});

  final DashboardData data;
  final _DashboardLayout layout;

  @override
  Widget build(BuildContext context) {
    final telemetry = data.telemetryConnected ? data.telemetry : null;
    String value(num? number, String unit) => number == null
        ? '--'
        : '${number is int ? number : number.toStringAsFixed(1)}$unit';
    List<double?> series(num? Function(DashboardTelemetry) read) =>
        data.telemetryConnected
        ? data.telemetryHistory
              .map((sample) {
                final number = read(sample);
                return number != null && number.isFinite
                    ? number.toDouble()
                    : null;
              })
              .toList(growable: false)
        : const [];
    final metrics = [
      _MetricData(
        'Battery',
        value(telemetry?.batterySoc, '%'),
        'SOH ${value(telemetry?.batterySoh, '%')}',
        Icons.battery_std_outlined,
        AppColors.success,
        series((sample) => sample.batterySoc),
        percentage: true,
      ),
      _MetricData(
        'BMS temperature',
        value(telemetry?.maxBmsTemperature, ' °C'),
        'Maximum BMS sensor',
        Icons.thermostat_outlined,
        AppColors.primary,
        series((sample) => sample.maxBmsTemperature),
      ),
      _MetricData(
        'IMU temperature',
        value(telemetry?.imuTemperature, ' °C'),
        'IMU sensor',
        Icons.thermostat_outlined,
        AppColors.info,
        series((sample) => sample.imuTemperature),
      ),
      _MetricData(
        'Motor temperature',
        value(telemetry?.maxMotorTemperature, ' °C'),
        'Maximum motor sensor',
        Icons.thermostat_outlined,
        AppColors.tertiary,
        series((sample) => sample.maxMotorTemperature),
      ),
      _MetricData(
        'Active motors',
        value(telemetry?.activeMotorCount, ''),
        'Distinct reported indices',
        Icons.settings_outlined,
        AppColors.secondary,
        null,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = switch (layout) {
          _DashboardLayout.compact => 1,
          _DashboardLayout.medium => 2,
          _DashboardLayout.expanded => 5,
        };
        final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
        final height = 140.0 + (textScale > 1 ? (textScale - 1) * 80 : 0);
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                height: height,
                child: _MetricCard(data: metric),
              ),
          ],
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData(
    this.label,
    this.value,
    this.detail,
    this.icon,
    this.color,
    this.points, {
    this.percentage = false,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
  final List<double?>? points;
  final bool percentage;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    final points = data.points;
    final available = data.value != '--';
    final hasHistory = points != null && points.whereType<double>().isNotEmpty;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showDashboardMessage(
          context,
          '${data.label}: ${data.value} — ${data.detail}',
        ),
        child: _GlassPanel(
          radius: 20,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(data.icon, size: 18, color: data.color),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      data.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                        height: 16 / 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                data.value,
                maxLines: 1,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 24,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto Mono',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                  height: 16 / 11,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 28,
                width: double.infinity,
                child: points == null
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: data.color.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            available ? 'Telemetry received' : 'Unavailable',
                            style: TextStyle(color: data.color, fontSize: 10),
                          ),
                        ),
                      )
                    : hasHistory
                    ? Tooltip(
                        message:
                            'Last 5 minutes, sampled every 5 seconds. '
                            '${data.percentage ? 'Scale: 0–100%.' : 'Local temperature scale.'} '
                            'Missing readings appear as gaps.',
                        child: Semantics(
                          label:
                              '${data.label} 5-minute trend from ${points.length} received samples',
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: _SparklinePainter(
                                points: points,
                                color: data.color,
                                percentage: data.percentage,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Waiting for telemetry',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.points,
    required this.color,
    required this.percentage,
  });

  final List<double?> points;
  final Color color;
  final bool percentage;

  @override
  void paint(Canvas canvas, Size size) {
    final values = points
        .whereType<double>()
        .where((value) => value.isFinite)
        .toList();
    if (values.isEmpty || size.isEmpty) return;
    var minimum = values.first;
    var maximum = values.first;
    for (final value in values) {
      if (value < minimum) minimum = value;
      if (value > maximum) maximum = value;
    }
    // Pad small changes so sensor noise isn't drawn as a full-height swing.
    final padding = (maximum - minimum) * .2 < 1
        ? 1.0
        : (maximum - minimum) * .2;
    final low = percentage ? 0.0 : minimum - padding;
    final high = percentage ? 100.0 : maximum + padding;
    final line = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    var connected = false;
    Offset? last;
    for (var index = 0; index < points.length; index++) {
      final value = points[index];
      if (value == null || !value.isFinite) {
        connected = false;
        last = null;
        continue;
      }
      // 61 samples span about 5 minutes; no invented leading data.
      final x = 2 + (size.width - 4) * (61 - points.length + index) / 60;
      final y =
          3 +
          (size.height - 6) * (1 - ((value - low) / (high - low)).clamp(0, 1));
      final point = Offset(x, y);
      if (connected) {
        path.lineTo(x, y);
      } else {
        path.moveTo(x, y);
        canvas.drawCircle(point, 1.3, Paint()..color = color);
      }
      connected = true;
      last = point;
    }
    canvas.drawPath(path, line);
    if (last != null) {
      canvas.drawCircle(
        last,
        3.5,
        Paint()..color = color.withValues(alpha: .15),
      );
      canvas.drawCircle(last, 2, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.color != color ||
      oldDelegate.percentage != percentage;
}

class _OperationalGrid extends StatelessWidget {
  const _OperationalGrid({required this.layout});

  final _DashboardLayout layout;

  @override
  Widget build(BuildContext context) => switch (layout) {
    _DashboardLayout.compact => const SizedBox(
      height: 768,
      child: Column(
        children: [
          SizedBox(
            height: 440,
            child: _PrimaryColumn(layout: _DashboardLayout.compact),
          ),
          SizedBox(height: 16),
          SizedBox(
            height: 312,
            child: _AttentionColumn(layout: _DashboardLayout.compact),
          ),
        ],
      ),
    ),
    _DashboardLayout.medium => const SizedBox(
      height: 440,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _PrimaryColumn(layout: _DashboardLayout.medium)),
          SizedBox(width: 12),
          Expanded(child: _AttentionColumn(layout: _DashboardLayout.medium)),
        ],
      ),
    ),
    _DashboardLayout.expanded => const SizedBox(
      height: 330,
      child: Row(
        children: [
          Expanded(child: _PrimaryColumn(layout: _DashboardLayout.expanded)),
          SizedBox(width: 16),
          Expanded(child: _AttentionColumn(layout: _DashboardLayout.expanded)),
        ],
      ),
    ),
  };
}

class _PrimaryColumn extends StatelessWidget {
  const _PrimaryColumn({required this.layout});

  final _DashboardLayout layout;

  @override
  Widget build(BuildContext context) {
    final missionHeight = layout == _DashboardLayout.expanded ? 158.0 : 172.0;
    final actionHeight = layout == _DashboardLayout.expanded ? 158.0 : 252.0;
    final gap = layout == _DashboardLayout.expanded ? 14.0 : 16.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: missionHeight,
          child: _MissionCard(layout: layout),
        ),
        SizedBox(height: gap),
        SizedBox(
          height: actionHeight,
          child: _QuickActions(layout: layout),
        ),
      ],
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.layout});

  final _DashboardLayout layout;

  @override
  Widget build(BuildContext context) => _GlassPanel(
    padding: EdgeInsets.all(layout == _DashboardLayout.expanded ? 18 : 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PanelTitle('Active mission'),
        const SizedBox(height: 12),
        const Text(
          'Mission telemetry unavailable',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Color(0xFF1B1B1F),
            fontSize: 16,
            height: 24 / 16,
          ),
        ),
        const Text(
          'No mission data in this telemetry stream',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Color(0xFF49454F),
            fontSize: 12,
            height: 16 / 12,
          ),
        ),
        const Spacer(),
        const Text('--'),
      ],
    ),
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.layout});

  final _DashboardLayout layout;

  void _unavailable(BuildContext context, String name) =>
      context.notifications.info(
        'Not available yet',
        description: '$name is not available in this build.',
      );

  @override
  Widget build(BuildContext context) {
    final buttons = [
      _ActionButton(
        icon: Icons.motion_photos_auto_outlined,
        label: 'Open Motion',
        primary: true,
        onTap: () => context.go(AppRoutes.motion),
      ),
      _ActionButton(
        icon: Icons.sports_esports_outlined,
        label: 'Open Controller',
        onTap: () => _unavailable(context, 'Controller'),
      ),
      _ActionButton(
        icon: Icons.smart_toy_outlined,
        label: 'Open AI Agent',
        onTap: () => _unavailable(context, 'AI Agent'),
      ),
    ];
    final expanded = layout == _DashboardLayout.expanded;
    return _GlassPanel(
      padding: EdgeInsets.all(expanded ? 18 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle('Quick actions'),
          SizedBox(height: expanded ? 8 : 12),
          Expanded(
            child: expanded
                ? Row(
                    children: [
                      for (var index = 0; index < buttons.length; index++) ...[
                        Expanded(child: buttons[index]),
                        if (index < buttons.length - 1)
                          const SizedBox(width: 12),
                      ],
                    ],
                  )
                : Column(
                    children: [
                      for (var index = 0; index < buttons.length; index++) ...[
                        SizedBox(height: 56, child: buttons[index]),
                        if (index < buttons.length - 1)
                          const SizedBox(height: 7),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(primary ? 999 : 24),
      onTap: onTap,
      child: Ink(
        height: 56,
        decoration: BoxDecoration(
          color: primary ? null : const Color(0x7AFFFFFF),
          gradient: primary
              ? const LinearGradient(
                  colors: [
                    Color(0xFF7A1FF2),
                    Color(0xFF9E2EFF),
                    Color(0xFF2985FF),
                  ],
                  stops: [0, .55, 1],
                )
              : null,
          borderRadius: BorderRadius.circular(primary ? 999 : 24),
          border: Border.all(color: const Color(0xC7FFFFFF)),
          boxShadow: primary
              ? null
              : const [BoxShadow(color: Color(0x14303D75), blurRadius: 14)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: primary ? Colors.white : AppColors.primary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: primary ? Colors.white : AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AttentionColumn extends StatelessWidget {
  const _AttentionColumn({required this.layout});

  final _DashboardLayout layout;

  @override
  Widget build(BuildContext context) {
    final expanded = layout == _DashboardLayout.expanded;
    final alertsHeight = switch (layout) {
      _DashboardLayout.compact => 168.0,
      _DashboardLayout.medium => 172.0,
      _DashboardLayout.expanded => 158.0,
    };
    final summaryHeight = switch (layout) {
      _DashboardLayout.compact => 128.0,
      _DashboardLayout.medium => 252.0,
      _DashboardLayout.expanded => 158.0,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: alertsHeight, child: const _AlertsCard()),
        SizedBox(height: expanded ? 14 : 16),
        SizedBox(height: summaryHeight, child: const _AiSummary()),
      ],
    );
  }
}

class _AlertsCard extends StatelessWidget {
  const _AlertsCard();

  @override
  Widget build(BuildContext context) => _GlassPanel(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PanelTitle('Active alerts'),
        const SizedBox(height: 12),
        Expanded(
          child: _GlassPanel(
            radius: 18,
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                Container(
                  height: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E1E6),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: const Color(0x3849454F)),
                  ),
                  child: const Row(
                    children: [
                      _Dot(color: Color(0xFF79747E)),
                      SizedBox(width: 8),
                      Text(
                        'Unknown',
                        style: TextStyle(
                          color: Color(0xFF49454F),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alerts unavailable',
                        maxLines: 1,
                        style: TextStyle(
                          color: Color(0xFF49454F),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Safety status is not provided by this telemetry stream',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF49454F),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _AiSummary extends StatelessWidget {
  const _AiSummary();

  @override
  Widget build(BuildContext context) => _GlassPanel(
    padding: const EdgeInsets.all(18),
    child: Stack(
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelTitle('AI summary'),
            SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: 44),
                child: Text(
                  'AI summary unavailable from this telemetry stream.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF1B1B1F),
                    fontSize: 14,
                    height: 20 / 14,
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: -4,
          top: -2,
          width: 56,
          height: 56,
          child: Image.asset(
            'assets/images/intelligence_orb.png',
            fit: BoxFit.contain,
          ),
        ),
      ],
    ),
  );
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: Color(0xFF28324C),
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w500,
    ),
  );
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.layout});

  static const events = [
    _ActivityData('Activity history unavailable from this telemetry stream'),
  ];

  final _DashboardLayout layout;

  @override
  Widget build(BuildContext context) {
    final expanded = layout == _DashboardLayout.expanded;
    final visibleEvents = expanded ? events.take(2) : events;
    return SizedBox(
      height: expanded ? 164 : 180,
      child: _GlassPanel(
        padding: EdgeInsets.fromLTRB(18, 16, 18, expanded ? 10 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PanelTitle('Recent activity'),
            SizedBox(height: expanded ? 8 : 12),
            for (final event in visibleEvents) ...[
              SizedBox(
                height: expanded ? 48 : 100,
                child: _ActivityItem(data: event),
              ),
              if (event != visibleEvents.last)
                SizedBox(height: expanded ? 8 : 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityData {
  const _ActivityData(this.label);

  final String label;
  final bool warning = false;
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({required this.data});

  final _ActivityData data;

  @override
  Widget build(BuildContext context) {
    final color = data.warning ? AppColors.warning : AppColors.info;
    final background = data.warning
        ? const Color(0xFFFFE08A)
        : const Color(0xFFD1E4FF);
    return _GlassPanel(
      radius: 14,
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Container(
            height: double.infinity,
            constraints: BoxConstraints(minWidth: data.warning ? 102 : 75),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  data.warning
                      ? Icons.warning_amber
                      : Icons.check_circle_outline,
                  color: color,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  data.warning ? 'Warning' : 'Info',
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              data.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF1B1B1F),
                fontSize: 12,
                height: 16 / 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: const Color(0x75FFFFFF),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xC7FFFFFF)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1733407A),
          blurRadius: 30,
          spreadRadius: -6,
          offset: Offset(0, 10),
        ),
        BoxShadow(
          color: Color(0xD9FFFFFF),
          blurRadius: 0,
          offset: Offset(0, 1),
        ),
      ],
    ),
    child: child,
  );
}
