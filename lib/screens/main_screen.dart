import 'package:flutter/material.dart';
import 'package:flutter_labelscan/screens/home_screen.dart';
import 'package:flutter_labelscan/screens/my_account_screen.dart';
import 'package:flutter_labelscan/screens/saved_lists_screen.dart'; // Import the new screen

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; // Start with the first tab (HomeScreen)

  // List of widgets to display for each tab
  // List of widgets to display for each tab
  static final List<Widget> _widgetOptions = <Widget>[
    const HomeScreen(),
    const SavedListsScreen(), // Add the SavedListsScreen
    const MyAccountScreen(),
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
            icon: Icon(Icons.qr_code_scanner), // Use QR code icon
            label: 'Scan Label',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history), // Icon for saved lists
            label: 'Saved',
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
