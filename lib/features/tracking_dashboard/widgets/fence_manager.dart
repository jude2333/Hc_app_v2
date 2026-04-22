import 'package:flutter/material.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import '../data/tracking_repository.dart';

/// Fence management panel for creating, editing, and deleting geo-fences.
/// Currently supports circle fences (center point + radius).
class FenceManagerPanel extends StatefulWidget {
  final String token;
  final int? tenantId;
  final List<Map<String, dynamic>> fences;
  final VoidCallback onFencesChanged;

  const FenceManagerPanel({
    super.key,
    required this.token,
    this.tenantId,
    required this.fences,
    required this.onFencesChanged,
  });

  @override
  State<FenceManagerPanel> createState() => _FenceManagerPanelState();
}

class _FenceManagerPanelState extends State<FenceManagerPanel> {
  bool _showForm = false;
  bool _saving = false;
  int? _editingId;

  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController(text: '500');

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _nameController.clear();
    _latController.clear();
    _lngController.clear();
    _radiusController.text = '500';
    _editingId = null;
    _showForm = false;
  }

  void _editFence(Map<String, dynamic> fence) {
    _editingId = fence['id'];
    _nameController.text = fence['name'] ?? '';
    _latController.text = fence['center_lat']?.toString() ?? '';
    _lngController.text = fence['center_lng']?.toString() ?? '';
    _radiusController.text = fence['radius_m']?.toString() ?? '500';
    setState(() => _showForm = true);
  }

  Future<void> _saveFence() async {
    final name = _nameController.text.trim();
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    final radius = double.tryParse(_radiusController.text.trim());

    if (name.isEmpty || lat == null || lng == null || radius == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill all fields with valid values'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final repo = TrackingRepository(token: widget.token);
      final data = {
        'name': name,
        'fence_type': 'circle',
        'center_lat': lat,
        'center_lng': lng,
        'radius_m': radius,
      };

      if (_editingId != null) {
        // Update
        await repo.updateFence(_editingId!, data);
      } else {
        // Create
        await repo.createFence(data);
      }

      _resetForm();
      widget.onFencesChanged();
    } catch (e) {
      debugPrint('[Fence] Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteFence(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Fence', style: AppTextStyles.h3),
        content: Text('Delete "$name"? This cannot be undone.', style: AppTextStyles.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = TrackingRepository(token: widget.token);
      await repo.deleteFence(id);
      widget.onFencesChanged();
    } catch (e) {
      debugPrint('[Fence] Delete error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              const Icon(Icons.fence, size: 20, color: AppColors.mapFenceBorder),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Geo-Fences (${widget.fences.length})',
                style: AppTextStyles.h3,
              ),
              const Spacer(),
              if (!_showForm)
                InkWell(
                  onTap: () => setState(() => _showForm = true),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: AppDecorations.pillBadge(AppColors.mapFenceBorder),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, size: 14, color: AppColors.mapFenceBorder),
                        const SizedBox(width: 4),
                        Text(
                          'Add Fence', 
                          style: AppTextStyles.chipText.copyWith(color: AppColors.mapFenceBorder),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Create/Edit form
        if (_showForm)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.mapFenceBorder.withValues(alpha: 0.03),
              border: Border(bottom: BorderSide(color: AppColors.mapFenceBorder.withValues(alpha: 0.2))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _editingId != null ? 'Edit Fence' : 'New Circle Fence',
                  style: AppTextStyles.metricSmall,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildTextField(
                  controller: _nameController, 
                  label: 'Name', 
                  hint: 'e.g. Chennai Office',
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _latController, 
                        label: 'Latitude', 
                        hint: '13.0827',
                        isNumber: true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _buildTextField(
                        controller: _lngController, 
                        label: 'Longitude', 
                        hint: '80.2707',
                        isNumber: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildTextField(
                  controller: _radiusController, 
                  label: 'Radius (meters)', 
                  hint: '500',
                  isNumber: true,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        _resetForm();
                        setState(() {});
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton(
                      onPressed: _saving ? null : _saveFence,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mapFenceBorder,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
                      ),
                      child: _saving
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_editingId != null ? 'Update' : 'Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Fence list
        Expanded(
          child: widget.fences.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fence, size: 64, color: AppColors.textHint.withValues(alpha: 0.5)),
                      const SizedBox(height: AppSpacing.md),
                      Text('No fences configured', style: AppTextStyles.h2.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: AppSpacing.xs),
                      Text('Add a fence to monitor zone entries/exits', style: AppTextStyles.caption),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: widget.fences.length,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final fence = widget.fences[index];
                    final isActive = fence['is_active'] == true;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                      decoration: AppDecorations.brandedCard,
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: isActive ? AppColors.mapFenceFill : AppColors.textHint.withValues(alpha: 0.1),
                          child: Icon(
                            Icons.circle_outlined,
                            size: 20,
                            color: isActive ? AppColors.mapFenceBorder : AppColors.textSecondary,
                          ),
                        ),
                        title: Text(
                          fence['name'] ?? 'Unnamed',
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${fence['fence_type']} · ${fence['radius_m']}m radius',
                          style: AppTextStyles.caption,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _editFence(fence),
                              icon: const Icon(Icons.edit, size: 18, color: AppColors.textSecondary),
                              tooltip: 'Edit Fence',
                            ),
                            IconButton(
                              onPressed: () => _deleteFence(fence['id'], fence['name'] ?? 'this fence'),
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                              tooltip: 'Delete Fence',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
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
          borderSide: const BorderSide(color: AppColors.mapFenceBorder),
        ),
      ),
    );
  }
}
