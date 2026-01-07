import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import '../tabs/daily_tab.dart';
import '../tabs/weekly_tab.dart';
import '../tabs/monthly_tab.dart';
import '../tabs/yearly_tab.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _roleName;
  String? _tenantId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserData());
  }

  Future<void> _loadUserData() async {
    final storage = ref.read(storageServiceProvider);

    if (mounted) {
      setState(() {
        _roleName = storage.getFromSession("role_name");
        _tenantId = storage.getFromSession("logged_in_tenant_id");
        _isLoading = false;
      });
    }
  }

  bool _checkTenant(String? tenantId) {
    if (tenantId == null) return false;
    const tenantsAllowed = [1, 26, 70];
    return tenantsAllowed.contains(int.tryParse(tenantId));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _SkeletonDashboard();
    }

    if (!_checkTenant(_tenantId)) {
      return _buildComingSoonScreen('Dashboard Yet To Come');
    }

    if (_roleName == 'MANAGER') {
      return _buildManagerDashboard();
    } else if (_roleName == 'TECHNICIAN') {
      return _buildComingSoonScreen('Technician Dashboard - Coming Soon');
    } else {
      return _buildComingSoonScreen('Dashboard Yet To Come');
    }
  }

  Widget _buildManagerDashboard() {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const BouncingScrollPhysics(),
              children: const [
                DailyTab(),
                WeeklyTab(),
                MonthlyTab(),
                YearlyTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade400,
            Colors.deepOrange.shade500,
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.dashboard_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Analytics & Insights',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.orange.shade700,
        unselectedLabelColor: Colors.grey.shade500,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            color: Colors.orange.shade600,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        splashFactory: InkRipple.splashFactory,
        overlayColor: WidgetStateProperty.all(
          Colors.orange.withOpacity(0.1),
        ),
        tabs: const [
          _TabItem(icon: Icons.today_rounded, label: 'Daily'),
          _TabItem(icon: Icons.view_week_rounded, label: 'Weekly'),
          _TabItem(icon: Icons.calendar_month_rounded, label: 'Monthly'),
          _TabItem(icon: Icons.calendar_today_rounded, label: 'Yearly'),
        ],
      ),
    );
  }

  Widget _buildComingSoonScreen(String message) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.construction_rounded,
                size: 48,
                color: Colors.orange.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We\'re working on something great!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TabItem({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

// Skeleton Loading Widgets
class _SkeletonDashboard extends StatefulWidget {
  const _SkeletonDashboard();

  @override
  State<_SkeletonDashboard> createState() => _SkeletonDashboardState();
}

class _SkeletonDashboardState extends State<_SkeletonDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
    _animation = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          _buildSkeletonHeader(),
          _buildSkeletonTabBar(),
          Expanded(
            child: _buildSkeletonContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 16,
      ),
      width: double.infinity,
      height: 120, // Approximate height of header
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: FadeTransition(
        opacity: _animation,
        child: Row(
          children: [
            _SkeletonBox(width: 48, height: 48, borderRadius: 12),
            const SizedBox(width: 16),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _SkeletonBox(width: 120, height: 24),
                SizedBox(height: 8),
                _SkeletonBox(width: 80, height: 16),
              ],
            ),
            const Spacer(),
            _SkeletonBox(width: 36, height: 36, borderRadius: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 0),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey, width: 0.2)),
      ),
      child: FadeTransition(
        opacity: _animation,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children:
              List.generate(4, (index) => _SkeletonBox(width: 60, height: 20)),
        ),
      ),
    );
  }

  Widget _buildSkeletonContent() {
    return FadeTransition(
      opacity: _animation,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Stat Cards Row
          Row(
            children: [
              Expanded(
                  child: _SkeletonBox(
                      width: double.infinity, height: 100, borderRadius: 12)),
              const SizedBox(width: 16),
              Expanded(
                  child: _SkeletonBox(
                      width: double.infinity, height: 100, borderRadius: 12)),
            ],
          ),
          const SizedBox(height: 16),
          // Another Stat Cards Row
          Row(
            children: [
              Expanded(
                  child: _SkeletonBox(
                      width: double.infinity, height: 100, borderRadius: 12)),
              const SizedBox(width: 16),
              Expanded(
                  child: _SkeletonBox(
                      width: double.infinity, height: 100, borderRadius: 12)),
            ],
          ),
          const SizedBox(height: 24),
          // Chart Placeholder
          _SkeletonBox(width: double.infinity, height: 250, borderRadius: 16),
          const SizedBox(height: 24),
          // List Placeholder
          _SkeletonBox(width: double.infinity, height: 60, borderRadius: 8),
          const SizedBox(height: 12),
          _SkeletonBox(width: double.infinity, height: 60, borderRadius: 8),
          const SizedBox(height: 12),
          _SkeletonBox(width: double.infinity, height: 60, borderRadius: 8),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
