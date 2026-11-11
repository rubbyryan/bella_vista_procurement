import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'api.dart';
import 'models.dart';
import 'state.dart';
import 'theme/bv_theme.dart';

// ---------------------------------------------------------------------------
// Formatting
// ---------------------------------------------------------------------------
String money(double v) => '\$${v.toStringAsFixed(2)}';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String dmy(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
String dm(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]}';
String hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String stamp(DateTime d) => '${dm(d)} ${hm(d)}';

// ---------------------------------------------------------------------------
// Theme helpers (Primary mode = Bella Blue canvas with white "islands")
// ---------------------------------------------------------------------------
bool isPrimaryMode(BuildContext c) => Theme.of(c).scaffoldBackgroundColor == BVColors.blue;
bool isDarkMode(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

/// Text colour for things placed directly on the canvas.
Color onCanvas(BuildContext c) =>
    Theme.of(c).textTheme.bodyMedium?.color ?? Theme.of(c).colorScheme.onSurface;

/// Orange used as text/numbers (passes contrast on cards).
Color accentText(BuildContext c) =>
    isDarkMode(c) ? BVColors.darkOrange : const Color(0xFFB8500A);

/// The ONE main call to action per screen: Vista Orange with an Ink label.
ButtonStyle ctaStyle(BuildContext c) {
  final s = Theme.of(c).colorScheme;
  return FilledButton.styleFrom(backgroundColor: s.secondary, foregroundColor: s.onSecondary);
}

/// Outlined button for use directly on the canvas (white on Primary).
ButtonStyle canvasOutlined(BuildContext c) {
  final col = onCanvas(c);
  return OutlinedButton.styleFrom(foregroundColor: col, side: BorderSide(color: col));
}

ButtonStyle dangerOutlined(BuildContext c) {
  final e = Theme.of(c).colorScheme.error;
  return OutlinedButton.styleFrom(foregroundColor: e, side: BorderSide(color: e));
}

void snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

// ---------------------------------------------------------------------------
// Logo
// ---------------------------------------------------------------------------
/// The logo always sits on a white badge (never recoloured, never on orange).
class LogoBadge extends StatelessWidget {
  const LogoBadge({super.key, this.size = 120});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.16),
      ),
      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
    );
  }
}

// ---------------------------------------------------------------------------
// Layout helpers
// ---------------------------------------------------------------------------
/// White card (an "island" on Primary mode). Anything with inputs, dropdowns or
/// dark text must live inside a Panel so it reads correctly in all 3 modes.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return BVSurface(
      child: Builder(builder: (c) {
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Row(children: [
                    Expanded(
                      child: Text(title!, style: Theme.of(c).textTheme.titleMedium),
                    ),
                    if (trailing != null) trailing!,
                  ]),
                  const SizedBox(height: 12),
                ],
                child,
              ],
            ),
          ),
        );
      }),
    );
  }
}

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({super.key, required this.children, this.minWidth = 220, this.gap = 16});
  final List<Widget> children;
  final double minWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      var cols = (box.maxWidth / minWidth).floor();
      if (cols < 1) cols = 1;
      if (cols > 4) cols = 4;
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final c in children) SizedBox(width: w, child: c)],
      );
    });
  }
}

class TwoCol extends StatelessWidget {
  const TwoCol({
    super.key,
    required this.left,
    required this.right,
    this.breakpoint = 900,
    this.leftFlex = 3,
    this.rightFlex = 2,
  });
  final Widget left;
  final Widget right;
  final double breakpoint;
  final int leftFlex;
  final int rightFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth >= breakpoint) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: leftFlex, child: left),
            const SizedBox(width: 16),
            Expanded(flex: rightFlex, child: right),
          ],
        );
      }
      return Column(children: [left, const SizedBox(height: 16), right]);
    });
  }
}

/// Standard scrolling page with a title, optional subtitle and header actions.
class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.children,
  });
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: ListView(
          padding: EdgeInsets.all(narrow ? 16 : 24),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 12,
              spacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: t.headlineMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, style: t.bodyMedium),
                    ],
                  ],
                ),
                if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ),
            const SizedBox(height: 16),
            for (final c in children) ...[c, const SizedBox(height: 16)],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// KPI card, chips
// ---------------------------------------------------------------------------
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.warn = false,
    this.onTap,
  });
  final String label;
  final String value;
  final IconData icon;
  final bool warn;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Builder(builder: (c) {
            final t = Theme.of(c);
            final color = warn ? accentText(c) : t.textTheme.headlineMedium?.color;
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(value,
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ],
                  ),
                ),
                Icon(icon, color: color),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// Status chip for any backend status string (e.g. PENDING_HEAD_APPROVAL).
class StatePill extends StatelessWidget {
  const StatePill(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) => StatusChip(statusLabel(status), statusKind(status));
}

enum StepState { done, current, todo, rejected }

class StepInfo {
  const StepInfo(this.label, this.state);
  final String label;
  final StepState state;
}

/// Approval position: green done, orange current, red rejected, grey to come.
class ChainStepper extends StatelessWidget {
  const ChainStepper(this.steps, {super.key});
  final List<StepInfo> steps;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    Color ring(StepState st) => switch (st) {
          StepState.done => s.tertiary,
          StepState.current => s.secondary,
          StepState.rejected => s.error,
          StepState.todo => s.outlineVariant,
        };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            SizedBox(
              width: 84,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: steps[i].state == StepState.done
                        ? s.tertiary
                        : (steps[i].state == StepState.rejected ? s.error : Colors.transparent),
                    border: Border.all(width: 2, color: ring(steps[i].state)),
                  ),
                  child: switch (steps[i].state) {
                    StepState.done => Icon(Icons.check, size: 16, color: s.onTertiary),
                    StepState.rejected => Icon(Icons.close, size: 16, color: s.onError),
                    StepState.current => Center(
                        child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: s.secondary))),
                    StepState.todo => null,
                  },
                ),
                const SizedBox(height: 4),
                Text(steps[i].label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
              ]),
            ),
            if (i < steps.length - 1)
              Container(
                width: 24,
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: steps[i].state == StepState.done ? s.tertiary : s.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }
}

/// A row in a list: reference, two text columns, amount, date, status chip.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.path,
    required this.ref,
    required this.a,
    required this.b,
    this.amount,
    this.date,
    required this.chip,
  });
  final String path;
  final String ref;
  final String a;
  final String b;
  final double? amount;
  final DateTime? date;
  final Widget chip;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => context.go(path),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: LayoutBuilder(builder: (context, box) {
          final amt = amount == null ? '' : money(amount!);
          final dt = date == null ? '' : dm(date!);
          if (box.maxWidth >= 640) {
            return Row(children: [
              SizedBox(width: 190, child: Text(ref, overflow: TextOverflow.ellipsis, style: t.titleMedium?.copyWith(fontSize: 14))),
              Expanded(flex: 2, child: Text(a, overflow: TextOverflow.ellipsis)),
              Expanded(flex: 4, child: Text(b, overflow: TextOverflow.ellipsis)),
              SizedBox(width: 90, child: Text(amt, textAlign: TextAlign.right)),
              SizedBox(width: 80, child: Text(dt, textAlign: TextAlign.right)),
              SizedBox(width: 170, child: Align(alignment: Alignment.centerRight, child: chip)),
            ]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(ref, overflow: TextOverflow.ellipsis, style: t.titleMedium?.copyWith(fontSize: 14))),
              chip,
            ]),
            const SizedBox(height: 2),
            Text('$a | $b', maxLines: 2, overflow: TextOverflow.ellipsis),
            Text('$amt${amt.isEmpty || dt.isEmpty ? '' : ' | '}$dt',
                style: t.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]);
        }),
      ),
    );
  }
}

/// Header row for the wide list tables.
class RowHeader extends StatelessWidget {
  const RowHeader(this.cols, {super.key});
  final List<String> cols; // ref, group, items, value, date, status
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        if (box.maxWidth < 640) return const SizedBox.shrink();
        final st = Theme.of(context).textTheme.labelSmall;
        return Container(
          color: Theme.of(context).colorScheme.primaryContainer,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(children: [
            SizedBox(width: 190, child: Text(cols[0], style: st)),
            Expanded(flex: 2, child: Text(cols[1], style: st)),
            Expanded(flex: 4, child: Text(cols[2], style: st)),
            SizedBox(width: 90, child: Text(cols[3], textAlign: TextAlign.right, style: st)),
            SizedBox(width: 80, child: Text(cols[4], textAlign: TextAlign.right, style: st)),
            SizedBox(width: 170, child: Text(cols[5], textAlign: TextAlign.right, style: st)),
          ]),
        );
      });
}

/// Shows loading / error (with retry) / data for any FutureProvider value.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.builder, this.onRetry});
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => const Panel(
        child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => Panel(
        child: Builder(builder: (c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.cloud_off_rounded, color: Theme.of(c).colorScheme.error),
            const SizedBox(width: 12),
            Expanded(child: Text('$e', style: TextStyle(color: Theme.of(c).colorScheme.error))),
          ]),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Try again')),
        ])),
      ),
    );
  }
}

/// Label above a value (used in detail headers).
class Fact extends StatelessWidget {
  const Fact(this.label, this.value, {super.key});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value.isEmpty ? '-' : value),
        ],
      );
}

class QtyStepper extends StatelessWidget {
  const QtyStepper({super.key, required this.value, required this.min, required this.max, required this.onChanged});
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.remove_circle_outline_rounded),
        onPressed: value > min ? () => onChanged(value - 1) : null,
      ),
      SizedBox(width: 32, child: Text('$value', textAlign: TextAlign.center)),
      IconButton(
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.add_circle_outline_rounded),
        onPressed: value < max ? () => onChanged(value + 1) : null,
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Appearance menu (System / Light / Dark / Primary)
// ---------------------------------------------------------------------------
class AppearanceMenuButton extends ConsumerWidget {
  const AppearanceMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(appearanceProvider);
    return PopupMenuButton<AppAppearance>(
      tooltip: 'Appearance',
      icon: Icon(Icons.palette_rounded, color: onCanvas(context)),
      initialValue: a,
      onSelected: (v) => ref.read(appearanceProvider.notifier).set(v),
      itemBuilder: (_) => const [
        PopupMenuItem(value: AppAppearance.system, child: Text('System')),
        PopupMenuItem(value: AppAppearance.light, child: Text('Light')),
        PopupMenuItem(value: AppAppearance.dark, child: Text('Dark')),
        PopupMenuItem(value: AppAppearance.primary, child: Text('Primary (brand)')),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Signature pad (always white with Bella Blue ink, in every mode)
// ---------------------------------------------------------------------------
class SignaturePainter extends CustomPainter {
  SignaturePainter(this.strokes);
  final List<List<Offset>> strokes; // normalised 0..1

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BVColors.blue
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final s in strokes) {
      if (s.isEmpty) continue;
      Offset p(Offset o) => Offset(o.dx * size.width, o.dy * size.height);
      if (s.length == 1) {
        canvas.drawCircle(p(s.first), 1.5, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(p(s.first).dx, p(s.first).dy);
      for (final o in s.skip(1)) {
        path.lineTo(p(o).dx, p(o).dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SignaturePainter old) => true;
}

class SignatureView extends StatelessWidget {
  const SignatureView(this.strokes, {super.key, this.height = 80});
  final List<List<Offset>> strokes;
  final double height;
  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BVColors.divider),
        ),
        child: CustomPaint(painter: SignaturePainter(strokes)),
      );
}

class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key, required this.onChanged, this.height = 140});
  final ValueChanged<List<List<Offset>>> onChanged;
  final double height;

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];
  Size _size = Size.zero;

  Offset _norm(Offset p) => Offset(
        _size.width == 0 ? 0 : (p.dx / _size.width).clamp(0.0, 1.0).toDouble(),
        _size.height == 0 ? 0 : (p.dy / _size.height).clamp(0.0, 1.0).toDouble(),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        LayoutBuilder(builder: (context, box) {
          _size = Size(box.maxWidth, widget.height);
          return Container(
            height: widget.height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BVColors.divider),
            ),
            child: RawGestureDetector(
              gestures: {
                EagerGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                        () => EagerGestureRecognizer(), (_) {}),
              },
              child: Listener(
                onPointerDown: (e) => setState(() => _strokes.add([_norm(e.localPosition)])),
                onPointerMove: (e) => setState(() {
                  if (_strokes.isNotEmpty) _strokes.last.add(_norm(e.localPosition));
                }),
                onPointerUp: (_) => widget.onChanged(List.of(_strokes)),
                child: CustomPaint(
                  painter: SignaturePainter(_strokes),
                  child: _strokes.isEmpty
                      ? const Center(
                          child: Text('Sign here', style: TextStyle(color: Color(0xFF8A8FB5))))
                      : null,
                ),
              ),
            ),
          );
        }),
        TextButton(
          onPressed: () {
            setState(_strokes.clear);
            widget.onChanged([]);
          },
          child: const Text('Clear'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dialogs
// ---------------------------------------------------------------------------
/// Comment dialog (web) / bottom sheet (mobile). The comment is mandatory:
/// the confirm button stays disabled until [minChars] characters are typed.
Future<String?> showCommentDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm rejection',
  List<String> quickReasons = const [],
  int minChars = 10,
}) {
  Widget form(BuildContext c) => _CommentForm(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        quickReasons: quickReasons,
        minChars: minChars,
      );
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<String>(
      context: context,
      builder: (c) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: BVSurface(child: form(c)),
        ),
      ),
    );
  }
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (c) => BVSurface(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
        child: SingleChildScrollView(child: form(c)),
      ),
    ),
  );
}

class _CommentForm extends StatefulWidget {
  const _CommentForm({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.quickReasons,
    required this.minChars,
  });
  final String title;
  final String message;
  final String confirmLabel;
  final List<String> quickReasons;
  final int minChars;

  @override
  State<_CommentForm> createState() => _CommentFormState();
}

class _CommentFormState extends State<_CommentForm> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final len = _ctrl.text.trim().length;
    final valid = len >= widget.minChars;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: t.colorScheme.errorContainer,
              child: Icon(Icons.close_rounded, color: t.colorScheme.error),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.title, style: t.textTheme.titleMedium)),
          ]),
          const SizedBox(height: 12),
          Text(widget.message),
          if (widget.quickReasons.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final q in widget.quickReasons)
                ActionChip(
                  label: Text(q),
                  onPressed: () => setState(() => _ctrl.text = q),
                ),
            ]),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            minLines: 3,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Comment *',
              hintText: 'Type the reason here...',
              errorText: len > 0 && !valid ? 'A comment is required (min ${widget.minChars} characters).' : null,
              helperText: '$len / ${widget.minChars} min characters. Saved with your name, role and time.',
            ),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: t.colorScheme.error,
                foregroundColor: t.colorScheme.onError,
              ),
              onPressed: valid ? () => Navigator.pop(context, _ctrl.text.trim()) : null,
              child: Text(widget.confirmLabel),
            ),
          ]),
        ],
      ),
    );
  }
}

Future<bool> confirmDialog(BuildContext context,
    {required String title, required String message, String confirmLabel = 'Confirm'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: BVSurface(child: Text(message)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(confirmLabel)),
      ],
    ),
  );
  return ok ?? false;
}

/// Runs a backend call, refreshes the data and tells the user what happened.
/// Returns true when it worked.
Future<bool> act(BuildContext context, WidgetRef ref, Future<void> Function() f, String okMsg) async {
  try {
    await f();
    refreshAll(ref);
    if (context.mounted) snack(context, okMsg);
    return true;
  } on ApiException catch (e) {
    if (context.mounted) snack(context, e.message);
    return false;
  } catch (e) {
    if (context.mounted) snack(context, '$e');
    return false;
  }
}

/// Small dialog with a few text fields. Returns the values in order, or null.
Future<List<String>?> askFields(
  BuildContext context, {
  required String title,
  required List<String> labels,
  List<String>? initial,
  List<bool>? required,
  String confirm = 'Continue',
  String? note,
  bool danger = false,
}) {
  final ctrls = [for (var i = 0; i < labels.length; i++) TextEditingController(text: initial != null && i < initial.length ? initial[i] : '')];
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      final ok = [for (var i = 0; i < labels.length; i++) (required != null && i < required.length && required[i]) ? ctrls[i].text.trim().isNotEmpty : true].every((x) => x);
      return AlertDialog(
        title: Text(title),
        content: BVSurface(
          child: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (note != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(note)),
                for (var i = 0; i < labels.length; i++) ...[
                  TextField(
                    controller: ctrls[i],
                    minLines: 1,
                    maxLines: 3,
                    onChanged: (_) => setS(() {}),
                    decoration: InputDecoration(labelText: labels[i] + ((required != null && i < required.length && required[i]) ? ' *' : '')),
                  ),
                  const SizedBox(height: 12),
                ],
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error, foregroundColor: Theme.of(ctx).colorScheme.onError) : null,
            onPressed: ok ? () => Navigator.pop(ctx, [for (final c in ctrls) c.text.trim()]) : null,
            child: Text(confirm),
          ),
        ],
      );
    }),
  );
}
