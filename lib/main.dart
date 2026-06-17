import 'package:flutter/material.dart';

import 'pages/agents_page.dart';
import 'pages/events_page.dart';
import 'pages/maintenance_page.dart';
import 'pages/nodes_page.dart';
import 'pages/overview_page.dart';
import 'pages/registry_page.dart';
import 'pages/telemetry_page.dart';

void main() {
  runApp(const AeroArcApp());
}

class AeroArcApp extends StatelessWidget {
  const AeroArcApp({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF030B1F);

    return MaterialApp(
      title: 'Aero Arc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF626CFF),
          secondary: Color(0xFF00CFA0),
          surface: Color(0xFF07132E),
          surfaceContainerLowest: Color(0xFF050F27),
          surfaceContainerLow: Color(0xFF081734),
          outline: Color(0xFF1A2D59),
          outlineVariant: Color(0xFF12254F),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
          titleLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontSize: 18, color: Color(0xFF9BA8C8)),
          bodyMedium: TextStyle(fontSize: 16, color: Color(0xFF94A2C3)),
          labelLarge: TextStyle(fontSize: 16, color: Color(0xFF7F8FB2)),
        ),
      ),
      initialRoute: AppSection.overview.route,
      onGenerateRoute: (settings) {
        final section = AppSection.fromLocation(settings.name);
        return MaterialPageRoute<void>(
          settings: RouteSettings(name: section.route),
          builder: (_) => AppShell(section: section),
        );
      },
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.section});

  final AppSection section;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) {
          return _MobileShell(section: section);
        }
        return _DesktopShell(section: section);
      },
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({required this.section});

  final AppSection section;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(section: section),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF040D25),
                    border: Border(
                      bottom: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(
                      children: [
                        Text(
                          _formattedNow(),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF13244D),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 10,
                                color: Color(0xFF00CFA0),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'API dashboards',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: Color(0xFF5A6BFF),
                          child: Text(
                            'OP',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(child: _sectionPage(section)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.section});

  final AppSection section;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF020A1D),
        border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                children: [
                  const Icon(Icons.bolt, size: 20, color: Color(0xFF5A6BFF)),
                  const SizedBox(width: 8),
                  Text(
                    'Aero Arc',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 32,
                      color: const Color(0xFF5E6FFF),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 14,
                ),
                children: [
                  for (final item in AppSection.values)
                    _SidebarItem(
                      item: item,
                      selected: item == section,
                      onTap: () => _navigateTo(context, item),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AERO_ARC_API_BASE_URL',
                    style: TextStyle(color: Color(0xFF6B7DA8), fontSize: 12),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Defaults to localhost:8080',
                    style: TextStyle(color: Color(0xFF5A6BFF), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppSection item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? const Color(0xFF2A3E7C) : Colors.transparent,
            ),
            color: selected ? const Color(0xFF101C3B) : null,
          ),
          child: Row(
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                size: 20,
                color: selected
                    ? const Color(0xFF6B7BFF)
                    : const Color(0xFF8C9BBC),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF7A89FF)
                        : const Color(0xFF94A2C3),
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({required this.section});

  final AppSection section;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(section.title), centerTitle: false),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              const ListTile(
                title: Text(
                  'Aero Arc',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
              const Divider(height: 1),
              for (final item in AppSection.values)
                ListTile(
                  leading: Icon(
                    item == section ? item.selectedIcon : item.icon,
                  ),
                  title: Text(item.title),
                  selected: item == section,
                  onTap: () {
                    Navigator.of(context).pop();
                    _navigateTo(context, item);
                  },
                ),
            ],
          ),
        ),
      ),
      body: _sectionPage(section),
    );
  }
}

void _navigateTo(BuildContext context, AppSection next) {
  if (ModalRoute.of(context)?.settings.name == next.route) return;
  Navigator.of(context).pushReplacementNamed(next.route);
}

Widget _sectionPage(AppSection section) {
  return switch (section) {
    AppSection.overview => const OverviewPage(),
    AppSection.aircraft => const AgentsPage(),
    AppSection.operations => const RegistryPage(),
    AppSection.preflight => const NodesPage(),
    AppSection.conformance => const TelemetryPage(),
    AppSection.maintenance => const MaintenancePage(),
    AppSection.records => const EventsPage(),
  };
}

String _formattedNow() {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final now = DateTime.now();
  var hour = now.hour;
  final minute = now.minute.toString().padLeft(2, '0');
  final suffix = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12;
  if (hour == 0) hour = 12;
  return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}, $hour:$minute $suffix';
}

enum AppSection {
  overview(
    title: 'Readiness',
    route: '/overview',
    icon: Icons.grid_view_outlined,
    selectedIcon: Icons.grid_view_rounded,
  ),
  aircraft(
    title: 'Aircraft',
    route: '/aircraft',
    icon: Icons.flight_outlined,
    selectedIcon: Icons.flight,
  ),
  operations(
    title: 'Operations',
    route: '/operations',
    icon: Icons.route_outlined,
    selectedIcon: Icons.route,
  ),
  preflight(
    title: 'Preflight',
    route: '/preflight',
    icon: Icons.fact_check_outlined,
    selectedIcon: Icons.fact_check,
  ),
  conformance(
    title: 'Conformance',
    route: '/conformance',
    icon: Icons.monitor_heart_outlined,
    selectedIcon: Icons.monitor_heart,
  ),
  maintenance(
    title: 'Maintenance',
    route: '/maintenance',
    icon: Icons.build_outlined,
    selectedIcon: Icons.build,
  ),
  records(
    title: 'Records',
    route: '/records',
    icon: Icons.description_outlined,
    selectedIcon: Icons.description,
  );

  const AppSection({
    required this.title,
    required this.route,
    required this.icon,
    required this.selectedIcon,
  });

  final String title;
  final String route;
  final IconData icon;
  final IconData selectedIcon;

  static AppSection fromLocation(String? location) {
    final uri = Uri.tryParse(location ?? '');
    final first = uri == null || uri.pathSegments.isEmpty
        ? 'overview'
        : uri.pathSegments.first;
    final path = '/$first';
    for (final section in values) {
      if (section.route == path) return section;
    }
    return AppSection.overview;
  }
}
