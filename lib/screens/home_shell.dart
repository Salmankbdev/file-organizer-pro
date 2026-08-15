import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'duplicates_screen.dart';
import 'history_screen.dart';
import 'large_files_screen.dart';
import 'organize_screen.dart';
import 'rename_screen.dart';
import 'rules_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';
import 'storage_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// Switches the visible page. Used by quick actions on other screens.
  void select(int index) {
    if (index < 0 || index >= _pages.length) return;
    setState(() => _index = index);
  }

  static const _pages = [
    DashboardScreen(),
    ScanScreen(),
    OrganizeScreen(),
    RenameScreen(),
    DuplicatesScreen(),
    LargeFilesScreen(),
    RulesScreen(),
    StorageScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            groupAlignment: -0.9,
            leading: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.folder_copy_rounded,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'File Organizer Pro',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: Text('Scan'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.drive_file_move_outlined),
                selectedIcon: Icon(Icons.drive_file_move),
                label: Text('Organize'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.drive_file_rename_outline),
                selectedIcon: Icon(Icons.drive_file_rename_outline),
                label: Text('Rename'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.content_copy_outlined),
                selectedIcon: Icon(Icons.content_copy),
                label: Text('Duplicates'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.data_usage_outlined),
                selectedIcon: Icon(Icons.data_usage),
                label: Text('Large Files'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.rule_outlined),
                selectedIcon: Icon(Icons.rule),
                label: Text('Rules'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.pie_chart_outline),
                selectedIcon: Icon(Icons.pie_chart),
                label: Text('Storage'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: Text('History'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: _pages[_index]),
        ],
      ),
    );
  }
}
