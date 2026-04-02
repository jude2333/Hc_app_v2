import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tracking_ws_provider.dart';
import '../widgets/live_map_view.dart';
import '../widgets/tech_list_panel.dart';
import '../widgets/tech_detail_panel.dart';
import '../widgets/alerts_panel.dart';
import '../widgets/filter_bar.dart';
import '../data/tracking_models.dart';

/// Main tracking dashboard page for managers.
/// Layout: Filter bar on top, map on left, panels on right.
class TrackingDashboardPage extends ConsumerStatefulWidget {
  const TrackingDashboardPage({super.key});

  @override
  ConsumerState<TrackingDashboardPage> createState() => _TrackingDashboardPageState();
}

class _TrackingDashboardPageState extends ConsumerState<TrackingDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TechnicianStatus? _selectedTech;
  DateTime _selectedDate = DateTime.now();
  String? _statusFilter; // null = all, 'online', 'offline', 'idle'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initWebSocket();
  }

  void _initWebSocket() {
    // TODO: Get token from session/storage and connect
    // For now, this will be wired up when integrating with the auth flow
    // ref.read(dashboardWsProvider.notifier).connect(token);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wsState = ref.watch(dashboardWsProvider);
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.location_on, size: 22),
            const SizedBox(width: 8),
            const Text('Technician Tracking'),
            const SizedBox(width: 12),
            // Connection indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: wsState.isConnected
                    ? Colors.green.withOpacity(0.15)
                    : Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: wsState.isConnected ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    wsState.isConnected ? 'Live' : 'Disconnected',
                    style: TextStyle(
                      fontSize: 11,
                      color: wsState.isConnected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${wsState.onlineCount}/${wsState.totalCount} online',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          // Alert badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  _tabController.animateTo(2); // Switch to alerts tab
                },
              ),
              if (wsState.unreadAlertCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${wsState.unreadAlertCount > 99 ? "99+" : wsState.unreadAlertCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          FilterBar(
            selectedDate: _selectedDate,
            statusFilter: _statusFilter,
            onDateChanged: (date) => setState(() => _selectedDate = date),
            onStatusFilterChanged: (filter) => setState(() => _statusFilter = filter),
          ),

          // Main content
          Expanded(
            child: isWide
                ? _buildWideLayout(wsState)
                : _buildNarrowLayout(wsState),
          ),
        ],
      ),
    );
  }

  /// Desktop/tablet layout: map left, panels right
  Widget _buildWideLayout(DashboardWsState wsState) {
    final filteredTechs = _filterTechnicians(wsState.technicianList);

    return Row(
      children: [
        // Map (60% width)
        Expanded(
          flex: 6,
          child: LiveMapView(
            technicians: filteredTechs,
            selectedTech: _selectedTech,
            onTechSelected: (tech) => setState(() => _selectedTech = tech),
          ),
        ),

        // Right panels (40% width)
        Expanded(
          flex: 4,
          child: Column(
            children: [
              // Tech list (top half)
              Expanded(
                child: TechListPanel(
                  technicians: filteredTechs,
                  selectedTech: _selectedTech,
                  onTechSelected: (tech) => setState(() => _selectedTech = tech),
                ),
              ),
              
              // Tabbed detail panel (bottom half)
              Expanded(
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: Theme.of(context).primaryColor,
                      unselectedLabelColor: Colors.grey,
                      tabs: [
                        const Tab(text: 'Details', icon: Icon(Icons.info_outline, size: 16)),
                        const Tab(text: 'Timeline', icon: Icon(Icons.timeline, size: 16)),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber, size: 16),
                              const SizedBox(width: 4),
                              const Text('Alerts'),
                              if (wsState.unreadAlertCount > 0) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${wsState.unreadAlertCount}',
                                    style: const TextStyle(color: Colors.white, fontSize: 9),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          TechDetailPanel(
                            technician: _selectedTech,
                            selectedDate: _selectedDate,
                          ),
                          // Timeline placeholder — will be built in Phase 5
                          Center(
                            child: Text(
                              _selectedTech != null
                                  ? 'Timeline for ${_selectedTech!.technicianName}'
                                  : 'Select a technician to view timeline',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ),
                          AlertsPanel(alerts: wsState.recentAlerts),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Mobile layout: stacked
  Widget _buildNarrowLayout(DashboardWsState wsState) {
    final filteredTechs = _filterTechnicians(wsState.technicianList);

    return Column(
      children: [
        // Map (top 60%)
        Expanded(
          flex: 6,
          child: LiveMapView(
            technicians: filteredTechs,
            selectedTech: _selectedTech,
            onTechSelected: (tech) => setState(() => _selectedTech = tech),
          ),
        ),
        // Tech list (bottom 40%)
        Expanded(
          flex: 4,
          child: TechListPanel(
            technicians: filteredTechs,
            selectedTech: _selectedTech,
            onTechSelected: (tech) => setState(() => _selectedTech = tech),
          ),
        ),
      ],
    );
  }

  List<TechnicianStatus> _filterTechnicians(List<TechnicianStatus> techs) {
    if (_statusFilter == null) return techs;
    return techs.where((t) {
      switch (_statusFilter) {
        case 'online': return t.isOnline;
        case 'offline': return !t.isOnline;
        case 'idle': return t.isOnline && t.statusLabel == 'Idle';
        default: return true;
      }
    }).toList();
  }
}
