import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class NotesScreen extends StatefulWidget {
  final String lessonId; // courseId geliyor

  const NotesScreen({super.key, required this.lessonId});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool isTeacher = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      setState(() {
        isTeacher = doc['role'] == 'teacher';
      });
    }
  }

  Future<void> _uploadPDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      String fileName = result.files.single.name;
      String path = result.files.single.path!;

      // STORAGE KAYDI
      Reference ref = _storage.ref('courses/${widget.lessonId}/$fileName');
      await ref.putFile(File(path));

      String url = await ref.getDownloadURL();

      // FIRESTORE → courses koleksiyonunda pdf listesi
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.lessonId)
          .update({
        'pdfs': FieldValue.arrayUnion([
          {"name": fileName, "url": url}
        ])
      });
    }
  }

  Future<void> _openPDF(String url, String name) async {
    try {
      final response = await http.get(Uri.parse(url));
      final bytes = response.bodyBytes;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name');

      await file.writeAsBytes(bytes);

      await OpenFile.open(file.path);
    } catch (e) {
      print("PDF açılırken hata: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notlar"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),

      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('courses')         // 🔥 DÜZELTİLDİ: courses
            .doc(widget.lessonId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            FirebaseFirestore.instance
                .collection('courses')
                .doc(widget.lessonId)
                .set({'pdfs': []}, SetOptions(merge: true));

            return const Center(child: CircularProgressIndicator());
          }

          var lesson = snapshot.data!;
          List pdfs = lesson.data().toString().contains('pdfs') ? lesson['pdfs'] : [];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isTeacher) ...[
                  ElevatedButton(
                    onPressed: _uploadPDF,
                    child: const Text("PDF Yükle"),
                  ),
                  const SizedBox(height: 20),
                ],

                const Text(
                  "Yüklenen PDF'ler:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),

                const SizedBox(height: 10),

                Expanded(
                  child: ListView(
                    children: pdfs.map<Widget>((file) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                          title: Text(file["name"]),
                          trailing: const Icon(Icons.visibility),
                          onTap: () =>
                              _openPDF(file["url"], file["name"]),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
