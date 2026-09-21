import 'package:flutter/material.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:url_launcher/url_launcher.dart';

/// Hosted OpenStreetMap vector data, rendered locally with a dark style.
/// No credentials or Aero Arc tile hosting are required.
class OpenStreetMapBasemap extends StatefulWidget {
  const OpenStreetMapBasemap({super.key, this.loadStyle});

  static const styleUrl = 'https://tiles.openfreemap.org/styles/dark';
  final Future<vt.Style> Function()? loadStyle;

  @override
  State<OpenStreetMapBasemap> createState() => _OpenStreetMapBasemapState();
}

class _OpenStreetMapBasemapState extends State<OpenStreetMapBasemap> {
  vt.Style? _style;
  bool _failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() => _failed = false);
    try {
      final style =
          await (widget.loadStyle?.call() ??
              vt.StyleReader(uri: OpenStreetMapBasemap.styleUrl).read());
      if (!mounted || generation != _generation) {
        style.dispose();
        return;
      }
      setState(() => _style = style);
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _generation++;
    _style?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    if (style != null) {
      return RepaintBoundary(
        child: vt.VectorTileLayer(
          theme: style.theme,
          tileProviders: style.providers,
          rasterSources: style.rasterSources,
          sprites: style.sprites,
        ),
      );
    }
    // Loading or a basemap outage must never replace aircraft/mission layers.
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 52),
        child: Material(
          color: const Color(0xEE101720),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _failed
                ? TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Basemap unavailable · Retry'),
                  )
                : const Text(
                    'Loading OpenStreetMap…',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8797AB)),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Compact, always-visible attribution for OpenFreeMap's OpenMapTiles data.
class OpenStreetMapAttribution extends StatelessWidget {
  const OpenStreetMapAttribution({super.key});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomRight,
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: const Color(0xEE101720),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Wrap(
            spacing: 6,
            children: [
              for (final link in const [
                ('OpenFreeMap', 'https://openfreemap.org/'),
                ('© OpenMapTiles', 'https://openmaptiles.org/'),
                ('© OpenStreetMap', 'https://www.openstreetmap.org/copyright'),
              ])
                InkWell(
                  onTap: () => launchUrl(Uri.parse(link.$2)),
                  child: Text(
                    link.$1,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFFA3AFBE),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
