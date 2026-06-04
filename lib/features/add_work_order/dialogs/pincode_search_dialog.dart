import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/theme/theme.dart';
import '../../../../providers/pincode_provider.dart';

class PincodeSearchDialog extends ConsumerStatefulWidget {
  final TextEditingController searchController;
  final Function(String pincode, String address) onSelected;

  const PincodeSearchDialog({
    Key? key,
    required this.searchController,
    required this.onSelected,
  }) : super(key: key);

  @override
  ConsumerState<PincodeSearchDialog> createState() =>
      _PincodeSearchDialogState();
}

class _PincodeSearchDialogState extends ConsumerState<PincodeSearchDialog> {
  List<Map<String, dynamic>> pincodeResults = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final service = ref.read(pincodeServiceProvider);
      final results = await service.getInitialPincodes();
      if (mounted) {
        setState(() {
          pincodeResults = results;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading initial pincodes: $e');
      if (mounted) {
        setState(() {
          pincodeResults = [];
          isLoading = false;
        });
      }
    }
  }

  Future<void> _doSearch(String query) async {
    setState(() => isLoading = true);
    try {
      final service = ref.read(pincodeServiceProvider);
      final results = await service.searchPincodes(query);
      if (mounted) {
        setState(() {
          pincodeResults = results;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Pincode search error: $e');
      if (mounted) {
        setState(() {
          pincodeResults = [];
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surface,
      child: Container(
        width: 500,
        height: 450,
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: AppPadding.badge,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: AppRadius.smAll,
                  ),
                  child: const Text('Search Pincode',
                      style: TextStyle(
                          color: AppColors.textOnPrimary,
                          fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: isDark ? AppColors.darkTextSecondary : AppColors.textHint),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            TextField(
              controller: widget.searchController,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Enter pincode or area name...',
                hintStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textHint),
                prefixIcon: Icon(Icons.search, color: isDark ? AppColors.darkTextSecondary : AppColors.textHint),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: AppColors.primary),
                  onPressed: () => _doSearch(widget.searchController.text),
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkBackground : AppColors.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.smAll,
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: _doSearch,
              autofocus: true,
            ),
            SizedBox(height: AppSpacing.md),
            Expanded(
              child: isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary))
                  : pincodeResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_searching,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.textHint, size: 48),
                              SizedBox(height: AppSpacing.sm),
                              Text('No pincodes found',
                                  style: AppTextStyles.caption.copyWith(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: pincodeResults.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: isDark ? AppColors.darkDivider : AppColors.divider),
                          itemBuilder: (context, i) {
                            final item = pincodeResults[i];
                            final pincode = item['pincode'] ?? '';
                            final area = item['area'] ?? '';
                            final city = item['city'] ?? '';
                            final display =
                                '$area, $city ($pincode)'.toUpperCase();

                            return ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xs),
                              leading: Icon(Icons.place,
                                  color: AppColors.primary.withValues(alpha: 0.75)),
                              title: Text(display, style: AppTextStyles.body.copyWith(color: colorScheme.onSurface)),
                              onTap: () {
                                widget.onSelected(pincode, display);
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
