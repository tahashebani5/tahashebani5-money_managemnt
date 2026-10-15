import 'dart:async';
import 'package:flutter/material.dart';
import '../services/appLock.dart';
import 'commonWidgets.dart';

// Number pad with dots for entering a 4-digit PIN.
// After 5 wrong PINs, input is blocked for 30 seconds.
class PinPad extends StatefulWidget {
  final String title;
  final String? subtitle;
  // Returns null when the PIN is accepted, or an error message to show.
  final Future<String?> Function(String pin) onCompleted;
  // Shows a fingerprint key when set.
  final VoidCallback? onBiometric;
  // Message shown before anything is typed, e.g. after a mismatch.
  final String? initialError;

  const PinPad({
    super.key,
    required this.title,
    this.subtitle,
    required this.onCompleted,
    this.onBiometric,
    this.initialError,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';
  String? _error;
  bool _busy = false;
  int _failures = 0;
  DateTime? _blockedUntil;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _error = widget.initialError;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _secondsLeft {
    final until = _blockedUntil;
    if (until == null) return 0;
    final left = until.difference(DateTime.now()).inSeconds + 1;
    return left > 0 ? left : 0;
  }

  void _press(String digit) {
    if (_busy || _secondsLeft > 0 || _pin.length >= AppLock.pinLength) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == AppLock.pinLength) _submit();
  }

  void _backspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final error = await widget.onCompleted(_pin);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _pin = '';
      _error = error;
      if (error == null) {
        _failures = 0;
        return;
      }
      _failures++;
      if (_failures >= 5) {
        _failures = 0;
        _blockedUntil = DateTime.now().add(const Duration(seconds: 30));
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_secondsLeft == 0) timer.cancel();
          if (mounted) setState(() {});
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blocked = _secondsLeft;
    final message = blocked > 0 ? 'محاولات كثيرة خاطئة، انتظر $blocked ثانية' : _error;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: brandColor,
          child: const Icon(Icons.lock_outline, color: onBrand, size: 36),
        ),
        const SizedBox(height: 20),
        Text(widget.title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              widget.subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < AppLock.pinLength; i++)
              Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? scheme.primary : Colors.transparent,
                  border: Border.all(color: scheme.primary, width: 2),
                ),
              ),
          ],
        ),
        SizedBox(
          height: 48,
          child: Center(
            child: Text(message ?? '', style: TextStyle(color: scheme.error, fontWeight: FontWeight.bold)),
          ),
        ),
        // Number pads are laid out left-to-right even in Arabic apps
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']])
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [for (final d in row) _key(Text(d), () => _press(d))],
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  widget.onBiometric != null
                      ? _key(const Icon(Icons.fingerprint, size: 34), widget.onBiometric!, tooltip: 'البصمة')
                      : const SizedBox(width: 96, height: 80),
                  _key(const Text('0'), () => _press('0')),
                  _key(const Icon(Icons.backspace_outlined), _backspace, tooltip: 'حذف'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _key(Widget child, VoidCallback onTap, {String? tooltip}) {
    final button = SizedBox(
      width: 96,
      height: 80,
      child: Center(
        child: SizedBox(
          width: 72,
          height: 72,
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Center(
                child: DefaultTextStyle.merge(
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // A label for screen readers. Not a Tooltip: the lock screen sits above the
    // Navigator, where there is no Overlay for tooltips to use.
    return tooltip == null ? button : Semantics(label: tooltip, button: true, child: button);
  }
}

// Asks for a new PIN twice. Returns true when a PIN was saved.
Future<bool> showPinSetup(BuildContext context) async {
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (context) => const _PinSetupPage()),
  );
  return saved == true;
}

// Asks for the current PIN (or fingerprint, if enabled). Returns true if correct.
Future<bool> showPinVerify(BuildContext context, {required String title}) async {
  final biometric = await AppLock.isBiometricEnabled();
  if (!context.mounted) return false;
  final ok = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: PinPad(
            title: 'أدخل الرمز الحالي',
            onBiometric: biometric
                ? () async {
                    if (await AppLock.authenticateWithBiometrics() && context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  }
                : null,
            onCompleted: (pin) async {
              if (await AppLock.checkPin(pin)) {
                if (context.mounted) Navigator.of(context).pop(true);
                return null;
              }
              return 'رمز غير صحيح';
            },
          ),
        ),
      ),
    ),
  );
  return ok == true;
}

class _PinSetupPage extends StatefulWidget {
  const _PinSetupPage();

  @override
  State<_PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<_PinSetupPage> {
  String? _first;
  bool _mismatch = false;

  @override
  Widget build(BuildContext context) {
    final confirming = _first != null;
    return Scaffold(
      appBar: AppBar(title: const Text('رمز القفل')),
      body: SafeArea(
        child: PinPad(
          // New key per step so the dots reset
          key: ValueKey(confirming),
          title: confirming ? 'أعد إدخال الرمز للتأكيد' : 'اختر رمزاً من 4 أرقام',
          subtitle: confirming ? null : 'ستحتاج هذا الرمز كلما فتحت التطبيق',
          initialError: _mismatch ? 'الرمزان غير متطابقين، حاول مرة أخرى' : null,
          onCompleted: (pin) async {
            if (!confirming) {
              setState(() {
                _first = pin;
                _mismatch = false;
              });
              return null;
            }
            if (pin != _first) {
              setState(() {
                _first = null;
                _mismatch = true;
              });
              return null;
            }
            await AppLock.setPin(pin);
            if (mounted) Navigator.of(context).pop(true);
            return null;
          },
        ),
      ),
    );
  }
}
