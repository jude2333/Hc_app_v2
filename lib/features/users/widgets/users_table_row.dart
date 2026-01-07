import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/theme.dart';
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
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              bottom: BorderSide(color: AppColors.tableBorder, width: 1),
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
            color: AppColors.tableRowExpanded,
            padding: AppPadding.card,
            child: AllocatedAreasTable(areas: widget.user.allocatedAreas),
          ),
      ],
    );
  }

  Widget _buildDataCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: AppPadding.tableCell,
        child: Text(
          text,
          style: AppTextStyles.tableCell,
        ),
      ),
    );
  }

  Widget _buildIdCardCell(User user, {required int flex}) {
    final hasIdCard = user.photoIdCard.isNotEmpty;

    return Expanded(
      flex: flex,
      child: Container(
        padding: AppPadding.tableCell,
        child: hasIdCard
            ? OutlinedButton(
                onPressed: () => downloadIdCard(
                  context,
                  ref,
                  user.idCardLocation,
                  user.photoIdCard,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  side: BorderSide(color: AppColors.secondary),
                  padding: AppPadding.buttonCompact,
                ),
                child: Text(
                  user.photoIdCard,
                  style: AppTextStyles.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : Text(
                'No ID Card',
                style: AppTextStyles.caption,
              ),
      ),
    );
  }

  Widget _buildActionsCell(User user, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: AppPadding.tableCell,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.edit, size: AppSizes.iconSm),
              color: AppColors.secondary,
              onPressed: () => editUser(context, ref, user),
              tooltip: 'Edit',
            ),
            if (isManager(ref))
              IconButton(
                icon: Icon(Icons.delete, size: AppSizes.iconSm),
                color: AppColors.error,
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
        padding: AppPadding.tableCellCompact,
        child: Center(
          child: IconButton(
            icon: Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              color: hasAreas ? AppColors.primary : AppColors.textHint,
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
