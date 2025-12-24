import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EvaluationScreen extends StatefulWidget {
  final String lessonId;

  const EvaluationScreen({super.key, required this.lessonId});

  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  double _score = 5.0; // öğretmen için default puan
  final TextEditingController _commentController = TextEditingController();
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _getUserRole();
  }

  Future<void> _getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    setState(() {
      _userRole = doc['role'];
    });
  }

  Future<void> _submitEvaluation() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('courses').doc(widget.lessonId).set({
      'evaluations': {
        user.uid: {
          'score': _score,
          'comment': _commentController.text,
        }
      }
    }, SetOptions(merge: true));
  }

  Widget _buildStarRating() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        return IconButton(
          icon: Icon(
            _score >= starIndex ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 32,
          ),
          onPressed: () {
            setState(() {
              _score = starIndex.toDouble();
            });
          },
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userRole == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('courses').doc(widget.lessonId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        final courseData = snapshot.data?.data() as Map<String, dynamic>?;

        if (courseData == null) {
          return const Center(child: Text("Ders bilgisi yok"));
        }

        final title = courseData['title'] ?? 'Ders Değerlendirmeleri';
        final evaluations = courseData['evaluations'] != null
            ? Map<String, dynamic>.from(courseData['evaluations'])
            : <String, dynamic>{};

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // ----------------- Öğretmen için yorum + yıldızlı puan -----------------
                if (_userRole == 'teacher') ...[
                  const Text(
                    'Yeni Değerlendirme Ekle',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  _buildStarRating(),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      labelText: 'Yorum',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      await _submitEvaluation();
                      _commentController.clear();
                    },
                    child: const Text('Kaydet'),
                  ),
                  const Divider(height: 32),
                ],

                // ----------------- Mevcut değerlendirmeler -----------------
                Expanded(
                  child: evaluations.isEmpty
                      ? const Center(child: Text("Henüz değerlendirme yok"))
                      : ListView(
                          children: evaluations.entries.map<Widget>((e) {
                            final eval = Map<String, dynamic>.from(e.value);
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                leading: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(
                                    5,
                                    (index) => Icon(
                                      index < (eval['score'] ?? 0) ? Icons.star : Icons.star_border,
                                      color: Colors.amber,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                title: Text('Yorum: ${eval['comment'] ?? ""}'),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
