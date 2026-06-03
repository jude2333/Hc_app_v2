import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import '../providers/tracking_ws_provider.dart';
import '../providers/tracking_ui_providers.dart';
import '../data/tracking_repository.dart';

class TechDetailPanel extends ConsumerStatefulWidget {
  final String token;

  const TechDetailPanel({
    super.key,
    required this.token,
  });

  @override
  ConsumerState<TechDetailPanel> createState() => _TechDetailPanelState();
}

class _TechDetailPanelState extends ConsumerState<TechDetailPanel> {
  static final Map<String, String> _geocodeCache = {};

  static final Set<String> _geocodeFailedKeys = {};

  String? _currentAddress;
  bool _loadingAddress = false;
  String? _activeGeocodeKey;

  Future<void> _reverseGeocode(double lat, double lng) async {
    final cacheKey = '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';

    if (cacheKey == _activeGeocodeKey && _currentAddress != null) return;

    if (_geocodeFailedKeys.contains(cacheKey)) {
      if (mounted && _activeGeocodeKey != cacheKey) {
        setState(() {
          _activeGeocodeKey = cacheKey;
          _currentAddress = null;
          _loadingAddress = false;
        });
      }
      return;
    }

    if (_geocodeCache.containsKey(cacheKey)) {
      if (mounted) {
        setState(() {
          _currentAddress = _geocodeCache[cacheKey];
          _activeGeocodeKey = cacheKey;
          _loadingAddress = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loadingAddress = true;
        _activeGeocodeKey = cacheKey;
      });
    }

    try {
      final repo = TrackingRepository(token: widget.token);
      final address = await repo.reverseGeocode(lat, lng);

      if (address != null && address.isNotEmpty) {
        _geocodeCache[cacheKey] = address;
        if (mounted) {
          setState(() {
            _currentAddress = address;
            _loadingAddress = false;
          });
        }
      } else {
        _geocodeFailedKeys.add(cacheKey);
        if (mounted) {
          setState(() {
            _currentAddress = null;
            _loadingAddress = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[Geocode] Error: $e');
      _geocodeFailedKeys.add(cacheKey);
      if (mounted) {
        setState(() {
          _currentAddress = null;
          _loadingAddress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wsState = ref.watch(dashboardWsProvider);
    final selectedTechId = ref.watch(selectedTechProvider)?.technicianId;
    final tech =
        selectedTechId != null ? wsState.technicians[selectedTechId] : null;

    if (tech != null && tech.hasLocation) {
      final newKey =
          '${tech.lastLatitude!.toStringAsFixed(3)},${tech.lastLongitude!.toStringAsFixed(3)}';
      if (newKey != _activeGeocodeKey ||
          (_currentAddress == null &&
              !_loadingAddress &&
              !_geocodeFailedKeys.contains(newKey))) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _reverseGeocode(tech.lastLatitude!, tech.lastLongitude!);
        });
      }
    }

    if (tech == null || (selectedTechId != null && !tech.hasLocation)) {
      if (_currentAddress != null || _loadingAddress) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _currentAddress = null;
              _loadingAddress = false;
              _activeGeocodeKey = null;
            });
          }
        });
      }
    }

    if (tech == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline, size: 40, color: AppColors.textHint),
            const SizedBox(height: AppSpacing.sm),
            const Text('Select a technician to view details',
                style: AppTextStyles.caption),
          ],
        ),
      );
    }

    Color statusColor;
    if (!tech.isOnline) {
      statusColor = AppColors.trackOffline;
    } else if (tech.statusLabel == 'Idle') {
      statusColor = AppColors.trackIdle;
    } else {
      statusColor = AppColors.trackOnline;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: statusColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: CircleAvatar(
                  backgroundColor: statusColor,
                  radius: 20,
                  child: Text(
                    tech.technicianName.isNotEmpty
                        ? tech.technicianName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tech.technicianName.isNotEmpty
                          ? tech.technicianName
                          : 'Tech #${tech.technicianId}',
                      style: AppTextStyles.h3,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: statusColor, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text(
                          tech.statusLabel,
                          style: AppTextStyles.caption.copyWith(
                              color: statusColor, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _StatCard(
                icon: Icons.route,
                label: 'Distance',
                value: '${tech.todayDistance.toStringAsFixed(1)} km',
                color: AppColors.primary,
              ),
              _StatCard(
                icon: Icons.speed,
                label: 'Speed',
                value: '${tech.speedKmh.toStringAsFixed(1)} km/h',
                color: AppColors.activityStationary,
              ),
              _StatCard(
                icon: Icons.battery_std,
                label: 'Battery',
                value: tech.lastBattery != null ? '${tech.lastBattery}%' : '--',
                color: (tech.lastBattery ?? 100) < 20
                    ? AppColors.error
                    : AppColors.success,
              ),
              _StatCard(
                icon: Icons.pin_drop,
                label: 'Pings',
                value: '${tech.todayPings}',
                color: Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (tech.hasLocation) ...[
            _buildAddressRow(),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.gps_fixed, size: 12, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  Text(
                    '${tech.lastLatitude!.toStringAsFixed(5)}, ${tech.lastLongitude!.toStringAsFixed(5)}',
                    style: AppTextStyles.caption.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
            if (tech.lastAccuracy != null)
              _InfoRow(Icons.radar, 'Accuracy',
                  '±${tech.lastAccuracy!.toStringAsFixed(1)} meters'),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.location_off,
                      size: 16, color: AppColors.trackOffline),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'No location data yet',
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
          if (tech.lastSeenAt != null)
            _InfoRow(
                Icons.access_time,
                'Last seen',
                DateFormat('hh:mm a, MMM d')
                    .format(tech.lastSeenAt!.toLocal())),
          if (tech.currentWorkOrder != null)
            _InfoRow(Icons.work, 'Current WO', tech.currentWorkOrder!),
          if (tech.lastActivity != null)
            _InfoRow(Icons.directions_walk, 'Activity', tech.lastActivity!),
        ],
      ),
    );
  }

  Widget _buildAddressRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on, size: 16, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _loadingAddress
                ? Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: AppColors.textHint),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Finding location...',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textHint)),
                    ],
                  )
                : Text(
                    _currentAddress ?? 'Resolving address...',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      color: _currentAddress != null
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.of(context).size.width / 2) - 30,
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 160),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: AppTextStyles.chipText.copyWith(color: color)),
                Text(label,
                    style: AppTextStyles.caption.copyWith(fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Text('$label: ', style: AppTextStyles.caption),
          Expanded(
            child: Text(value,
                style:
                    AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
