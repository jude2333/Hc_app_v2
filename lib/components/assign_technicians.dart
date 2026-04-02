import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/services/postgresService.dart';
import 'package:anderson_crm_flutter/features/core/util.dart';
import 'package:anderson_crm_flutter/features/manager_work_order/providers/manager_work_order_provider.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';

final techniciansProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String?>(
  (ref, search) async {
    final dbService = ref.read(postgresServiceProvider);
    return await dbService.getTechnicians(search);
  },
);

class AssignTechnicianDialog extends ConsumerStatefulWidget {
  final WorkOrder workOrder;
  final Function(String techId, String techName) onAssign;

  const AssignTechnicianDialog({
    super.key,
    required this.workOrder,
    required this.onAssign,
  });

  @override
  ConsumerState<AssignTechnicianDialog> createState() =>
      _AssignTechnicianDialogState();
}

class _AssignTechnicianDialogState
    extends ConsumerState<AssignTechnicianDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _isSearching = true;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _searchQuery == value) {
        setState(() => _isSearching = false);
        ref.invalidate(techniciansProvider);
      }
    });
  }

  List<Map<String, dynamic>> _sortTechnicians(
      List<Map<String, dynamic>> technicians) {
    final pincode = widget.workOrder.pincode;
    if (pincode.isEmpty) return technicians;

    List<Map<String, dynamic>> matchFound = [];
    List<Map<String, dynamic>> matchNotFound = [];

    for (var technician in technicians) {
      bool matched = false;
      final allocatedAreas =
          technician['allocated_areas'] as List<dynamic>? ?? [];

      for (var area in allocatedAreas) {
        if (area['pincode']?.toString() == pincode) {
          matched = true;
          break;
        }
      }

      if (matched) {
        matchFound.add(technician);
      } else {
        matchNotFound.add(technician);
      }
    }

    return [...matchFound, ...matchNotFound];
  }

  bool _validateAssignment(
      String techId, String techName, List<WorkOrder> allWorkOrders) {
    final workOrder = widget.workOrder;
    final appointmentDate = workOrder.visitDate;
    final appointmentTime = workOrder.visitTime;

    for (var wo in allWorkOrders) {
      if (wo.status.toLowerCase() == 'assigned' &&
          wo.assignedId.toString() == techId &&
          wo.visitDate.year == appointmentDate.year &&
          wo.visitDate.month == appointmentDate.month &&
          wo.visitDate.day == appointmentDate.day) {
        try {
          final currentTimeStr =
              "${DateFormat('dd-MM-yyyy').format(appointmentDate)} $appointmentTime";
          final woTimeStr =
              "${DateFormat('dd-MM-yyyy').format(wo.visitDate)} ${wo.visitTime}";

          final currentDateTime = _parseAppTime(currentTimeStr);
          final woDateTime = _parseAppTime(woTimeStr);

          if (currentDateTime != null && woDateTime != null) {
            final diffMinutes =
                woDateTime.difference(currentDateTime).inMinutes.abs();

            if (diffMinutes == 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '$techName has already got appointment at the same time.'),
                  backgroundColor: Colors.red,
                ),
              );
              return false;
            }

            if (diffMinutes == 1) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '$techName has already got appointment within $diffMinutes min from this time.'),
                  backgroundColor: Colors.red,
                ),
              );
              return false;
            }
          }
        } catch (e) {
          debugPrint('Error parsing time for validation: $e');

          if (appointmentTime == wo.visitTime) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '$techName has already got appointment at the same time.'),
                backgroundColor: Colors.red,
              ),
            );
            return false;
          }
        }
      }
    }
    return true;
  }

  DateTime? _parseAppTime(String timeStr) {
    try {
      final formats = [
        DateFormat('dd-MM-yyyy HH:mm'),
        DateFormat('dd-MM-yyyy H:mm'),
        DateFormat('dd-MM-yyyy hh:mm a'),
      ];

      for (var format in formats) {
        try {
          return format.parse(timeStr);
        } catch (_) {}
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final techniciansAsync = ref
        .watch(techniciansProvider(_searchQuery.isEmpty ? null : _searchQuery));

    final allWorkOrders = ref.watch(
      managerWONotifierProvider.select((s) => s.workOrders),
    );

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      insetPadding: isMobile
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 24)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: isMobile ? double.infinity : screenWidth * 0.5,
        height: MediaQuery.of(context).size.height * (isMobile ? 0.8 : 0.7),
        color: AppColors.surface,
        child: Column(
          children: [
            // ── Header ──
            _buildHeader(isMobile),
            // ── Search bar (separate row on mobile) ──
            if (isMobile) _buildMobileSearchBar(),
            // ── Technician List ──
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : techniciansAsync.when(
                      loading: () => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: AppColors.primary),
                            const SizedBox(height: 12),
                            Text('Loading technicians...',
                                style:
                                    TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      error: (error, stack) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 48, color: AppColors.error),
                              const SizedBox(height: 12),
                              Text('Failed to load technicians',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary)),
                              const SizedBox(height: 4),
                              Text('$error',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                  textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ),
                      data: (technicians) {
                        final sortedTechnicians = _sortTechnicians(technicians);

                        if (sortedTechnicians.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_off_outlined,
                                    size: 48, color: AppColors.textHint),
                                const SizedBox(height: 12),
                                Text('No technicians found',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: sortedTechnicians.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: AppColors.divider),
                          itemBuilder: (context, index) {
                            final tech = sortedTechnicians[index];
                            return _TechnicianListItem(
                              technician: tech,
                              isMobile: isMobile,
                              matchesPincode: _isPincodeMatch(
                                  tech, widget.workOrder.pincode),
                              onTap: () {
                                final techId = tech['_id'].toString();
                                final techName = tech['name'].toString();

                                if (!_validateAssignment(
                                    techId, techName, allWorkOrders)) {
                                  return;
                                }

                                Navigator.of(context).pop();
                                Future.microtask(() {
                                  widget.onAssign(techId, techName);
                                });
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isPincodeMatch(Map<String, dynamic> tech, String pincode) {
    if (pincode.isEmpty) return false;
    final areas = tech['allocated_areas'] as List<dynamic>? ?? [];
    return areas.any((a) => a['pincode']?.toString() == pincode);
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 10 : 14,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.engineering_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Choose Technician',
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Desktop: search inline
          if (!isMobile) ...[
            const SizedBox(width: 12),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: _buildSearchField(),
              ),
            ),
          ],
          const SizedBox(width: 4),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      color: AppColors.surfaceAlt,
      child: _buildSearchField(),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search technician...',
        hintStyle: TextStyle(fontSize: 13, color: AppColors.textHint),
        prefixIcon: Icon(Icons.search, size: 20, color: AppColors.textHint),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, size: 18, color: AppColors.textHint),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              )
            : null,
        fillColor: Colors.white,
        filled: true,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      onChanged: _onSearchChanged,
    );
  }
}

class _TechnicianListItem extends StatelessWidget {
  final Map<String, dynamic> technician;
  final VoidCallback onTap;
  final bool isMobile;
  final bool matchesPincode;

  const _TechnicianListItem({
    required this.technician,
    required this.onTap,
    required this.isMobile,
    this.matchesPincode = false,
  });

  @override
  Widget build(BuildContext context) {
    final allocatedAreas =
        technician['allocated_areas'] as List<dynamic>? ?? [];

    return InkWell(
      onTap: onTap,
      splashColor: AppColors.primaryLight,
      highlightColor: AppColors.primaryLight,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 10 : 12,
        ),
        decoration: matchesPincode
            ? BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.5),
                border: Border(
                  left: BorderSide(color: AppColors.primary, width: 3),
                ),
              )
            : null,
        child: isMobile
            ? _buildMobileLayout(allocatedAreas)
            : _buildDesktopLayout(allocatedAreas),
      ),
    );
  }

  Widget _buildDesktopLayout(List<dynamic> allocatedAreas) {
    return Row(
      children: [
        _buildAvatar(),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _buildNameSection(),
        ),
        if (matchesPincode)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: AppRadius.xsAll,
              border:
                  Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, size: 12, color: AppColors.success),
                const SizedBox(width: 2),
                Text('Area Match',
                    style: TextStyle(
                        fontSize: 10,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        Expanded(
          flex: 3,
          child: _buildAreaChips(allocatedAreas),
        ),
        Icon(Icons.chevron_right, size: 20, color: AppColors.textHint),
      ],
    );
  }

  Widget _buildMobileLayout(List<dynamic> allocatedAreas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: 10),
            Expanded(child: _buildNameSection()),
            if (matchesPincode)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: AppRadius.xsAll,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, size: 11, color: AppColors.success),
                    const SizedBox(width: 2),
                    Text('Match',
                        style: TextStyle(
                            fontSize: 9,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: AppColors.textHint),
          ],
        ),
        if (allocatedAreas.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: _buildAreaChips(allocatedAreas),
          ),
        ],
      ],
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: isMobile ? 16 : 18,
      backgroundColor: AppColors.primaryLight,
      child: Text(
        Util.getInitials(
          technician['first_name'] ?? '',
          technician['last_name'] ?? '',
        ),
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: isMobile ? 11 : 13,
        ),
      ),
    );
  }

  Widget _buildNameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          technician['name']?.toString() ?? '',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isMobile ? 13 : 14,
            color: AppColors.textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 1),
        Text(
          technician['mobile']?.toString() ?? '',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: isMobile ? 11 : 12,
          ),
        ),
      ],
    );
  }

  Widget _buildAreaChips(List<dynamic> allocatedAreas) {
    if (allocatedAreas.isEmpty) {
      return Text('No areas assigned',
          style: TextStyle(
              fontSize: 11,
              color: AppColors.textHint,
              fontStyle: FontStyle.italic));
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: allocatedAreas.map<Widget>((area) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: AppRadius.xsAll,
          ),
          child: Text(
            '${area['pincode']} ${area['area']}',
            style: TextStyle(
              fontSize: isMobile ? 9 : 10,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }
}

void showAssignTechnicianDialog(
  BuildContext context,
  WidgetRef ref,
  WorkOrder workOrder,
  Function(String techId, String techName) onAssign,
) {
  final appointmentDate = workOrder.visitDate;
  if (Util.isPassedDate(appointmentDate.toString())) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Passed work orders cannot be assigned.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  final status = workOrder.status.toLowerCase();
  if (status == 'cancelled') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cannot assign cancelled work order.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  if (status != 'assigned' && status != 'unassigned') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cannot assign work order at this stage.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  showDialog(
    context: context,
    builder: (context) => AssignTechnicianDialog(
      workOrder: workOrder,
      onAssign: onAssign,
    ),
  );
}
