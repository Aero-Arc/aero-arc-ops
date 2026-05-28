import 'package:flutter/material.dart';

import '../widgets/section_page.dart';

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SectionPage(
      title: 'Events',
      subtitle: 'Browse recent events, severities, and timeline context.',
      icon: Icons.event_note,
    );
  }
}
