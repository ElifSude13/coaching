import 'package:flutter/material.dart';
import 'package:coaching/screens/home_screen.dart';
import 'package:coaching/screens/calendar_screen.dart';
import 'package:coaching/screens/notes_screen.dart';
import 'package:coaching/screens/profile_screen.dart';
import 'package:coaching/screens/evaluations_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = const [
      HomeScreen(),
      CalendarScreen(),
      NotesScreen(lessonId: 'default'),
      ProfileScreen(),
      EvaluationScreen(lessonId: 'default'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,

        backgroundColor: Colors.black,

        // Iconlar PNG olduğu için burada renk değiştirilmez
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,

        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),

        items: [
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/icons/home.png',
              width: 28, height: 28,
            ),
            label: 'Ana Sayfa',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/icons/calendar.png',
              width: 28, height: 28,
            ),
            label: 'Takvim',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/icons/notes.png',
              width: 28, height: 28,
            ),
            label: 'Notlar',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/icons/male.png',   // 👈 kendi profil PNG’n
              width: 28, height: 28,
            ),
            label: 'Profil',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/icons/star.png',
              width: 28, height: 28,
            ),
            label: 'Değerlendirmeler',
          ),
        ],
      ),
    );
  }
}
