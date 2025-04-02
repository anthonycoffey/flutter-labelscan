import 'package:flutter/material.dart';
import 'package:flutter_labelscan/screens/home_screen.dart';
import 'package:flutter_labelscan/screens/my_account_screen.dart'; // Will create this next

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; // Start with the first tab (HomeScreen)

  // List of widgets to display for each tab
  // Removed 'const' because HomeScreen() and MyAccountScreen() are not compile-time constants
  static final List<Widget> _widgetOptions = <Widget>[
    const HomeScreen(), // Can be const if HomeScreen is const constructible
    const MyAccountScreen(), // Can be const if MyAccountScreen is const constructible
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.label_important_outline), // Or document_scanner
            label: 'Label Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'My Account',
          ),
         ],
         currentIndex: _selectedIndex,
         selectedItemColor: Theme.of(context).colorScheme.primary, // Active tab color
         unselectedItemColor: Colors.grey, // Inactive tab color
         onTap: _onItemTapped,
       ),
    );
  }
}
