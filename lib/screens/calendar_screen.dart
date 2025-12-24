import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:coaching/screens/notes_screen.dart';
import 'package:coaching/screens/evaluations_screen.dart';


class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};

  String userRole = "student";

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection("users").doc(user.uid).get();

    userRole = doc.data()?["role"] ?? "student";

    await _loadUserEvents();

    setState(() {});
  }

  Future<void> _loadUserEvents() async {
    final user = _auth.currentUser;
    if (user == null) return;

    QuerySnapshot coursesSnap;

    if (userRole == 'teacher') {
      coursesSnap = await _firestore
          .collection('courses')
          .where('teacherId', isEqualTo: user.uid)
          .get();
    } else {
      coursesSnap = await _firestore
          .collection('courses')
          .where('studentIds', arrayContains: user.uid)
          .get();
    }

    final events = <DateTime, List<Map<String, dynamic>>>{};

    for (var doc in coursesSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      data["id"] = doc.id;
      final Timestamp ts = data['date'];
      final d = ts.toDate();
      final normalized = DateTime(d.year, d.month, d.day);

      events[normalized] = (events[normalized] ?? [])..add(data);
    }

    setState(() => _events = events);
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    return _events[normalized] ?? [];
  }

  void _addCourseDialog() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final titleController = TextEditingController();
    final descController = TextEditingController();

    DateTime? selectedDate = DateTime.now();

    List<DocumentSnapshot> allStudents = [];
    List<DocumentSnapshot> filteredStudents = [];
    String searchQuery = "";

    List<String> selectedStudentIds = [];

    final snap = await _firestore
        .collection("users")
        .where("role", isEqualTo: "student")
        .get();

    allStudents = snap.docs;
    filteredStudents = allStudents;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Yeni Ders Ekle"),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration:
                          const InputDecoration(labelText: "Ders Başlığı"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descController,
                      decoration:
                          const InputDecoration(labelText: "Açıklama"),
                    ),
                    const SizedBox(height: 10),

                    /// ---------------- TARİH SEÇİCİ ----------------
                    ElevatedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setStateDialog(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Text(
                        selectedDate == null
                            ? "Tarih Seç"
                            : "Tarih: ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
                      ),
                    ),

                    const Divider(height: 24),
                    const Text("Öğrenciler",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    TextField(
                      decoration: const InputDecoration(
                        labelText: "Öğrenci Ara",
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (val) {
                        searchQuery = val.trim().toLowerCase();
                        setStateDialog(() {
                          filteredStudents = allStudents.where((d) {
                            final name =
                                (d['name'] ?? '').toString().toLowerCase();
                            return name.contains(searchQuery);
                          }).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      height: 260,
                      child: ListView.builder(
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = filteredStudents[index];
                          final id = student.id;
                          final name = student['name'] ?? "Bilinmeyen";

                          final isSelected =
                              selectedStudentIds.contains(id);

                          return CheckboxListTile(
                            value: isSelected,
                            title: Text(name),
                            onChanged: (val) {
                              setStateDialog(() {
                                if (val == true) {
                                  selectedStudentIds.add(id);
                                } else {
                                  selectedStudentIds.remove(id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                child: const Text("İptal"),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: const Text("Ekle"),
                onPressed: () async {
                  if (titleController.text.isEmpty || selectedDate == null) {
                    return;
                  }

                  await _firestore.collection("courses").add({
                    'title': titleController.text,
                    'description': descController.text,
                    'teacherId': user.uid,
                    'studentIds': selectedStudentIds,
                    'date': Timestamp.fromDate(selectedDate!),
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  Navigator.pop(context);
                  _loadUserEvents();
                },
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _deleteCourse(String courseId) async {
    await _firestore.collection("courses").doc(courseId).delete();
    _loadUserEvents(); // takvimi yenile
  }

  void _editCourseDialog(String courseId, Map<String, dynamic> oldData) async {
    final titleController = TextEditingController(text: oldData['title'] ?? "");
    final descController = TextEditingController(text: oldData['description'] ?? "");
    DateTime selectedDate = (oldData['date'] as Timestamp).toDate();

    // Mevcut öğrenciler
    List<String> selectedStudentIds = List<String>.from(oldData['studentIds'] ?? []);

    // Tüm öğrenciler
    List<DocumentSnapshot> allStudents = [];
    List<DocumentSnapshot> filteredStudents = [];
    String searchQuery = "";

    final snap = await _firestore
        .collection("users")
        .where("role", isEqualTo: "student")
        .get();
    allStudents = snap.docs;
    filteredStudents = allStudents;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Dersi Düzenle"),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: "Ders Başlığı"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: "Açıklama"),
                    ),
                    const SizedBox(height: 10),

                    ElevatedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2023),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setStateDialog(() => selectedDate = picked);
                        }
                      },
                      child: Text(
                          "Tarih: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}"),
                    ),

                    const Divider(height: 24),
                    const Text("Öğrenciler",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    TextField(
                      decoration: const InputDecoration(
                        labelText: "Öğrenci Ara",
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (val) {
                        searchQuery = val.trim().toLowerCase();
                        setStateDialog(() {
                          filteredStudents = allStudents.where((d) {
                            final name = (d['name'] ?? '').toString().toLowerCase();
                            return name.contains(searchQuery);
                          }).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      height: 260,
                      child: ListView.builder(
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = filteredStudents[index];
                          final id = student.id;
                          final name = student['name'] ?? "Bilinmeyen";

                          final isSelected = selectedStudentIds.contains(id);

                          return CheckboxListTile(
                            value: isSelected,
                            title: Text(name),
                            onChanged: (val) {
                              setStateDialog(() {
                                if (val == true) {
                                  selectedStudentIds.add(id);
                                } else {
                                  selectedStudentIds.remove(id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                child: const Text("İptal"),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: const Text("Kaydet"),
                onPressed: () async {
                  await _firestore.collection("courses").doc(courseId).update({
                    'title': titleController.text,
                    'description': descController.text,
                    'date': Timestamp.fromDate(selectedDate),
                    'studentIds': selectedStudentIds, // öğrenciler de kaydediliyor
                  });

                  Navigator.pop(context);
                  _loadUserEvents();
                },
              ),
            ],
          );
        });
      },
    );
  }

  
  void _openCourseMenu(Map<String, dynamic> event) {
    final DateTime courseDate = (event["date"] as Timestamp).toDate();
    final bool isPast = courseDate.isBefore(DateTime.now());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(event["title"] ?? "Ders"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.picture_as_pdf, color: Colors.orange),
                title: Text("Notlara Git"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          NotesScreen(lessonId: event["id"]), // 👍 bağlıyoruz
                    ),
                  );
                },
              ),

              ListTile(
                leading: Icon(Icons.info, color: Colors.blue),
                title: Text("Ders Bilgileri"),
                onTap: () {
                  Navigator.pop(context);
                  _showCourseDetails(event);
                },
              ),

              if (userRole == "teacher")
                ListTile(
                  leading: Icon(Icons.edit, color: Colors.green),
                  title: Text("Dersi Düzenle"),
                  onTap: () {
                    Navigator.pop(context);
                    _editCourseDialog(event["id"], event);
                  },
                ),

              if (userRole == "teacher")
                ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text("Dersi Sil"),
                  onTap: () async {
                    Navigator.pop(context);
                    await _deleteCourse(event["id"]);
                  },
                ),
              if (isPast)
                ListTile(
                  leading: Icon(Icons.rate_review, color: Colors.purple),
                  title: Text("Değerlendirmeler"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EvaluationScreen(lessonId: event["id"]),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showCourseDetails(Map<String, dynamic> event) {
    final date = (event["date"] as Timestamp).toDate();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(event["title"]),
          content: Text(
            "Açıklama: ${event["description"]}\n"
            "Tarih: ${date.day}/${date.month}/${date.year}",
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final selectedEvents =
        _selectedDay != null ? _getEventsForDay(_selectedDay!) : [];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Takvim"),
        backgroundColor: Colors.black,   // üst bar siyah
        foregroundColor: Colors.white,   // yazı beyaz
        actions: [
          if (userRole == "teacher")
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addCourseDialog,
            ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
            onDaySelected: (sd, fd) {
              setState(() {
                _selectedDay = sd;
                _focusedDay = fd;
              });
            },
            eventLoader: _getEventsForDay,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: selectedEvents.isEmpty
                ? const Center(child: Text("Bu gün ders yok."))
                : ListView.builder(
                    itemCount: selectedEvents.length,
                    itemBuilder: (context, index) {
                      final event = selectedEvents[index];

                      final teacherId = event["teacherId"] ?? "";
                      final List studentIds =
                          (event["studentIds"] ?? []) as List;

                      return InkWell(
                        onTap: () => _openCourseMenu(event),
                        child: Card(
                          margin: const EdgeInsets.all(10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(event["title"] ?? "",
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                if ((event["description"] ?? "").isNotEmpty)
                                  Text(event["description"]),
                                const SizedBox(height: 12),

                                /// ------------ ÖĞRETMEN ------------
                                FutureBuilder<DocumentSnapshot>(
                                  future: _firestore
                                      .collection('users')
                                      .doc(teacherId)
                                      .get(),
                                  builder: (context, snap) {
                                    if (!snap.hasData) {
                                      return const Text(
                                          "Öğretmen yükleniyor...");
                                    }
                                    final data = snap.data?.data()
                                        as Map<String, dynamic>?;
                                    final tName =
                                        data?['name'] ?? "Bilinmeyen Öğretmen";
                                    return Text("Öğretmen: $tName");
                                  },
                                ),
                                const SizedBox(height: 12),

                                /// ------------ ÖĞRENCİLER ------------
                                const Text("Katılımcı öğrenciler:",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),

                                if (studentIds.isEmpty)
                                  const Text("Herhangi bir öğrenci yok"),

                                ...studentIds.map((sid) {
                                  return FutureBuilder<DocumentSnapshot>(
                                    future: _firestore
                                        .collection('users')
                                        .doc(sid)
                                        .get(),
                                    builder: (context, snap) {
                                      if (!snap.hasData) {
                                        return const Text("Yükleniyor...");
                                      }
                                      final data = snap.data?.data()
                                          as Map<String, dynamic>?;
                                      final sName =
                                          data?['name'] ?? "Bilinmeyen Öğrenci";
                                      return Text("- $sName");
                                    },
                                  );
                                }).toList(),
                                const SizedBox(height: 12),

                              ],
                            ),
                          ),
                        )
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }
}
