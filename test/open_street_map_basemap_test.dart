import 'dart:async';

import 'package:aero_arc_web/widgets/open_street_map_basemap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;

void main() {
  testWidgets('basemap failure and retry preserve operational overlays', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              OpenStreetMapBasemap(
                loadStyle: () async {
                  attempts++;
                  throw StateError('Provider unavailable');
                },
              ),
              const Center(child: Text('AA-07 · Flying')),
              const OpenStreetMapAttribution(),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('AA-07 · Flying'), findsOneWidget);
    expect(find.text('Basemap unavailable · Retry'), findsOneWidget);
    expect(find.text('© OpenStreetMap'), findsOneWidget);
    await tester.tap(find.text('Basemap unavailable · Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('AA-07 · Flying'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pending load can fail after leaving the map', (tester) async {
    final pending = Completer<vt.Style>();
    await tester.pumpWidget(
      MaterialApp(home: OpenStreetMapBasemap(loadStyle: () => pending.future)),
    );
    expect(find.text('Loading OpenStreetMap…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    pending.completeError(StateError('Network unavailable'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
