import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/services/app_update_service.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import '../tabs/daily_tab.dart';
import '../tabs/weekly_tab.dart';
import '../tabs/monthly_tab.dart';
import '../tabs/yearly_tab.dart';
import '../tabs/tech_daily_tab.dart';
import '../tabs/tech_weekly_tab.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  String? _roleName;
  String? _tenantId;
  bool _isLoading = true;

  // Web-only: APK download info
  ApkDownloadInfo? _apkDownloadInfo;
  bool _showDownloadBanner = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
      if (kIsWeb) _fetchApkDownloadInfo();
    });
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

  /// Ensures the TabController length matches the current role.
  /// Self-heals on hot reload, navigation reuse, and login/logout flows.
  void _ensureTabController() {
    final required = _roleName == 'TECHNICIAN' ? 2 : 4;
    if (_tabController == null || _tabController!.length != required) {
      _tabController?.dispose();
      _tabController = TabController(length: required, vsync: this);
    }
  }

  Future<void> _fetchApkDownloadInfo() async {
    final info = await AppUpdateService.getApkDownloadInfo();
    if (info != null && mounted) {
      setState(() => _apkDownloadInfo = info);
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

    // Ensure controller matches current role before rendering tabs
    _ensureTabController();

    if (!_checkTenant(_tenantId)) {
      return _buildComingSoonScreen('Dashboard Yet To Come');
    }

    if (_roleName == 'MANAGER' || _roleName == 'ADMIN') {
      return _buildManagerDashboard();
    } else if (_roleName == 'TECHNICIAN') {
      return _buildTechnicianDashboard();
    } else {
      return _buildComingSoonScreen('Dashboard Yet To Come');
    }
  }

  Widget _buildManagerDashboard() {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(),
          if (kIsWeb && _apkDownloadInfo != null && _showDownloadBanner)
            _buildDownloadBanner(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController!,
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

  Widget _buildTechnicianDashboard() {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(),
          if (kIsWeb && _apkDownloadInfo != null && _showDownloadBanner)
            _buildDownloadBanner(),
          _buildTechTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController!,
              physics: const BouncingScrollPhysics(),
              children: const [
                TechDailyTab(),
                TechWeeklyTab(),
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
        top: MediaQuery.of(context).padding.top + AppSpacing.md,
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        bottom: AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.gradientStart, AppColors.primaryDark],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.textOnPrimary.withValues(alpha: 0.2),
              borderRadius: AppRadius.xlAll,
            ),
            child: const Icon(
              Icons.dashboard_rounded,
              color: AppColors.textOnPrimary,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard',
                style: TextStyle(
                  color: AppColors.textOnPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Analytics & Insights',
                style: TextStyle(
                  color: AppColors.textOnPrimary.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.textOnPrimary.withValues(alpha: 0.2),
              borderRadius: AppRadius.lgAll,
            ),
            child: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textOnPrimary,
              size: AppSizes.iconSm,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController!,
        labelColor: AppColors.gradientStart,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        indicator: UnderlineTabIndicator(
          borderSide: const BorderSide(
            color: AppColors.gradientStart,
            width: 3,
          ),
          borderRadius: AppRadius.xxsAll,
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        splashFactory: InkRipple.splashFactory,
        overlayColor: WidgetStateProperty.all(
          AppColors.primary.withValues(alpha: 0.1),
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

  Widget _buildTechTabBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController!,
        labelColor: AppColors.gradientStart,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        indicator: UnderlineTabIndicator(
          borderSide: const BorderSide(
            color: AppColors.gradientStart,
            width: 3,
          ),
          borderRadius: AppRadius.xxsAll,
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        splashFactory: InkRipple.splashFactory,
        overlayColor: WidgetStateProperty.all(
          AppColors.primary.withValues(alpha: 0.1),
        ),
        tabs: const [
          _TabItem(icon: Icons.today_rounded, label: 'Today'),
          _TabItem(icon: Icons.view_week_rounded, label: '7-Day'),
        ],
      ),
    );
  }

  Widget _buildComingSoonScreen(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.xxxl + AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.construction_rounded,
                  size: 48,
                  color: AppColors.gradientStart,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                message,
                style: AppTextStyles.h3.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'We\'re working on something great!',
                style: AppTextStyles.caption.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              if (kIsWeb && _apkDownloadInfo != null) ...[
                const SizedBox(height: AppSpacing.xxxl + AppSpacing.sm),
                _buildDownloadCard(),
              ],
              const SizedBox(height: AppSpacing.xxxl + AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  // ── Web-only: Download banner for manager/admin dashboard ──
  Widget _buildDownloadBanner() {
    final info = _apkDownloadInfo!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.andersonBlue.withValues(alpha: 0.08),
            AppColors.andersonBlue.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: AppRadius.xlAll,
        border: Border.all(
          color: AppColors.andersonBlue.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.andersonBlue.withValues(alpha: 0.1),
              borderRadius: AppRadius.mdAll,
            ),
            child: const Icon(
              Icons.phone_android_rounded,
              color: AppColors.andersonBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Download Anderson CRM for Android',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Get the latest mobile experience • v${info.version}',
                  style: AppTextStyles.caption.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            height: 34,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.download_rounded, size: AppSizes.iconXs),
              label: Text(
                'Download',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOnPrimary,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.andersonBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.mdAll,
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              ),
              onPressed: () => _launchApkDownload(info.apkUrl),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          InkWell(
            borderRadius: AppRadius.roundAll,
            onTap: () => setState(() => _showDownloadBanner = false),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Web-only: Download card for coming-soon screens ──
  Widget _buildDownloadCard() {
    final info = _apkDownloadInfo!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.andersonBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_android_rounded,
              size: AppSizes.iconLg,
              color: AppColors.andersonBlue,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Download Mobile App',
            style: AppTextStyles.h3.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.ssm),
          Text(
            'Get the latest Android app (v${info.version})',
            style: AppTextStyles.caption.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          if (info.releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: AppPadding.md,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkInfoBackground : AppColors.infoBackground,
                borderRadius: AppRadius.lgAll,
                border: Border.all(
                  color: isDark ? AppColors.darkInfoBorder : AppColors.infoBorder,
                ),
              ),
              child: Text(
                info.releaseNotes,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark ? AppColors.darkInfoText : AppColors.infoText,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(
                'Download Anderson CRM APK',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOnPrimary,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.andersonBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.lgAll,
                ),
                elevation: 0,
              ),
              onPressed: () => _launchApkDownload(info.apkUrl),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchApkDownload(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('Could not open download link. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
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
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkBorder
              : AppColors.border,
        )),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 0),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.border,
          width: 0.2,
        )),
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
          _SkeletonBox(width: double.infinity, height: 250, borderRadius: 16),
          const SizedBox(height: 24),
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
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkBorder
            : AppColors.border,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
