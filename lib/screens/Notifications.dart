import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../util.dart';

import '../providers/notification_provider.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final TextEditingController _searchController = TextEditingController();
  Set<String> _expandedRows = {};
  String? _processingDocId;

  @override
  void initState() {
    super.initState();
    // ✅ OPTIMIZATION: No need to call loadNotifications here
    // The provider already handles initialization non-blockingly
    // The page will automatically receive updates via ref.watch
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _searchNotifications(String query) {
    setState(() {});
  }

  Future<void> _markAsSeen(Map<String, dynamic> notification) async {
    final docId = notification['_id']?.toString() ?? '';
    if (docId.isEmpty || docId == 'placeholder' || _processingDocId == docId) {
      return;
    }

    setState(() {
      _processingDocId = docId;
    });

    try {
      await ref.read(liveNotificationProvider.notifier).markAsSeen(docId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully marked as seen'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error marking notification as seen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingDocId = null;
        });
      }
    }
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.red;
    if (status == 'New') return Colors.blue;
    return Colors.grey;
  }

  void _toggleExpanded(String docId) {
    setState(() {
      if (_expandedRows.contains(docId)) {
        _expandedRows.remove(docId);
      } else {
        _expandedRows.add(docId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final state = ref.watch(liveNotificationProvider);

    List<Map<String, dynamic>> filteredNotifications = state.notifications;
    if (_searchController.text.isNotEmpty) {
      filteredNotifications = Util.search(
          state.notifications, _searchController.text.toLowerCase());
    }

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Notifications',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: _searchNotifications,
            ),
          ),

          const SizedBox(height: 16),

          // Content
          Expanded(
            child: _buildContent(
                isMobile, state.isLoading, state.error, filteredNotifications),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isMobile, bool isLoading, String? errorMessage,
      List<Map<String, dynamic>> notifications) {
    // ✅ OPTIMIZATION: Show skeleton placeholders during initial load
    if (isLoading && notifications.isEmpty) {
      return _buildSkeletonLoading(isMobile);
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(errorMessage),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref
                  .read(liveNotificationProvider.notifier)
                  .loadNotifications(),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No notifications found'),
          ],
        ),
      );
    }

    return isMobile
        ? _buildMobileView(notifications)
        : _buildDesktopView(notifications);
  }

  // ✅ NEW: Skeleton loading widget for perceived performance
  Widget _buildSkeletonLoading(bool isMobile) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6, // Show 6 skeleton items
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildShimmerBox(width: 120, height: 16),
                    const Spacer(),
                    _buildShimmerBox(width: 60, height: 24, borderRadius: 12),
                  ],
                ),
                const SizedBox(height: 12),
                _buildShimmerBox(width: double.infinity, height: 14),
                const SizedBox(height: 8),
                _buildShimmerBox(width: 200, height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerBox({
    required double width,
    required double height,
    double borderRadius = 4,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  Widget _buildMobileView(List<Map<String, dynamic>> notifications) {
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(liveNotificationProvider.notifier).loadNotifications(),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          final docId = notification['_id']?.toString() ?? '';
          final isExpanded = _expandedRows.contains(docId);

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 2,
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    notification['from_name'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(notification['msg_header'] ?? 'No subject'),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildStatusChip(notification),
                          const SizedBox(width: 8),
                          Text(
                            notification['updated'] ?? '',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.orange,
                    ),
                    onPressed: () => _toggleExpanded(docId),
                  ),
                ),
                if (isExpanded) _buildExpandedContent(notification),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopView(List<Map<String, dynamic>> notifications) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 1,
      child: Column(
        children: [
          // Table Header
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                _buildHeaderCell('Name', flex: 2),
                _buildHeaderCell('Message', flex: 3),
                _buildHeaderCell('Status', flex: 1),
                _buildHeaderCell('Date Time', flex: 2),
                _buildHeaderCell('', flex: 1),
              ],
            ),
          ),

          // Table Body
          Expanded(
            child: ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final docId = notification['_id']?.toString() ?? '';
                final isExpanded = _expandedRows.contains(docId);

                return Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: InkWell(
                        onTap: () => _toggleExpanded(docId),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              _buildDataCell(
                                notification['from_name'] ?? 'Unknown',
                                flex: 2,
                              ),
                              _buildDataCell(
                                notification['msg_header'] ?? 'No subject',
                                flex: 3,
                              ),
                              _buildStatusCell(notification, flex: 1),
                              _buildDataCell(
                                notification['updated'] ?? '',
                                flex: 2,
                              ),
                              _buildExpandCell(isExpanded, flex: 1),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (isExpanded)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          border: Border(
                            bottom: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: _buildExpandedContent(notification),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildStatusCell(Map<String, dynamic> notification,
      {required int flex}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildStatusChip(notification),
      ),
    );
  }

  Widget _buildExpandCell(bool isExpanded, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Icon(
          isExpanded ? Icons.expand_less : Icons.expand_more,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildStatusChip(Map<String, dynamic> notification) {
    final status = notification['status'];
    final docId = notification['_id']?.toString() ?? '';
    final canMarkSeen = status == 'New' && docId != 'placeholder';
    final isProcessing = _processingDocId == docId;

    return InkWell(
      onTap:
          canMarkSeen && !isProcessing ? () => _markAsSeen(notification) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: _getStatusColor(status)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              status ?? 'Unknown',
              style: TextStyle(
                color: _getStatusColor(status),
                fontSize: 12,
              ),
            ),
            if (isProcessing) ...[
              const SizedBox(width: 4),
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _getStatusColor(status),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent(Map<String, dynamic> notification) {
    final status = notification['status'];
    final docId = notification['_id']?.toString() ?? '';
    final canMarkSeen = status == 'New' && docId != 'placeholder';
    final isProcessing = _processingDocId == docId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Message Detail',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          notification['msg_body'] ?? 'No content',
          style: const TextStyle(fontSize: 14),
        ),
        if (canMarkSeen) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: isProcessing ? null : () => _markAsSeen(notification),
              icon: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Mark as Seen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
