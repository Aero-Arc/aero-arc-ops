import 'package:flutter/material.dart';

import 'pages/agents_page.dart';
import 'pages/aircraft_map_screen.dart';
import 'pages/events_page.dart';
import 'pages/intent_workflow_page.dart';
import 'pages/maintenance_page.dart';
import 'pages/nodes_page.dart';
import 'pages/overview_page.dart';
import 'pages/readiness_page.dart';
import 'widgets/operations_header.dart';
import 'pages/registry_page.dart';
import 'pages/telemetry_page.dart';

void main() {
  runApp(const AeroArcApp());
}

class AeroArcApp extends StatelessWidget {
  const AeroArcApp({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0B1016);

    return MaterialApp(
      title: 'Aero Arc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF16C8E0),
          secondary: Color(0xFF21C997),
          primaryContainer: Color(0xFF0D303A),
          onPrimaryContainer: Color(0xFF50D9E9),
          secondaryContainer: Color(0xFF0D303A),
          onSecondaryContainer: Color(0xFF50D9E9),
          surface: Color(0xFF101720),
          surfaceContainerLowest: Color(0xFF0B1016),
          surfaceContainerLow: Color(0xFF121B25),
          outline: Color(0xFF263342),
          outlineVariant: Color(0xFF202C39),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontSize: 14, color: Color(0xFFA3AFBE)),
          bodyMedium: TextStyle(fontSize: 13, color: Color(0xFFA3AFBE)),
          labelLarge: TextStyle(fontSize: 13, color: Color(0xFF8797AB)),
        ),
      ),
      initialRoute: AppSection.overview.route,
      onGenerateRoute: (settings) {
        final route = _resolveRoute(settings.name);
        final intentArgs = settings.arguments is IntentWorkflowRouteArguments
            ? settings.arguments as IntentWorkflowRouteArguments
            : null;
        return _NoTransitionPageRoute(
          settings: RouteSettings(name: route.name),
          child: AppShell(
            section: route.section,
            aircraftMapId: route.aircraftMapId,
            intentAircraftId: route.intentAircraftId,
            intentArgs: intentArgs,
          ),
        );
      },
    );
  }
}

class _NoTransitionPageRoute extends PageRoute<void> {
  _NoTransitionPageRoute({required super.settings, required this.child});

  final Widget child;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return child;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.section,
    this.aircraftMapId,
    this.intentAircraftId,
    this.intentArgs,
    this.renderMapTiles = true,
  });

  final AppSection section;
  final String? aircraftMapId;
  final String? intentAircraftId;
  final IntentWorkflowRouteArguments? intentArgs;
  final bool renderMapTiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) {
          return _MobileShell(
            section: section,
            aircraftMapId: aircraftMapId,
            intentAircraftId: intentAircraftId,
            intentArgs: intentArgs,
            renderMapTiles: renderMapTiles,
          );
        }
        return _DesktopShell(
          section: section,
          aircraftMapId: aircraftMapId,
          intentAircraftId: intentAircraftId,
          intentArgs: intentArgs,
          renderMapTiles: renderMapTiles,
        );
      },
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.section,
    this.aircraftMapId,
    this.intentAircraftId,
    this.intentArgs,
    this.renderMapTiles = true,
  });

  final AppSection section;
  final String? aircraftMapId;
  final String? intentAircraftId;
  final IntentWorkflowRouteArguments? intentArgs;
  final bool renderMapTiles;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(section: section),
          Expanded(
            child: Column(
              children: [
                const OperationsHeader(),
                Expanded(
                  child: _sectionPage(
                    section,
                    aircraftMapId,
                    intentAircraftId,
                    intentArgs,
                    renderMapTiles: renderMapTiles,
                  ),
                ),
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
      width: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF090E14),
        border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.hexagon_outlined,
                    size: 24,
                    color: Color(0xFF16C8E0),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Aero Arc',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        color: const Color(0xFFE5EBF2),
                      ),
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
                    'AERO ARC OPERATIONS',
                    style: TextStyle(color: Color(0xFF8797AB), fontSize: 12),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Fleet & mission workspace',
                    style: TextStyle(color: Color(0xFF16C8E0), fontSize: 12),
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? const Color(0xFF16404A) : Colors.transparent,
            ),
            color: selected ? const Color(0xFF0D242D) : null,
          ),
          child: Row(
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                size: 17,
                color: selected
                    ? const Color(0xFF16C8E0)
                    : const Color(0xFF8797AB),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF50D9E9)
                        : const Color(0xFFA3AFBE),
                    fontSize: 13,
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
  const _MobileShell({
    required this.section,
    this.aircraftMapId,
    this.intentAircraftId,
    this.intentArgs,
    this.renderMapTiles = true,
  });

  final AppSection section;
  final String? aircraftMapId;
  final String? intentAircraftId;
  final IntentWorkflowRouteArguments? intentArgs;
  final bool renderMapTiles;

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
      body: _sectionPage(
        section,
        aircraftMapId,
        intentAircraftId,
        intentArgs,
        renderMapTiles: renderMapTiles,
      ),
    );
  }
}

void _navigateTo(BuildContext context, AppSection next) {
  if (ModalRoute.of(context)?.settings.name == next.route) return;
  Navigator.of(context).pushReplacementNamed(next.route);
}

Widget _sectionPage(
  AppSection section,
  String? aircraftMapId,
  String? intentAircraftId,
  IntentWorkflowRouteArguments? intentArgs, {
  bool renderMapTiles = true,
}) {
  if (aircraftMapId != null) {
    return AircraftMapScreen(
      aircraftId: aircraftMapId,
      renderTiles: renderMapTiles,
    );
  }
  if (intentAircraftId != null) {
    return IntentWorkflowPage(
      aircraftId: intentAircraftId,
      initialIntent: intentArgs?.initialIntent,
      initialVolumes: intentArgs?.initialVolumes ?? const [],
      initialVolumeCenter: intentArgs?.initialVolumeCenter,
      renderTiles: renderMapTiles,
    );
  }
  return switch (section) {
    AppSection.overview => OverviewPage(renderTiles: renderMapTiles),
    AppSection.readiness => const ReadinessPage(),
    AppSection.aircraft => const AgentsPage(),
    AppSection.operations => const RegistryPage(),
    AppSection.preflight => const NodesPage(),
    AppSection.conformance => const TelemetryPage(),
    AppSection.maintenance => const MaintenancePage(),
    AppSection.records => const EventsPage(),
  };
}

_ResolvedRoute _resolveRoute(String? location) {
  final uri = Uri.tryParse(location ?? '');
  final segments = uri?.pathSegments ?? const <String>[];
  if (segments.length == 3 &&
      segments[0] == 'aircraft' &&
      segments[2] == 'map') {
    return _ResolvedRoute(
      section: AppSection.aircraft,
      name: '/aircraft/${segments[1]}/map',
      aircraftMapId: segments[1],
    );
  }
  if (segments.length == 4 &&
      segments[0] == 'aircraft' &&
      segments[2] == 'intent' &&
      segments[3] == 'new') {
    return _ResolvedRoute(
      section: AppSection.aircraft,
      name: '/aircraft/${segments[1]}/intent/new',
      intentAircraftId: segments[1],
    );
  }
  final section = AppSection.fromLocation(location);
  return _ResolvedRoute(section: section, name: section.route);
}

class _ResolvedRoute {
  const _ResolvedRoute({
    required this.section,
    required this.name,
    this.aircraftMapId,
    this.intentAircraftId,
  });

  final AppSection section;
  final String name;
  final String? aircraftMapId;
  final String? intentAircraftId;
}

enum AppSection {
  overview(
    title: 'Overview',
    route: '/overview',
    icon: Icons.grid_view_outlined,
    selectedIcon: Icons.grid_view_rounded,
  ),
  readiness(
    title: 'Readiness',
    route: '/readiness',
    icon: Icons.checklist_outlined,
    selectedIcon: Icons.checklist,
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
