import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:omnix_hub/services/rust_bridge.dart';
import 'package:omnix_hub/screens/dashboard_screen.dart';
import 'package:omnix_hub/screens/scan_screen.dart';
import 'package:omnix_hub/screens/quarantine_screen.dart';
import 'package:omnix_hub/screens/settings_screen.dart';
import 'package:omnix_hub/screens/update_screen.dart';
import 'package:omnix_hub/screens/events_screen.dart';
import 'package:omnix_hub/screens/risk_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => RustBridge(),
      child: const OmniXHubApp(),
    ),
  );
}

class OmniXHubApp extends StatelessWidget {
  const OmniXHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OmniX Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1A73E8),
        brightness: Brightness.dark,
        useMaterial3: true,
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const _screens = <Widget>[
    DashboardScreen(),
    ScanScreen(),
    QuarantineScreen(),
    EventsScreen(),
    RiskScreen(),
    UpdateScreen(),
    SettingsScreen(),
  ];

  static const _destinations = <NavigationRailDestination>[
    NavigationRailDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: Text('Dashboard'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.search_outlined),
      selectedIcon: Icon(Icons.search),
      label: Text('Scanner'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.shield_outlined),
      selectedIcon: Icon(Icons.shield),
      label: Text('Quarantine'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.event_note_outlined),
      selectedIcon: Icon(Icons.event_note),
      label: Text('Events'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.speed_outlined),
      selectedIcon: Icon(Icons.speed),
      label: Text('Risk'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.update_outlined),
      selectedIcon: Icon(Icons.update),
      label: Text('Updates'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: Text('Settings'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Icon(Icons.security, size: 32,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 4),
                    Text('OmniX',
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
              destinations: _destinations,
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: _screens[_selectedIndex]),
          ],
        ),
      );
    }

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.search_outlined), label: 'Scan'),
          NavigationDestination(
              icon: Icon(Icons.shield_outlined), label: 'Quarantine'),
          NavigationDestination(
              icon: Icon(Icons.event_note_outlined), label: 'Events'),
          NavigationDestination(
              icon: Icon(Icons.speed_outlined), label: 'Risk'),
          NavigationDestination(
              icon: Icon(Icons.update_outlined), label: 'Updates'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
