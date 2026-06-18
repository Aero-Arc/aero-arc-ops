import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aero_arc_web/api/aero_arc_api.dart';

void main() {
  test('getAircraftMapView calls map endpoint and parses response', () async {
    Uri? requestedUri;
    final client = AeroArcApiClient(
      baseUri: Uri.parse('http://api.test'),
      httpClient: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          '''
          {
            "aircraft": {
              "id": "aircraft-1",
              "tail_number": "N100AA",
              "name": "Eagle 1",
              "model": "ArcRunner",
              "manufacturer": "Aero Arc",
              "status": "active",
              "acceptance_status": "accepted",
              "remote_id_status": "broadcasting"
            },
            "live_state_available": false,
            "replay_samples": [],
            "operational_volumes": [],
            "conformance_events": []
          }
          ''',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final view = await client.getAircraftMapView('aircraft-1', limit: 250);

    expect(requestedUri?.path, '/api/v1/aircraft/aircraft-1/map');
    expect(requestedUri?.queryParameters['limit'], '250');
    expect(view.aircraft.id, 'aircraft-1');
  });
}
