import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String? name;
  String? surname;
  String? gender;
  String? email;
  String? uid;
  String? role;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      uid = user.uid;
      email = user.email;

      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        setState(() {
          name = doc['name'];
          surname = doc['surname'];
          gender = doc['gender'];
          role = doc['role'];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: name == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // *** GENDER'A GÖRE RESİM GELECEK ***
                  CircleAvatar(
                    radius: 55,
                    backgroundImage: AssetImage(
                      gender == "female"
                          ? "assets/icons/female.png"
                          : "assets/icons/male.png",
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildProfileField("Ad Soyad", "$name $surname"),
                  const SizedBox(height: 12),

                  _buildProfileField("Cinsiyet", gender ?? "-"),
                  const SizedBox(height: 12),

                  _buildProfileField("E-posta", email ?? "-"),
                  const SizedBox(height: 12),

                  _buildCopyField("Kullanıcı ID", uid ?? "-"),
                  const SizedBox(height: 12),

                  _buildProfileField("Rol", role ?? "-"),
                ],
              ),
            ),
    );
  }

  // Normal Data Card
  Widget _buildProfileField(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  // UUID + Copy Icon
  Widget _buildCopyField(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child:
                    Text(value, style: const TextStyle(fontSize: 16), maxLines: 1),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Kopyalandı!")),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
