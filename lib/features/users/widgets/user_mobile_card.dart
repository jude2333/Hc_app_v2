import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/user_model.dart';
import 'allocated_areas_table.dart';
import 'user_actions.dart';

/// Mobile card view for a single user.
class UserMobileCard extends ConsumerStatefulWidget {
  final User user;

  const UserMobileCard({super.key, required this.user});

  @override
  ConsumerState<UserMobileCard> createState() => _UserMobileCardState();
}

class _UserMobileCardState extends ConsumerState<UserMobileCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: Column(
        children: [
          ListTile(
            title: Text(
              widget.user.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.phone, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(widget.user.mobile),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(child: Text(widget.user.roleName)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.business, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(child: Text(widget.user.departmentName)),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                  onPressed: () => editUser(context, ref, widget.user),
                ),
                if (isManager(ref))
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () => deleteUser(context, ref, widget.user),
                  ),
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.orange,
                  ),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
              ],
            ),
          ),
          if (widget.user.photoIdCard.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.badge, size: 16),
                label: Text(widget.user.photoIdCard),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                ),
                onPressed: () => downloadIdCard(
                  context,
                  ref,
                  widget.user.idCardLocation,
                  widget.user.photoIdCard,
                ),
              ),
            ),
          if (_isExpanded)
            AllocatedAreasTable(areas: widget.user.allocatedAreas),
        ],
      ),
    );
  }
}
