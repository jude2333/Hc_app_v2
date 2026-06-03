import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import '../providers/tracking_ws_provider.dart';
import '../providers/tracking_ui_providers.dart';
import '../data/tracking_models.dart';
import '../data/tracking_repository.dart';

class LiveMapView extends ConsumerStatefulWidget {
  final String token;
  final List<Map<String, dynamic>> fences;

  const LiveMapView({
    super.key,
    required this.token,
    this.fences = const [],
  });

  @override
  ConsumerState<LiveMapView> createState() => _LiveMapViewState();
}

class _LiveMapViewState extends ConsumerState<LiveMapView>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _mapReady = false;
  AnimationController? _activeAnimation;

  // Route state
  List<RoutePoint> _routePoints = [];
  bool _showRoute = false;
  bool _loadingRoute = false;
  int? _routeTechId;
  String? _routeDate;

  // Fence visibility
  bool _showFences = true;

  static const _defaultCenter = LatLng(13.0827, 80.2707);
  static const _defaultZoom = 11.0;
  static const _selectedZoom = 15.0;

  @override
  void dispose() {
    _activeAnimation?.dispose();
    _activeAnimation = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wsState = ref.watch(dashboardWsProvider);
    final selectedTech = ref.watch(selectedTechProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final statusFilter = ref.watch(statusFilterProvider);

    // Auto-center when a tech is selected (listening via ref.listen)
    ref.listen<TechnicianStatus?>(selectedTechProvider, (previous, current) {
      if (current != null &&
          current.technicianId != previous?.technicianId &&
          current.hasLocation &&
          _mapReady) {
        _animatedMove(
          LatLng(current.lastLatitude!, current.lastLongitude!),
          _selectedZoom,
        );
        if (_showRoute) _loadRoute(current.technicianId, selectedDate);
      }
    });

    // Reload route if date changed
    ref.listen<DateTime>(selectedDateProvider, (previous, current) {
      if (current != previous && _showRoute && selectedTech != null) {
        _loadRoute(selectedTech.technicianId, current);
      }
    });

    final filteredTechs =
        _filterTechnicians(wsState.technicianList, statusFilter);

    return Stack(
      children: [
        // Map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _getInitialCenter(filteredTechs),
            initialZoom: _defaultZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onMapReady: () {
              _mapReady = true;
              _fitAllTechnicians(filteredTechs);
            },
          ),
          children: [
            // Carto Voyager tiles (no retina placeholder — avoids debug warning)
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.anderson.crm',
              tileProvider: CancellableNetworkTileProvider(),
              maxZoom: 20,
            ),

            // Fence overlays (circles)
            if (_showFences) ..._buildFenceOverlays(),

            // Route polyline (color-coded by activity)
            if (_showRoute && _routePoints.length >= 2)
              PolylineLayer(
                polylines: _buildColorCodedRoute(),
              ),

            // Route start/end/stop markers
            if (_showRoute && _routePoints.length >= 2)
              MarkerLayer(markers: _buildRouteMarkers()),

            // Technician markers — hide others when viewing route
            MarkerLayer(markers: _buildMarkers(filteredTechs, selectedTech)),

            // Attribution
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('© CARTO'),
                TextSourceAttribution('© OpenStreetMap contributors'),
              ],
            ),
          ],
        ),

        // Controls (top-right) glassmorphism panel
        Positioned(
          top: AppSpacing.md,
          right: AppSpacing.md,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: AppDecorations.glassPanel,
            child: Column(
              children: [
                _MapButton(
                  icon: Icons.zoom_out_map,
                  tooltip: 'Show all technicians',
                  onPressed: () => _fitAllTechnicians(filteredTechs),
                ),
                if (selectedTech?.hasLocation == true) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _MapButton(
                    icon: Icons.my_location,
                    tooltip: 'Center on selected',
                    onPressed: () {
                      _animatedMove(
                        LatLng(
                          selectedTech!.lastLatitude!,
                          selectedTech.lastLongitude!,
                        ),
                        _selectedZoom,
                      );
                    },
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: SizedBox(
                      width: 24,
                      child: Divider(height: 1, color: AppColors.border)),
                ),
                _MapButton(
                  icon: Icons.route,
                  tooltip: 'Toggle travel route',
                  isActive: _showRoute,
                  onPressed: () {
                    setState(() => _showRoute = !_showRoute);
                    if (_showRoute && selectedTech != null) {
                      _loadRoute(selectedTech.technicianId, selectedDate);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                _MapButton(
                  icon: Icons.fence,
                  tooltip: 'Toggle geo-fences',
                  isActive: _showFences,
                  onPressed: () {
                    setState(() => _showFences = !_showFences);
                  },
                ),
              ],
            ),
          ),
        ),

        // ─── Status legend (bottom-left, always visible) ───
        Positioned(
          bottom: AppSpacing.xl,
          left: AppSpacing.md,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: AppDecorations.glassPanel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                _LegendDot(color: AppColors.trackOnline, label: 'Moving'),
                SizedBox(height: 6),
                _LegendDot(color: AppColors.trackIdle, label: 'Idle'),
                SizedBox(height: 6),
                _LegendDot(color: AppColors.trackOffline, label: 'Offline'),
              ],
            ),
          ),
        ),

        // ─── Route activity legend (bottom-center, when route active) ───
        if (_showRoute && _routePoints.length >= 2)
          Positioned(
            bottom: AppSpacing.xl,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                decoration: AppDecorations.glassPanel,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    _LegendBar(
                        color: AppColors.activityDriving, label: 'Driving'),
                    SizedBox(width: AppSpacing.lg),
                    _LegendBar(
                        color: AppColors.activityWalking, label: 'Walking'),
                    SizedBox(width: AppSpacing.lg),
                    _LegendBar(
                        color: AppColors.activityStationary,
                        label: 'Stationary'),
                  ],
                ),
              ),
            ),
          ),

        // Route loading indicator
        if (_loadingRoute)
          Positioned(
            top: 20,
            left: MediaQuery.of(context).size.width / 2 - 60,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: AppDecorations.glassPanel,
              child: const Row(
                children: [
                  SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Loading route...', style: AppTextStyles.buttonText),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<TechnicianStatus> _filterTechnicians(
      List<TechnicianStatus> techs, String? statusFilter) {
    if (statusFilter == null) return techs;
    return techs.where((t) {
      switch (statusFilter) {
        case 'online':
          return t.isOnline;
        case 'offline':
          return !t.isOnline;
        case 'idle':
          return t.isOnline && t.statusLabel == 'Idle';
        default:
          return true;
      }
    }).toList();
  }

  void _animatedMove(LatLng target, double zoom) {
    // Cancel any running animation first
    _activeAnimation?.dispose();
    _activeAnimation = null;

    if (!_mapReady || !mounted) return;

    final camera = _mapController.camera;
    final latTween =
        Tween<double>(begin: camera.center.latitude, end: target.latitude);
    final lngTween =
        Tween<double>(begin: camera.center.longitude, end: target.longitude);
    final zoomTween = Tween<double>(begin: camera.zoom, end: zoom);

    final controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _activeAnimation = controller;

    final animation =
        CurvedAnimation(parent: controller, curve: Curves.easeInOut);

    controller.addListener(() {
      if (!mounted) return;
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        if (_activeAnimation == controller) {
          _activeAnimation = null;
        }
        controller.dispose();
      }
    });

    controller.forward();
  }

  Future<void> _loadRoute(int techId, DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    if (techId == _routeTechId &&
        dateStr == _routeDate &&
        _routePoints.isNotEmpty) return;

    setState(() => _loadingRoute = true);

    try {
      final repo = TrackingRepository(token: widget.token);
      final data = await repo.getRoute(techId, dateStr);

      if (mounted) {
        setState(() {
          _routePoints = data;
          _routeTechId = techId;
          _routeDate = dateStr;
          _loadingRoute = false;
        });

        // Fit map to route if route exists
        if (_routePoints.length >= 2) {
          final bounds = LatLngBounds.fromPoints(
            _routePoints.map((p) => LatLng(p.latitude, p.longitude)).toList(),
          );
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(50),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[LiveMap] Route load error: $e');
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  void _fitAllTechnicians(List<TechnicianStatus> filteredTechs) {
    if (!_mapReady) return;

    final validTechs = filteredTechs.where((t) => t.hasLocation).toList();
    if (validTechs.isEmpty) {
      _animatedMove(_defaultCenter, _defaultZoom);
      return;
    }

    if (validTechs.length == 1) {
      _animatedMove(
        LatLng(validTechs.first.lastLatitude!, validTechs.first.lastLongitude!),
        _selectedZoom,
      );
      return;
    }

    final points = validTechs
        .map((t) => LatLng(t.lastLatitude!, t.lastLongitude!))
        .toList();

    // If viewing route, include route points in bounds
    if (_showRoute && _routePoints.isNotEmpty) {
      points.addAll(_routePoints.map((p) => LatLng(p.latitude, p.longitude)));
    }

    _mapController.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: const EdgeInsets.all(50),
    ));
  }

  LatLng _getInitialCenter(List<TechnicianStatus> filteredTechs) {
    final selectedTech = ref.read(selectedTechProvider);
    if (selectedTech?.hasLocation == true) {
      return LatLng(selectedTech!.lastLatitude!, selectedTech.lastLongitude!);
    }
    final validTechs = filteredTechs.where((t) => t.hasLocation).toList();
    if (validTechs.isNotEmpty) {
      return LatLng(
          validTechs.first.lastLatitude!, validTechs.first.lastLongitude!);
    }
    return _defaultCenter;
  }

  // ─── Route Polyline ─────────────────────────────────────────

  List<Polyline> _buildColorCodedRoute() {
    if (_routePoints.length < 2) return [];

    final polylines = <Polyline>[];
    var segmentPoints = <LatLng>[
      LatLng(_routePoints[0].latitude, _routePoints[0].longitude)
    ];
    var currentActivity = _routePoints[0].activityType ?? 'driving';

    for (int i = 1; i < _routePoints.length; i++) {
      final point = _routePoints[i];
      final activity =
          point.activityType ?? (point.isMoving ? 'driving' : 'stationary');

      segmentPoints.add(LatLng(point.latitude, point.longitude));

      // When activity changes, close current segment and start new one
      if (activity != currentActivity || i == _routePoints.length - 1) {
        polylines.add(Polyline(
          points: List.from(segmentPoints),
          color: _activityColor(currentActivity).withValues(alpha: 0.85),
          strokeWidth: 4.0,
          borderColor: _activityColor(currentActivity).withValues(alpha: 0.4),
          borderStrokeWidth: 1,
        ));

        // Start new segment (overlapping last point for continuity)
        segmentPoints = [LatLng(point.latitude, point.longitude)];
        currentActivity = activity;
      }
    }

    return polylines;
  }

  Color _activityColor(String activity) {
    switch (activity) {
      case 'driving':
        return AppColors.activityDriving;
      case 'walking':
        return AppColors.activityWalking;
      case 'stationary':
        return AppColors.activityStationary;
      default:
        return AppColors.activityDriving;
    }
  }

  List<Marker> _buildRouteMarkers() {
    final markers = <Marker>[];
    if (_routePoints.isEmpty) return markers;

    // Start marker
    final start = _routePoints.first;
    markers.add(Marker(
      point: LatLng(start.latitude, start.longitude),
      width: 60,
      height: 28,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.success,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: AppColors.success.withValues(alpha: 0.3), blurRadius: 4)
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow, size: 12, color: Colors.white),
            SizedBox(width: 2),
            Text('Start',
                style: TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ));

    // End marker
    final end = _routePoints.last;
    markers.add(Marker(
      point: LatLng(end.latitude, end.longitude),
      width: 56,
      height: 28,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: AppColors.error.withValues(alpha: 0.3), blurRadius: 4)
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stop, size: 12, color: Colors.white),
            SizedBox(width: 2),
            Text('End',
                style: TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ));

    // Stop markers
    for (int i = 1; i < _routePoints.length - 1; i++) {
      final p = _routePoints[i];
      final prevMoving = _routePoints[i - 1].isMoving;
      final currStationary = !p.isMoving;

      if (prevMoving && currStationary) {
        markers.add(Marker(
          point: LatLng(p.latitude, p.longitude),
          width: 18,
          height: 18,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.activityStationary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                    color: AppColors.activityStationary.withValues(alpha: 0.3),
                    blurRadius: 3)
              ],
            ),
            child: const Icon(Icons.pause, size: 10, color: Colors.white),
          ),
        ));
      }
    }

    return markers;
  }

  // ─── Fence Overlays ─────────────────────────────────────────

  List<Widget> _buildFenceOverlays() {
    final circles = <CircleMarker>[];

    for (final fence in widget.fences) {
      if (fence['fence_type'] == 'circle' &&
          fence['center_lat'] != null &&
          fence['center_lng'] != null &&
          fence['radius_m'] != null) {
        circles.add(CircleMarker(
          point: LatLng(
            (fence['center_lat'] as num).toDouble(),
            (fence['center_lng'] as num).toDouble(),
          ),
          radius: (fence['radius_m'] as num).toDouble(),
          useRadiusInMeter: true,
          color: AppColors.mapFenceFill,
          borderColor: AppColors.mapFenceBorder,
          borderStrokeWidth: 2,
        ));
      }
    }

    if (circles.isEmpty) return [];
    return [CircleLayer(circles: circles)];
  }

  // ─── Tech Markers ──────────────────────────────────────────

  List<Marker> _buildMarkers(
      List<TechnicianStatus> filteredTechs, TechnicianStatus? selectedTech) {
    // When route is active, only show the selected technician's marker
    final techsToShow = (_showRoute && _routePoints.isNotEmpty)
        ? filteredTechs.where((t) =>
            t.hasLocation && t.technicianId == selectedTech?.technicianId)
        : filteredTechs.where((t) => t.hasLocation);

    return techsToShow.map((tech) {
      final isSelected = selectedTech?.technicianId == tech.technicianId;
      return Marker(
        point: LatLng(tech.lastLatitude!, tech.lastLongitude!),
        width: isSelected ? 160 : 110,
        height: isSelected ? 65 : 50,
        child: GestureDetector(
          onTap: () => ref.read(selectedTechProvider.notifier).state = tech,
          child: _TechMarker(tech: tech, isSelected: isSelected),
        ),
      );
    }).toList();
  }
}

// ─── Custom Technician Marker Widget ─────────────────────────

class _TechMarker extends StatelessWidget {
  final TechnicianStatus tech;
  final bool isSelected;

  const _TechMarker({required this.tech, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    if (!tech.isOnline) {
      statusColor = AppColors.trackOffline;
    } else if (tech.statusLabel == 'Idle') {
      statusColor = AppColors.trackIdle;
    } else {
      statusColor = AppColors.trackOnline;
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Pulsing dot for selected tech
        if (isSelected && tech.isOnline)
          Positioned(
            bottom: 2,
            child: TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(seconds: 2),
              // ignore: sort_child_properties_last
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.3),
                ),
              ),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 1.0 + (value * 0.5),
                  child: Opacity(
                    opacity: 1.0 - (value * 0.5),
                    child: child,
                  ),
                );
              },
              onEnd: () {
                // To loop the animation seamlessly, this requires a slightly more complex setup
                // but this gives a nice one-time pulse on focus.
              },
            ),
          ),

        // Pin Point
        Positioned(
          bottom: 0,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),

        // Name Card
        Positioned(
          bottom: 18, // Above the pin
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Battery indicator
                if (tech.lastBattery != null) ...[
                  Icon(
                    tech.lastBattery! < 20
                        ? Icons.battery_alert
                        : Icons.battery_full,
                    size: 10,
                    color: isSelected
                        ? Colors.white70
                        : (tech.lastBattery! < 20
                            ? AppColors.error
                            : AppColors.success),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  tech.technicianName.isNotEmpty ? tech.technicianName : 'Tech',
                  style: AppTextStyles.buttonText.copyWith(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Control Button ─────────────────────────────────────────

class _MapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isActive;

  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                if (!isActive)
                  BoxShadow(
                      color: AppColors.shadowLight,
                      blurRadius: 4,
                      offset: const Offset(0, 2))
              ],
            ),
            child: Icon(icon,
                size: 20,
                color: isActive ? Colors.white : AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

// ─── Legend Widgets ──────────────────────────────────────────

/// Circular dot + label for the technician status legend.
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 3)
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

/// Colored bar + label for the route activity legend.
class _LegendBar extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendBar({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 2)
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}
