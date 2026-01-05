import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/user_model.dart';
import 'allocated_areas_table.dart';
import 'user_actions.dart';

/// A single row in the users desktop table.
class UserTableRow extends ConsumerStatefulWidget {
  final User user;
  final int index;

  const UserTableRow({super.key, required this.user, required this.index});

  @override
  ConsumerState<UserTableRow> createState() => _UserTableRowState();
}

class _UserTableRowState extends ConsumerState<UserTableRow> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isEven = widget.index % 2 == 0;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: isEven ? Colors.white : Colors.grey[50],
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildDataCell(widget.user.name, flex: 3),
                _buildDataCell(widget.user.mobile, flex: 2),
                _buildDataCell(widget.user.roleName, flex: 3),
                _buildDataCell(widget.user.departmentName, flex: 2),
                _buildIdCardCell(widget.user, flex: 2),
                _buildActionsCell(widget.user, flex: 2),
                _buildExpandCell(widget.user, flex: 1),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          Container(
            color: Colors.blue[50],
            padding: const EdgeInsets.all(16),
            child: AllocatedAreasTable(areas: widget.user.allocatedAreas),
          ),
      ],
    );
  }

  Widget _buildDataCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(
          text,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildIdCardCell(User user, {required int flex}) {
    final hasIdCard = user.photoIdCard.isNotEmpty;

    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: hasIdCard
            ? OutlinedButton(
                onPressed: () => downloadIdCard(
                  context,
                  ref,
                  user.idCardLocation,
                  user.photoIdCard,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: Text(
                  user.photoIdCard,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : const Text(
                'No ID Card',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
      ),
    );
  }

  Widget _buildActionsCell(User user, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              color: Colors.blue,
              onPressed: () => editUser(context, ref, user),
              tooltip: 'Edit',
            ),
            if (isManager(ref))
              IconButton(
                icon: const Icon(Icons.delete, size: 20),
                color: Colors.red,
                onPressed: () => deleteUser(context, ref, user),
                tooltip: 'Delete',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandCell(User user, {required int flex}) {
    final hasAreas = user.allocatedAreas.isNotEmpty;

    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Center(
          child: IconButton(
            icon: Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              color: hasAreas ? Colors.orange : Colors.grey[400],
            ),
            onPressed: hasAreas
                ? () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  }
                : null,
            tooltip: hasAreas ? 'Show allocated areas' : 'No allocated areas',
          ),
        ),
      ),
    );
  }
}
