import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../data/tracking_models.dart';

/// Live map view using flutter_map + OpenStreetMap tiles.
/// Shows technician markers with color-coded status.
class LiveMapView extends StatefulWidget {
  final List<TechnicianStatus> technicians;
  final TechnicianStatus? selectedTech;
  final Function(TechnicianStatus) onTechSelected;

  const LiveMapView({
    super.key,
    required this.technicians,
    this.selectedTech,
    required this.onTechSelected,
  });

  @override
  State<LiveMapView> createState() => _LiveMapViewState();
}

class _LiveMapViewState extends State<LiveMapView> {
  final MapController _mapController = MapController();

  // Default center: India (approximate center of operations)
  static const _defaultCenter = LatLng(13.0827, 80.2707); // Chennai
  static const _defaultZoom = 11.0;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _getMapCenter(),
        initialZoom: _defaultZoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // OpenStreetMap tile layer
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.anderson.crm',
          maxZoom: 19,
        ),

        // Technician markers
        MarkerLayer(
          markers: _buildMarkers(),
        ),

        // Attribution
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }

  LatLng _getMapCenter() {
    // If a tech is selected and has location, center on them
    if (widget.selectedTech?.hasLocation == true) {
      return LatLng(
        widget.selectedTech!.lastLatitude!,
        widget.selectedTech!.lastLongitude!,
      );
    }

    // Otherwise, center on the average of all technician locations
    final withLocation = widget.technicians.where((t) => t.hasLocation).toList();
    if (withLocation.isEmpty) return _defaultCenter;

    final avgLat = withLocation.map((t) => t.lastLatitude!).reduce((a, b) => a + b) / withLocation.length;
    final avgLng = withLocation.map((t) => t.lastLongitude!).reduce((a, b) => a + b) / withLocation.length;
    return LatLng(avgLat, avgLng);
  }

  List<Marker> _buildMarkers() {
    return widget.technicians
        .where((tech) => tech.hasLocation)
        .map((tech) {
      final isSelected = widget.selectedTech?.technicianId == tech.technicianId;

      return Marker(
        point: LatLng(tech.lastLatitude!, tech.lastLongitude!),
        width: isSelected ? 140 : 100,
        height: isSelected ? 60 : 45,
        child: GestureDetector(
          onTap: () => widget.onTechSelected(tech),
          child: _TechMarker(tech: tech, isSelected: isSelected),
        ),
      );
    }).toList();
  }
}

/// Custom marker widget for a technician
class _TechMarker extends StatelessWidget {
  final TechnicianStatus tech;
  final bool isSelected;

  const _TechMarker({required this.tech, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final IconData statusIcon;

    if (!tech.isOnline) {
      statusColor = Colors.red;
      statusIcon = Icons.location_off;
    } else if (tech.statusLabel == 'Idle') {
      statusColor = Colors.orange;
      statusIcon = Icons.pause_circle;
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.navigation;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Name + battery label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: statusColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tech.technicianName.length > 10
                    ? '${tech.technicianName.substring(0, 10)}…'
                    : tech.technicianName,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              if (tech.lastBattery != null) ...[
                const SizedBox(width: 3),
                Icon(
                  tech.lastBattery! > 50
                      ? Icons.battery_full
                      : tech.lastBattery! > 20
                          ? Icons.battery_3_bar
                          : Icons.battery_alert,
                  size: 10,
                  color: tech.lastBattery! < 20
                      ? Colors.red
                      : isSelected
                          ? Colors.white70
                          : Colors.grey,
                ),
                Text(
                  '${tech.lastBattery}%',
                  style: TextStyle(
                    fontSize: 8,
                    color: isSelected ? Colors.white70 : Colors.grey,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 2),

        // Pin icon
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.4),
                blurRadius: 6,
                spreadRadius: isSelected ? 2 : 0,
              ),
            ],
          ),
          child: Icon(
            statusIcon,
            size: isSelected ? 16 : 12,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
