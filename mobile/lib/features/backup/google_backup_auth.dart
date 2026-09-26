import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleBackupAuth {
  static Future<void>? _initialize;

  static Future<UserCredential> signIn() async {
    _initialize ??= GoogleSignIn.instance.initialize();
    await _initialize;
    final account = await GoogleSignIn.instance.authenticate();
    final token = account.authentication.idToken;
    if (token == null) throw const FormatException('Google hesabının təsdiqi alınmadı.');
    return FirebaseAuth.instance.signInWithCredential(
      GoogleAuthProvider.credential(idToken: token));
  }

  static Future<void> signOut() async {
    _initialize ??= GoogleSignIn.instance.initialize();
    await _initialize;
    await FirebaseAuth.instance.signOut();
    try { await GoogleSignIn.instance.signOut(); }
    catch (_) { /* Firebase session has already been cleared. */ }
  }
}
