import 'package:flutter/material.dart';

import '../widgets/redl_bottom_nav.dart';
import 'feed_screen.dart';
import 'garage_screen.dart';
import 'photos_screen.dart';
import 'profile_screen.dart';
import 'record_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    FeedScreen(),
    RecordScreen(),
    GarageScreen(),
    PhotosScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: RedlBottomNav(currentIndex: _index, onTap: (i) => setState(() => _index = i)),
    );
  }
}
