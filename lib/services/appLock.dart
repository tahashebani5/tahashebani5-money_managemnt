import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'Database_Services.dart';

// Optional app lock (off by default). The PIN is never stored, only a
// salted SHA-256 hash of it, in the settings table.
class AppLock {
  static const _enabledKey = 'lock_enabled';
  static const _hashKey = 'pin_hash';
  static const _saltKey = 'pin_salt';
  static const _biometricKey = 'biometric_enabled';
  static const int pinLength = 4;

  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isEnabled() async => await DatabaseHelper().getSetting(_enabledKey) == '1';

  static Future<bool> isBiometricEnabled() async =>
      await isEnabled() && await DatabaseHelper().getSetting(_biometricKey) == '1';

  static String _hash(String salt, String pin) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  // Saves a new PIN and turns the lock on.
  static Future<void> setPin(String pin) async {
    final random = Random.secure();
    final salt = base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
    final db = DatabaseHelper();
    await db.setSetting(_saltKey, salt);
    await db.setSetting(_hashKey, _hash(salt, pin));
    await db.setSetting(_enabledKey, '1');
  }

  static Future<bool> checkPin(String pin) async {
    final db = DatabaseHelper();
    final salt = await db.getSetting(_saltKey);
    final hash = await db.getSetting(_hashKey);
    if (salt == null || hash == null || hash.isEmpty) return false;
    return _hash(salt, pin) == hash;
  }

  // Turns the lock off and forgets the PIN.
  static Future<void> disable() async {
    final db = DatabaseHelper();
    await db.setSetting(_enabledKey, '0');
    await db.setSetting(_biometricKey, '0');
    await db.setSetting(_hashKey, '');
  }

  static Future<void> setBiometricEnabled(bool enabled) =>
      DatabaseHelper().setSetting(_biometricKey, enabled ? '1' : '0');

  // True when the phone has a fingerprint/face sensor with something enrolled.
  static Future<bool> canUseBiometrics() async {
    try {
      return await _auth.canCheckBiometrics && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticateWithBiometrics() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'افتح محفظتي',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
