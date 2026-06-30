import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import '../providers/tracking_ws_provider.dart';
import '../providers/tracking_ui_providers.dart';
import '../widgets/live_map_view.dart';
import '../widgets/tech_list_panel.dart';
import '../widgets/tech_detail_panel.dart';
import '../widgets/alerts_panel.dart';
import '../widgets/filter_bar.dart';
import '../widgets/timeline_panel.dart';
import '../widgets/fence_manager.dart';
import '../widgets/analytics_tab.dart';
import '../data/tracking_models.dart';
import '../data/tracking_repository.dart';

class TrackingDashboardPage extends ConsumerStatefulWidget {
  const TrackingDashboardPage({super.key});

  @override
  ConsumerState<TrackingDashboardPage> createState() =>
      _TrackingDashboardPageState();
}

class _TrackingDashboardPageState extends ConsumerState<TrackingDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final TrackingDashboardWsNotifier _wsNotifier;
  String _token = '';
  List<Map<String, dynamic>> _fences = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _wsNotifier = ref.read(dashboardWsProvider.notifier);
    _initWebSocket();
    _loadFences();
  }

  void _initWebSocket() {
    final storage = ref.read(storageServiceProvider);
    _token = storage.getFromSession('pg_admin');
    if (_token.isNotEmpty) {
      _wsNotifier.connect(_token);
    }
  }

  void _refreshTokenAndReconnect() {
    final storage = ref.read(storageServiceProvider);
    final freshToken = storage.getFromSession('pg_admin');
    if (freshToken.isNotEmpty) {
      _token = freshToken;
      _wsNotifier.disconnect();
      _wsNotifier.connect(_token);
    }
  }

  Future<void> _loadFences() async {
    if (_token.isEmpty) return;
    try {
      final repo = TrackingRepository(token: _token);
      final fences = await repo.getFences();
      if (mounted) setState(() => _fences = fences);
    } catch (e) {
      debugPrint('[Dashboard] Load fences error: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _wsNotifier.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wsState = ref.watch(dashboardWsProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final selectedTech = ref.watch(selectedTechProvider);
    final isWide = MediaQuery.of(context).size.width > 900;

    if (!wsState.isConnected && _token.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final storage = ref.read(storageServiceProvider);
        final freshToken = storage.getFromSession('pg_admin');
        if (freshToken != _token && freshToken.isNotEmpty) {
          _token = freshToken;
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
        title: Row(
          children: [
            const Icon(Icons.location_on, size: 20, color: AppColors.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                isWide ? 'Technician Tracking' : 'Tracking',
                style: AppTextStyles.h3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Connection indicator
            GestureDetector(
              onTap: wsState.isConnected ? null : _refreshTokenAndReconnect,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: AppDecorations.pillBadge(
                  wsState.isConnected ? AppColors.trackOnline : AppColors.error,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: wsState.isConnected
                            ? AppColors.trackOnline
                            : AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      wsState.isConnected ? 'Live' : 'Reconnect',
                      style: AppTextStyles.chipText.copyWith(
                        color: wsState.isConnected
                            ? AppColors.trackOnline
                            : AppColors.error,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${wsState.onlineCount}/${wsState.totalCount}',
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
          ],
        ),
        actions: [
          // Alert badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.textSecondary),
                onPressed: () => _tabController.animateTo(2),
              ),
              if (wsState.unreadAlertCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
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
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          const FilterBar(),

          // Main content
          Expanded(
            child: isWide
                ? _buildWideLayout(wsState, selectedTech, selectedDate)
                : _buildNarrowLayout(wsState, selectedTech, selectedDate),
          ),
        ],
      ),
    );
  }

  /// Desktop/tablet layout: map left, panels right
  Widget _buildWideLayout(DashboardWsState wsState,
      TechnicianStatus? selectedTech, DateTime selectedDate) {
    return Row(
      children: [
        // Map (60% width)
        Expanded(
          flex: 6,
          child: LiveMapView(
            token: _token,
            fences: _fences,
          ),
        ),

        // Right panels (40% width)
        Expanded(
          flex: 4,
          child: Container(
            color: AppColors.surfaceAlt,
            child: Column(
              children: [
                // Tech list (top portion)
                const Expanded(
                  flex: 4,
                  child: TechListPanel(),
                ),

                const Divider(height: 1, color: AppColors.border),

                // Tabbed detail panel (bottom portion)
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      Container(
                        color: AppColors.surface,
                        child: TabBar(
                          controller: _tabController,
                          labelColor: AppColors.primary,
                          unselectedLabelColor: AppColors.textSecondary,
                          indicatorColor: AppColors.primary,
                          indicatorWeight: 3,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          labelStyle:
                              AppTextStyles.buttonText.copyWith(fontSize: 13),
                          tabs: [
                            const Tab(
                                text: 'Details',
                                icon: Icon(Icons.info_outline, size: 18)),
                            const Tab(
                                text: 'Timeline',
                                icon: Icon(Icons.timeline, size: 18)),
                            Tab(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.warning_amber, size: 18),
                                  const SizedBox(width: 4),
                                  const Text('Alerts'),
                                  if (wsState.unreadAlertCount > 0) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.error,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${wsState.unreadAlertCount}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const Tab(
                                text: 'Fences',
                                icon: Icon(Icons.fence, size: 18)),
                            const Tab(
                                text: 'Analytics',
                                icon: Icon(Icons.analytics_outlined, size: 18)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Details
                            TechDetailPanel(
                              token: _token,
                            ),
                            // Timeline
                            TimelinePanel(
                              technician: selectedTech,
                              selectedDate: selectedDate,
                              token: _token,
                            ),
                            // Alerts
                            AlertsPanel(alerts: wsState.recentAlerts),
                            // Fences
                            FenceManagerPanel(
                              token: _token,
                              fences: _fences,
                              onFencesChanged: _loadFences,
                            ),
                            // Analytics
                            AnalyticsTab(
                              token: _token,
                              selectedDate: selectedDate,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Mobile layout: stacked vertically — map, tech list, then tabbed panels
  Widget _buildNarrowLayout(DashboardWsState wsState,
      TechnicianStatus? selectedTech, DateTime selectedDate) {
    return Column(
      children: [
        // Map (top 35%)
        Expanded(
          flex: 35,
          child: LiveMapView(
            token: _token,
            fences: _fences,
          ),
        ),
        // Tech list (25%)
        const Expanded(
          flex: 25,
          child: TechListPanel(),
        ),

        const Divider(height: 1, color: AppColors.border),

        // Tabbed detail panels (bottom 40%)
        Expanded(
          flex: 40,
          child: Column(
            children: [
              Container(
                color: AppColors.surface,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelStyle: AppTextStyles.buttonText.copyWith(fontSize: 12),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                  tabs: [
                    const Tab(
                        text: 'Details',
                        icon: Icon(Icons.info_outline, size: 16)),
                    const Tab(
                        text: 'Timeline', icon: Icon(Icons.timeline, size: 16)),
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${wsState.unreadAlertCount}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Tab(
                        text: 'Fences', icon: Icon(Icons.fence, size: 16)),
                    const Tab(
                        text: 'Analytics',
                        icon: Icon(Icons.analytics_outlined, size: 16)),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    TechDetailPanel(token: _token),
                    TimelinePanel(
                      technician: selectedTech,
                      selectedDate: selectedDate,
                      token: _token,
                    ),
                    AlertsPanel(alerts: wsState.recentAlerts),
                    FenceManagerPanel(
                      token: _token,
                      fences: _fences,
                      onFencesChanged: _loadFences,
                    ),
                    AnalyticsTab(
                      token: _token,
                      selectedDate: selectedDate,
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
}
