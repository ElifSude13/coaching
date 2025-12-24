import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _studentEmailController = TextEditingController();

  String userName = '';
  String userRole = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        userName = doc['name'] ?? 'Anonim';
        userRole = doc['role'] ?? 'student';
      });
    }
  }

  Future<void> _requestStudentByUid(String studentId) async {
    final teacher = _auth.currentUser;
    if (teacher == null || studentId.isEmpty) return;

    final studentDoc = await _firestore.collection('users').doc(studentId).get();
    if (!studentDoc.exists || studentDoc['role'] != 'student') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Öğrenci bulunamadı')),
      );
      return;
    }
   
    // Öğretmenin students listesine ekle
  await _firestore
        .collection('teacher_requests')
        .doc(teacher.uid)
        .collection('requests')
        .doc(studentId)
        .set({
      'teacherId': teacher.uid,
      'studentId': studentId,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });

    _studentEmailController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Öğrenciye ekleme isteği gönderildi')),
    );
  }

  Future<void> _removeStudent(String studentId) async {
    final teacher = _auth.currentUser;
    if (teacher == null) return;

    await _firestore
        .collection('teacher_students')
        .doc(teacher.uid)
        .collection('students')
        .doc(studentId)
        .delete();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Öğrenci silindi')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ana Sayfa"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await _auth.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hoş geldin, $userName 👋',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Öğretmense öğrenci ekleme bölümü
              if (userRole == 'teacher') ...[
                const Text('Öğrenci Ekle',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _studentEmailController,
                        decoration: const InputDecoration(
                          labelText: 'Öğrenci UID',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => _requestStudentByUid(_studentEmailController.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Ekle'),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                const Text(
                  'Öğrenci Listesi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('teacher_students')
                      .doc(currentUser?.uid)
                      .collection('students')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final students = snapshot.data?.docs ?? [];
                    if (students.isEmpty) {
                      return const Text('Henüz öğrenci eklenmemiş.');
                    }

                    return ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final student = students[index];
                        return Card(
                          child: ListTile(
                            title: FutureBuilder<DocumentSnapshot>(
                              future: _firestore.collection('users').doc(student['studentId']).get(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Text("Yükleniyor...");
                                }
                                final data = snapshot.data!;
                                final studentName = data['name'] ?? "Bilinmeyen öğrenci";
                                return Text(studentName);
                              },
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  _removeStudent(student['studentId']),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],

              // Öğrenci ise: gelen öğretmen isteklerini göster
              if (userRole == 'student') ...
              [ 
                const SizedBox(height: 30),
                const Text('Öğretmen İstekleri', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), 
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot>
                ( 
                  stream: _firestore
                    .collectionGroup('requests')
                    .where('studentId', isEqualTo: currentUser?.uid)
                    .where('status', isEqualTo: 'pending')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                  builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator()); 
                      }
                    final requests = snapshot.data?.docs ?? []; 
                    if (requests.isEmpty) {
                    return const Text('Yeni istek yok.'); 
                    }
                    return ListView.builder( 
                      physics: const NeverScrollableScrollPhysics(), 
                      shrinkWrap: true, 
                      itemCount: requests.length, 
                      itemBuilder: (context, index) {
                        final req = requests[index];
                        final teacherId = req['teacherId'];
                        return Card(
                          child: ListTile( 
                            title: FutureBuilder<DocumentSnapshot>(
                              future: _firestore.collection('users').doc(teacherId).get(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Text("Öğretmen yükleniyor...");
                                }
                                final data = snapshot.data!;
                                final teacherName = data['name'] ?? "Bilinmeyen öğretmen";
                                return Text('$teacherName sizi eklemek istiyor');
                              },
                            ),
                            trailing: Row( 
                              mainAxisSize: MainAxisSize.min, 
                              children: [
                                IconButton( 
                                  icon: const Icon(Icons.check, color: Colors.green),
                                  onPressed: () async {
                                    // Öğretmende öğrenciyi ekle 
                                    await _firestore
                                      .collection('teacher_students')
                                      .doc(teacherId)
                                      .collection('students')
                                      .doc(currentUser?.uid)
                                      .set({ 
                                    'studentId': currentUser?.uid,
                                    'timestamp': FieldValue.serverTimestamp(), 
                                    }); 

                                    // Öğrencinin öğretmenler listesine ekle 
                                    await _firestore
                                      .collection('student_teachers')
                                      .doc(currentUser?.uid)
                                      .collection('teachers')
                                      .doc(teacherId)
                                      .set({ 
                                    'teacherId': teacherId,
                                    'timestamp': FieldValue.serverTimestamp(), 
                                    }); 
                                    
                                    // İsteği kabul et 
                                    await req.reference.update({'status': 'accepted'});
                                  }, 
                                ), 
                                IconButton
                                ( 
                                  icon: const Icon(Icons.close, color: Colors.red), 
                                  onPressed: () async { 
                                    await req.reference.update({'status': 'rejected'}); 
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],

              const SizedBox(height: 30),

              const Text('Yaklaşan Dersler',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('lessons')
                    .orderBy('date', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final lessons = snapshot.data?.docs ?? [];
                  if (lessons.isEmpty) {
                    return const Center(child: Text('Yaklaşan ders yok.'));
                  }
                  return ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: lessons.length,
                    itemBuilder: (context, index) {
                      final lesson = lessons[index];
                      return Card(
                        child: ListTile(
                          title: Text(lesson['title'] ?? 'Ders'),
                          subtitle: Text('Tarih: ${lesson['date'] ?? '-'}'),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
