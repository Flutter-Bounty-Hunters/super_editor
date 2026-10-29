import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'metrics.dart';

abstract final class Palette {
  static const background = Color(0xFF101212);
  static const sidebar = Color(0xFF141616);
  static const surface = Color(0xFF191C1B);
  static const raised = Color(0xFF202422);
  static const border = Color(0xFF2D3430);
  static const text = Color(0xFFE8EDEA);
  static const muted = Color(0xFF969F99);
  static const green = Color(0xFF54DCA0);
  static const p95 = Color(0xFF7FAE98);
  static const lightOrange = Color(0xFFF1D3A6);
  static const amber = Color(0xFFE9B86E);
  static const red = Color(0xFFF28C95);
  static const baseline = Color(0xFF46514B);
}

const cpuColors = <String, Color>{
  'numeric_model_preparation': Color(0xFF9B75FF),
  'exact_fragment_artifacts': Color(0xFFFFAA45),
  'source_preparation': Color(0xFF37CDE6),
  'numeric_chunk_preparation': Color(0xFFFF5BA7),
  'numeric_exact_widths': Color(0xFFB6E84B),
  'numeric_candidate_search': Color(0xFF427DFF),
  'fragment_commit': Color(0xFFFFE267),
  'gc': Color(0xFFFF5959),
  'child_layout': Color(0xFF40D991),
  'other_layout': Color(0xFFDCE3E8),
};

const cpuDescriptions = <String, String>{
  'numeric_model_preparation': 'Builds the fast text-width model.',
  'exact_fragment_artifacts': 'Creates exact Flutter text fragments.',
  'source_preparation': 'Prepares content and text break points.',
  'numeric_chunk_preparation': 'Prepares chunks for width estimation.',
  'numeric_exact_widths': 'Measures text widths needed by the model.',
  'numeric_candidate_search': 'Finds a break point that fits the line.',
  'fragment_commit': 'Adds chosen fragments to the layout.',
  'gc': 'Reclaims unused memory.',
  'child_layout': 'Lays out inline Flutter widgets.',
  'other_layout': 'Layout work outside the named categories.',
};

class Panel extends StatelessWidget {
  const Panel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(24)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
            color: Palette.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Palette.border)),
        child: child,
      );
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = Palette.muted, this.icon});
  final String text;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .07),
            border: Border.all(color: color.withValues(alpha: .23)),
            borderRadius: BorderRadius.circular(5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5)
          ],
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ]),
      );
}

Widget caption(String text) => Text(text,
    style: const TextStyle(
        color: Palette.muted,
        fontSize: 11,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w500));
Widget muted(String text, {double size = 12}) => Text(text,
    style: TextStyle(color: Palette.muted, fontSize: size, height: 1.6));
Widget mono(String text, {double size = 13, Color color = Palette.text}) =>
    Text(text,
        style: TextStyle(
            fontFamily: 'DashboardMono', fontSize: size, color: color));

class StatCard extends StatelessWidget {
  const StatCard(
      {super.key,
      required this.label,
      required this.value,
      required this.detail,
      required this.icon,
      this.color = Palette.text,
      this.onTap});
  final String label, value, detail;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Panel(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 12, color: Palette.muted))),
                Icon(icon, size: 16, color: Palette.muted)
              ]),
              const SizedBox(height: 18),
              Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: mono(value, size: 27, color: color))),
              const SizedBox(height: 9),
              Text(detail,
                  style: TextStyle(
                      fontSize: 11,
                      color: color == Palette.text ? Palette.muted : color)),
            ])),
      ));
}

class SampleSparkline extends StatelessWidget {
  const SampleSparkline({super.key, required this.samples});
  final List<double> samples;
  @override
  Widget build(BuildContext context) => Semantics(
      label:
          '${samples.length} measured layout samples, ${milliseconds(samples.reduce(math.min))} to ${milliseconds(samples.reduce(math.max))} milliseconds',
      child: SizedBox(
          height: 84,
          width: double.infinity,
          child: CustomPaint(painter: _SparklinePainter(samples))));
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter(this.values);
  final List<double> values;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final low = values.reduce(math.min), high = values.reduce(math.max);
    final spread = math.max(.1, high - low);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final point = Offset(i / (values.length - 1) * size.width,
          size.height - 10 - (values[i] - low) / spread * (size.height - 20));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        fill,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x2354DCA0), Color(0x0054DCA0)])
              .createShader(Offset.zero & size));
    canvas.drawPath(
        path,
        Paint()
          ..color = Palette.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values;
}

/// Budget status is shared by bars and values; p95 uses a muted tail shade.
Color timingColor(TimingStatistic statistic,
    {double? milliseconds, double? budget}) {
  final tail = statistic == TimingStatistic.p95;
  if (milliseconds != null && budget != null) {
    if (milliseconds > budget) {
      return tail ? const Color(0xFFBD737C) : Palette.red;
    }
    if (milliseconds >= budget * .8) {
      return tail ? const Color(0xFFBD9B6B) : Palette.amber;
    }
  }
  return tail ? Palette.p95 : Palette.green;
}

class FrameMarkerLine extends StatelessWidget {
  const FrameMarkerLine({super.key, required this.major});
  final bool major;
  @override
  Widget build(BuildContext context) => major
      ? Container(
          width: 3,
          decoration: BoxDecoration(color: Palette.amber, boxShadow: [
            BoxShadow(
                color: Palette.amber.withValues(alpha: .25), blurRadius: 7)
          ]))
      : SizedBox(
          width: 1.5, child: CustomPaint(painter: _DashedFramePainter()));
}

class _DashedFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Palette.lightOrange
      ..strokeWidth = 1.5;
    for (var y = 0.0; y < size.height; y += 11) {
      canvas.drawLine(Offset(size.width / 2, y),
          Offset(size.width / 2, math.min(y + 5, size.height)), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedFramePainter oldDelegate) => false;
}
