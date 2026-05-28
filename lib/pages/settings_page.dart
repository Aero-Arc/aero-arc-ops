import 'package:flutter/material.dart';

import '../widgets/section_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SectionPage(
      title: 'Settings',
      subtitle: 'Configure environment defaults, auth, and display preferences.',
      icon: Icons.settings,
    );
  }
}
