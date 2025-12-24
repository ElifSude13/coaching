import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Kullanıcı kaydı
  Future<User?> registerUser({
    required String email,
    required String password,
    required String name,
    required String surname,
    required String role,
    required String gender,
  }) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = cred.user;

      // ❗ Firestore kaydı — eksik olan "uid" eklendi
      await _firestore.collection('users').doc(user!.uid).set({
        'uid': user.uid,                // 👈 ÖNEMLİ
        'name': name,
        'surname': surname,
        'email': email,
        'role': role,
        'gender': gender,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return user;
    } catch (e) {
      print('Register Error: $e');
      return null;
    }
  }

  // Kullanıcı girişi
  Future<User?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return cred.user;
    } catch (e) {
      print('Login Error: $e');
      return null;
    }
  }

  Future<void> logout() async => await _auth.signOut();
}
