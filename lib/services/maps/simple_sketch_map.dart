import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class SimpleSketchMap extends StatefulWidget {
  const SimpleSketchMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.onTileErrorChanged,
  });

  final double latitude;
  final double longitude;
  final ValueChanged<bool>? onTileErrorChanged;

  @override
  State<SimpleSketchMap> createState() => _SimpleSketchMapState();
}

class _SimpleSketchMapState extends State<SimpleSketchMap> {
  late final MapController _mapController;
  bool _hasTileError = false;

  LatLng get _coordinates => LatLng(widget.latitude, widget.longitude);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(covariant SimpleSketchMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      setState(() {
        _hasTileError = false;
      });
      widget.onTileErrorChanged?.call(false);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 260,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _coordinates,
                initialZoom: 17,
                minZoom: 3,
                maxZoom: 19,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.drag |
                      InteractiveFlag.pinchZoom |
                      InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app_acc_transito',
                  errorTileCallback: (_, __, ___) {
                    if (_hasTileError || !mounted) {
                      return;
                    }
                    setState(() {
                      _hasTileError = true;
                    });
                    widget.onTileErrorChanged?.call(true);
                  },
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _coordinates,
                      width: 48,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: Icon(
                        Icons.location_pin,
                        color: colorScheme.error,
                        size: 44,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Column(
                children: [
                  _MapControlButton(
                    tooltip: 'Acercar',
                    icon: Icons.add_rounded,
                    onPressed: () => _moveToCurrentCenter(1),
                  ),
                  const SizedBox(height: 6),
                  _MapControlButton(
                    tooltip: 'Alejar',
                    icon: Icons.remove_rounded,
                    onPressed: () => _moveToCurrentCenter(-1),
                  ),
                  const SizedBox(height: 6),
                  _MapControlButton(
                    tooltip: 'Centrar marcador',
                    icon: Icons.my_location_outlined,
                    onPressed: () => _mapController.move(_coordinates, 17),
                  ),
                ],
              ),
            ),
            if (_hasTileError)
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text(
                      'No se pudieron cargar las teselas del mapa. Las coordenadas se conservan.',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _moveToCurrentCenter(double zoomDelta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom + zoomDelta);
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}
