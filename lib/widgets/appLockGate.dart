import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/appLock.dart';
import 'pinPad.dart';

// Covers the whole app with the PIN screen when the app lock is on:
// at start-up, and when coming back after more than a minute away.
// Does nothing while the lock is off (the default).
class AppLockGate extends StatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  static const _relockAfter = Duration(minutes: 1);

  bool _checked = false;
  bool _locked = false;
  bool _biometric = false;
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockIfEnabled();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _lockIfEnabled() async {
    bool enabled = false;
    bool biometric = false;
    try {
      enabled = await AppLock.isEnabled();
      biometric = enabled && await AppLock.isBiometricEnabled();
    } catch (_) {
      // Settings could not be read: show the app rather than a blank screen
    }
    if (!mounted) return;
    // Close the keyboard of whatever field was in use under the lock
    if (enabled) FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _checked = true;
      _locked = enabled;
      _biometric = biometric;
    });
    if (enabled && biometric) _tryBiometric();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !_locked) {
      _leftAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final leftAt = _leftAt;
      _leftAt = null;
      if (!_locked &&
          leftAt != null &&
          DateTime.now().difference(leftAt) >= _relockAfter) {
        _lockIfEnabled();
      }
    }
  }

  Future<void> _tryBiometric() async {
    if (await AppLock.authenticateWithBiometrics() && mounted) {
      setState(() => _locked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Screen readers must not read balances hidden behind the lock
        ExcludeSemantics(excluding: _locked || !_checked, child: widget.child),
        // Hide the app until we know whether it is locked
        if (!_checked)
          Positioned.fill(
            child: ColoredBox(color: Theme.of(context).colorScheme.surface),
          ),
        if (_locked)
          Positioned.fill(
            // Dark status-bar icons on the light lock screen (and the reverse)
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: Theme.of(context).brightness == Brightness.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
              child: Scaffold(
                body: SafeArea(
                  child: PinPad(
                    title: 'أدخل الرمز لفتح محفظتي',
                    onBiometric: _biometric ? _tryBiometric : null,
                    onCompleted: (pin) async {
                      if (await AppLock.checkPin(pin)) {
                        if (mounted) setState(() => _locked = false);
                        return null;
                      }
                      return 'رمز غير صحيح';
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
