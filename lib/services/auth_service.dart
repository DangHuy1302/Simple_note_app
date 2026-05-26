import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Đăng ký bằng email/password
  Future<User?> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          throw 'Mật khẩu quá yếu (tối thiểu 6 ký tự)';
        case 'email-already-in-use':
          throw 'Email đã được sử dụng';
        case 'invalid-email':
          throw 'Email không hợp lệ';
        default:
          throw 'Lỗi đăng ký: ${e.message}';
      }
    }
  }

  // Đăng nhập bằng email/password
  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw 'Tài khoản không tồn tại';
        case 'wrong-password':
          throw 'Mật khẩu không chính xác';
        case 'invalid-credential':
          throw 'Email hoặc mật khẩu không chính xác';
        case 'invalid-email':
          throw 'Email không hợp lệ';
        default:
          throw 'Lỗi đăng nhập: ${e.message}';
      }
    }
  }

  // Đăng nhập bằng Google (google_sign_in v6.x API)
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw 'Đã hủy đăng nhập Google';
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw 'Lỗi Firebase: ${e.message}';
    } catch (e) {
      if (e.toString() == 'Đã hủy đăng nhập Google') rethrow;
      throw 'Lỗi đăng nhập Google: $e';
    }
  }

  // Đăng xuất
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  // Đặt lại mật khẩu
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw 'Lỗi: ${e.message}';
    }
  }
}
