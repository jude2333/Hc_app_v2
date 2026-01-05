import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/services/postgresService.dart';
import 'package:anderson_crm_flutter/util.dart';

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
    Key? key,
    required this.workOrder,
    required this.onAssign,
  }) : super(key: key);

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

  bool _validateAssignment(String techId, String techName,
      List<Map<String, dynamic>> allWorkOrders) {
    final workOrder = widget.workOrder;
    final appointmentDate = workOrder.visitDate;
    final appointmentTime = workOrder.visitTime;

    for (var wo in allWorkOrders) {
      if (wo['status'] == 'assigned' &&
          wo['assigned_id'] == techId &&
          wo['appointment_date'] == appointmentDate) {
        final currentTime = appointmentTime;
        final woTime = wo['appointment_time'];

        if (currentTime == woTime) {
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
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final techniciansAsync = ref
        .watch(techniciansProvider(_searchQuery.isEmpty ? null : _searchQuery));

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Choose Technician',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search',
                        prefixIcon: const Icon(Icons.search),
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: techniciansAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Text('Error: $error'),
                ),
                data: (technicians) {
                  final sortedTechnicians = _sortTechnicians(technicians);

                  if (sortedTechnicians.isEmpty) {
                    return const Center(
                      child: Text('No technicians found'),
                    );
                  }

                  return ListView.builder(
                    itemCount: sortedTechnicians.length,
                    itemBuilder: (context, index) {
                      final tech = sortedTechnicians[index];
                      return _TechnicianListItem(
                        technician: tech,
                        onTap: () {
                          widget.onAssign(
                            tech['_id'].toString(),
                            tech['name'].toString(),
                          );
                          Navigator.of(context).pop();
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
}

class _TechnicianListItem extends StatelessWidget {
  final Map<String, dynamic> technician;
  final VoidCallback onTap;

  const _TechnicianListItem({
    required this.technician,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final allocatedAreas =
        technician['allocated_areas'] as List<dynamic>? ?? [];

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.orange.withOpacity(0.2),
              child: Text(
                Util.getInitials(
                  technician['first_name'] ?? '',
                  technician['last_name'] ?? '',
                ),
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    technician['name']?.toString() ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    technician['mobile']?.toString() ?? '',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: allocatedAreas.map<Widget>((area) {
                  return Chip(
                    label: Text(
                      '${area['pincode']} ${area['area']}',
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: Colors.orange.withOpacity(0.15),
                    labelStyle: const TextStyle(color: Colors.orange),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
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
  if (Util.isPassedDate(ref, appointmentDate.toString())) {
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
