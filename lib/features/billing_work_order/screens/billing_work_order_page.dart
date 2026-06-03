import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import '../providers/billing_work_order_provider.dart';
import '../widgets/billing_desktop_table.dart';
import '../widgets/billing_mobile_list.dart';
import '../widgets/bill_dialog.dart';

class BillingWorkOrderPage extends ConsumerStatefulWidget {
  const BillingWorkOrderPage({super.key});

  @override
  ConsumerState<BillingWorkOrderPage> createState() =>
      _BillingWorkOrderPageState();
}

class _BillingWorkOrderPageState extends ConsumerState<BillingWorkOrderPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(billingWorkOrderProvider.notifier).initialize();
    });

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 0) {
          ref.read(billingWorkOrderProvider.notifier).loadUnbilled();
        } else {
          ref.read(billingWorkOrderProvider.notifier).loadBilled();
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInitializing = ref.watch(
      billingWorkOrderProvider.select((s) => s.isInitializing),
    );
    final isLoading = ref.watch(
      billingWorkOrderProvider.select((s) => s.isLoading),
    );
    final errorMessage = ref.watch(
      billingWorkOrderProvider.select((s) => s.errorMessage),
    );
    final orders = ref.watch(
      billingWorkOrderProvider.select((s) => s.orders),
    );
    final selectedTab = ref.watch(
      billingWorkOrderProvider.select((s) => s.selectedTab),
    );
    final isInitialSyncPending =
        ref.watch(billingSyncStatusProvider).whenOrNull(
              data: (status) {
                return status.hasSynced == false;
              },
            ) ??
            false;

    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        surfaceTintColor: Colors.white,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'Billing Work Orders',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.orange,
          tabs: const [
            Tab(
              icon: Icon(Icons.pending_actions),
              text: 'Unbilled',
            ),
            Tab(
              icon: Icon(Icons.check_circle_outline),
              text: 'Billed',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabContent(
            isInitializing: isInitializing,
            isLoading: isLoading,
            isInitialSyncPending: isInitialSyncPending,
            errorMessage: errorMessage,
            orders: orders,
            selectedTab: selectedTab,
            isDesktop: isDesktop,
          ),
          _buildTabContent(
            isInitializing: isInitializing,
            isLoading: isLoading,
            isInitialSyncPending: isInitialSyncPending,
            errorMessage: errorMessage,
            orders: orders,
            selectedTab: selectedTab,
            isDesktop: isDesktop,
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent({
    required bool isInitializing,
    required bool isLoading,
    required bool isInitialSyncPending,
    required String? errorMessage,
    required List<WorkOrder> orders,
    required String selectedTab,
    required bool isDesktop,
  }) {
    if (isInitializing ||
        ((isLoading || isInitialSyncPending) && orders.isEmpty)) {
      return _buildSkeletonLoading();
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $errorMessage'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(billingWorkOrderProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selectedTab == 'unbilled'
                  ? Icons.pending_actions
                  : Icons.check_circle_outline,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              selectedTab == 'unbilled'
                  ? 'No unbilled orders'
                  : 'No billed orders',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (isDesktop) {
      return BillingDesktopTable(
        orders: orders,
        onBill: _showBillDialog,
        onSend: _sendOrder,
        showBillAction: selectedTab == 'unbilled',
      );
    } else {
      return BillingMobileList(
        orders: orders,
        onBill: _showBillDialog,
        onSend: _sendOrder,
        showBillAction: selectedTab == 'unbilled',
      );
    }
  }

  void _showBillDialog(WorkOrder order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BillDialog(
        workOrder: order,
        onSubmit: (billNumber, labNumber) async {
          final result =
              await ref.read(billingWorkOrderProvider.notifier).registerBill(
                    workOrder: order,
                    billNumber: billNumber,
                    labNumber: labNumber,
                  );

          if (mounted) {
            Navigator.of(ctx).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result == 'OK' ? 'Billed successfully' : result),
                backgroundColor: result == 'OK' ? Colors.green : Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _sendOrder(WorkOrder order) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sending to lab system...'),
        duration: Duration(seconds: 2),
      ),
    );

    final result =
        await ref.read(billingWorkOrderProvider.notifier).sendOrder(order);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result == 'OK' ? 'Sent successfully' : result),
          backgroundColor: result == 'OK' ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Widget _buildSkeletonLoading() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        Expanded(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            elevation: 2,
            color: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: List.generate(
                      6,
                      (index) => Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: 8,
                    itemBuilder: (context, index) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          children: List.generate(
                            6,
                            (i) => Expanded(
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
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
}
