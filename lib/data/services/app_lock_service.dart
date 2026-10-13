import 'package:local_auth/local_auth.dart';

/// Optional biometric / device-credential app lock (Spec §12). Uses Android's
/// native authentication — no custom PIN storage.
class AppLockService {
  AppLockService._();
  static final AppLockService instance = AppLockService._();

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isSupported() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool supported = await _auth.isDeviceSupported();
      return canCheck || supported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
