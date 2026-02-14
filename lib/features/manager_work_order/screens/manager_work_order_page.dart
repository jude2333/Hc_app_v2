import 'package:anderson_crm_flutter/features/add_work_order/add_work_order_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
// import 'package:anderson_crm_flutter/components/add_work_order.dart';
import 'package:anderson_crm_flutter/components/canceled_work_order_page.dart';
import 'package:anderson_crm_flutter/features/price_list/screens/manager_price_view_page.dart';
import 'package:anderson_crm_flutter/features/tech_engagement/screens/tech_engagement_page.dart';

import '../../theme/theme.dart';
import '../providers/manager_work_order_provider.dart';
import '../widgets/manager_mobile_view.dart';
import '../widgets/manager_desktop_view.dart';

final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

class ManagerWorkOrderPage extends ConsumerStatefulWidget {
  const ManagerWorkOrderPage({Key? key}) : super(key: key);

  @override
  ConsumerState<ManagerWorkOrderPage> createState() =>
      _ManagerWorkOrderPageState();
}

class _ManagerWorkOrderPageState extends ConsumerState<ManagerWorkOrderPage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) return;
        final provider = ref.read(managerWorkOrderProvider);
        if (provider.isInitializing) {
          provider.initialize();
        }
        final selectedDate = ref.read(managerSelectedDatePod);
        // Check if we are already watching this date to avoid killing the stream
        if (provider.currentDate != selectedDate ||
            provider.workOrders.isEmpty) {
          debugPrint(
              'ManagerWorkOrderPage: initializing stream for $selectedDate');
          provider.loadWorkOrdersByDate(selectedDate);
        } else {
          debugPrint(
              'ManagerWorkOrderPage: Stream already active for $selectedDate - SKIPPING RELOAD');
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(managerWorkOrderProvider);
    final selected = ref.watch(managerSelectedDatePod);
    final today = ref.read(managerTodayPod);

    final dateOffsets = [3, 2, 1, 0, -1, -2, -3, -4, -5];
    final dateChips = dateOffsets.asMap().entries.map((entry) {
      final idx = entry.key;
      final off = entry.value;
      final date = today.add(Duration(days: off));
      String label;
      bool isFuturePlus = idx == 0;

      if (isFuturePlus) {
        label = '6+ Days\n${DateFormat('MM-dd').format(date)}';
      } else if (off == 2) {
        label = _dateFormat.format(date);
      } else if (off == 1) {
        label = 'NEXTDAY\n${DateFormat('MM-dd').format(date)}';
      } else if (off == 0) {
        label = 'TODAY\n${DateFormat('MM-dd').format(date)}';
      } else if (off == -1) {
        label = 'YESTERDAY\n${DateFormat('MM-dd').format(date)}';
      } else {
        label = _dateFormat.format(date);
      }
      return _DateChipProps(date, label, isFuturePlus: isFuturePlus);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundSmoke,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 4,
        surfaceTintColor: AppColors.surface,
        title: Padding(
          padding: EdgeInsets.only(left: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                padding: AppPadding.badge,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppRadius.lgAll,
                ),
                child: Text(
                  'Work Orders',
                  style: AppTextStyles.badge.copyWith(fontSize: 16),
                ),
              ),
              SizedBox(width: AppSpacing.lg),
              if (provider.isConnected)
                Tooltip(
                    message: 'Connected',
                    child: Icon(Icons.cloud_done,
                        color: AppColors.success, size: AppSizes.iconSm))
              else
                Tooltip(
                    message: 'Offline',
                    child: Icon(Icons.cloud_off,
                        color: AppColors.primary, size: AppSizes.iconSm)),
              if (provider.isSyncing)
                Padding(
                    padding: EdgeInsets.only(left: AppSpacing.sm),
                    child: SizedBox(
                        width: AppSizes.iconXs,
                        height: AppSizes.iconXs,
                        child: CircularProgressIndicator(strokeWidth: 2))),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Cancelled',
            icon: const Icon(Icons.cancel_outlined, color: Colors.black87),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const CanceledWorkOrderPage())),
          ),
          IconButton(
            tooltip: 'Manage Prices',
            icon: const Icon(Icons.price_change, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ManagerPriceViewPage()),
              );
            },
          ),
          IconButton(
            tooltip: 'Tech engagement',
            icon:
                const Icon(Icons.person_search_outlined, color: Colors.black87),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const TechEngagementPage())),
          ),
          IconButton(
            tooltip: 'Add',
            icon: const Icon(Icons.add_circle_outline, color: Colors.black87),
            onPressed: () => _openAddEditPage(context, ref),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            height: 60,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding:
                  EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 8),
              itemCount: dateChips.length,
              itemBuilder: (_, idx) {
                final chip = dateChips[idx];
                final isSel = chip.date.year == selected.year &&
                    chip.date.month == selected.month &&
                    chip.date.day == selected.day;
                final isToday = chip.date.year == today.year &&
                    chip.date.month == today.month &&
                    chip.date.day == today.day;

                return Padding(
                  padding: EdgeInsets.only(right: AppSpacing.sm),
                  child: _ModernDateChip(
                    date: chip.date,
                    label: chip.label,
                    isSelected: isSel,
                    isToday: isToday,
                    onTap: () async {
                      ref.read(managerSelectedDatePod.notifier).state =
                          chip.date;
                      await provider.loadWorkOrdersByDate(chip.date,
                          fromDateOnwards: chip.isFuturePlus);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: _buildBody(context, provider),
    );
  }

  Widget _buildBody(BuildContext context, ManagerWorkOrderProvider provider) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    if (provider.isInitializing ||
        (provider.isLoading && provider.workOrders.isEmpty)) {
      return Padding(
        padding: isMobile
            ? EdgeInsets.zero
            : EdgeInsets.fromLTRB(
                AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, 0),
        child: _buildSkeletonLoading(),
      );
    }
    if (provider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: AppSizes.iconLg + 16, color: AppColors.error),
            Text('Error: ${provider.errorMessage}'),
            ElevatedButton(
              onPressed: () async {
                final selectedDate = ref.read(managerSelectedDatePod);
                await provider.loadWorkOrdersByDate(selectedDate);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (isMobile) {
      return ManagerMobileView(
        workOrders: ref.watch(managerFilteredWorkOrdersPod),
        searchQuery: ref.watch(managerSearchPod),
        onSearchChanged: (value) =>
            ref.read(managerSearchPod.notifier).state = value,
      );
    }

    return Padding(
      padding:
          EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, 0),
      child: ManagerDesktopView(
          workOrders: ref.watch(managerFilteredWorkOrdersPod)),
    );
  }

  Widget _buildSkeletonLoading() {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(bottom: AppSpacing.md),
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.tableBorder,
            borderRadius: AppRadius.mdAll,
          ),
        ),
        Expanded(
          child: Card(
            elevation: AppSizes.cardElevation,
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
            child: Column(
              children: [
                Container(
                  padding: AppPadding.tableCell,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: List.generate(
                        8,
                        (index) => Expanded(
                              child: Container(
                                margin: EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs),
                                height: 14,
                                decoration: BoxDecoration(
                                  color: AppColors.tableBorder,
                                  borderRadius: AppRadius.xsAll,
                                ),
                              ),
                            )),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: 8,
                    itemBuilder: (context, index) {
                      return Container(
                        padding: AppPadding.tableCell,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppColors.divider),
                          ),
                        ),
                        child: Row(
                          children: List.generate(
                              8,
                              (i) => Expanded(
                                    child: Container(
                                      margin: EdgeInsets.symmetric(
                                          horizontal: AppSpacing.xs),
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: AppColors.tableBorder,
                                        borderRadius: AppRadius.xsAll,
                                      ),
                                    ),
                                  )),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openAddEditPage(BuildContext context, WidgetRef ref) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
          builder: (context) => const AddWorkOrderPage(),
          fullscreenDialog: true),
    )
        .then((value) {
      // No loadWorkOrdersByDate needed — db.watch() auto-detects
      // the INSERT/UPDATE and re-emits the updated list.
      if (value == 'refresh' && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Work Order Saved'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
  }
}

class _DateChipProps {
  final DateTime date;
  final String label;
  final bool isFuturePlus;
  _DateChipProps(this.date, this.label, {this.isFuturePlus = false});
}

class _ModernDateChip extends StatelessWidget {
  final DateTime date;
  final String label;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  const _ModernDateChip({
    required this.date,
    required this.label,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lines = label.split('\n');
    final hasTitle = lines.length > 1;
    final title = hasTitle ? lines[0] : null;
    final dateText = hasTitle ? lines[1] : lines[0];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected
                ? null
                : (isToday ? AppColors.primaryLight : AppColors.surfaceAlt),
            borderRadius: BorderRadius.circular(12),
            border: isToday && !isSelected
                ? Border.all(color: AppColors.primary, width: 1.5)
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null)
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.primary,
                    letterSpacing: 0.3,
                    height: 1.2,
                  ),
                ),
              Text(
                dateText,
                style: TextStyle(
                  fontSize: hasTitle ? 12 : 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
