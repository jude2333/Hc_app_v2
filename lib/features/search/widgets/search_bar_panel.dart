import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import '../providers/search_provider.dart';

class SearchBarPanel extends ConsumerStatefulWidget {
  const SearchBarPanel({super.key});

  @override
  ConsumerState<SearchBarPanel> createState() => _SearchBarPanelState();
}

class _SearchBarPanelState extends ConsumerState<SearchBarPanel> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    final searchType = state.searchType;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: isMobile
          ? _buildMobileLayout(searchType, state)
          : _buildDesktopLayout(searchType, state),
    );
  }

  Widget _buildMobileLayout(String searchType, SearchState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRadioChips(searchType),
        SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: _buildInputField(searchType, state)),
            SizedBox(width: AppSpacing.sm),
            _buildSearchButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(String searchType, SearchState state) {
    return Row(
      children: [
        _buildRadioChips(searchType),
        const Spacer(),
        Expanded(flex: 3, child: _buildInputField(searchType, state)),
        SizedBox(width: AppSpacing.sm),
        _buildSearchButton(),
      ],
    );
  }

  Widget _buildRadioChips(String selectedType) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: ['Mobile', 'Date', 'Name'].map((type) {
        final isSelected = type == selectedType;
        return Padding(
          padding: EdgeInsets.only(right: AppSpacing.sm),
          child: ChoiceChip(
            label: Text(type),
            selected: isSelected,
            onSelected: (_) {
              ref.read(searchProvider.notifier).setSearchType(type);
              _controller.clear();
            },
            selectedColor: AppColors.primaryLight,
            backgroundColor: AppColors.surface,
            labelStyle: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInputField(String searchType, SearchState state) {
    if (searchType == 'Date') {
      return _buildDateField(state.selectedDate);
    }

    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText:
            searchType == 'Mobile' ? 'Enter 10-digit mobile' : 'Enter name',
        prefixIcon: Icon(Icons.search, color: AppColors.textHint),
        border: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(color: AppColors.tableBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        filled: true,
        fillColor: AppColors.surface,
      ),
      keyboardType:
          searchType == 'Mobile' ? TextInputType.phone : TextInputType.text,
      inputFormatters: searchType == 'Mobile'
          ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ]
          : null,
      onChanged: (value) {
        ref.read(searchProvider.notifier).setQuery(value);
      },
      onSubmitted: (_) => _performSearch(),
    );
  }

  Widget _buildDateField(DateTime? selectedDate) {
    return InkWell(
      onTap: () => _showDatePicker(),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.tableBorder),
          borderRadius: AppRadius.smAll,
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                selectedDate != null
                    ? DateFormat('yyyy-MM-dd').format(selectedDate)
                    : 'Select Date',
                style: TextStyle(
                  color: selectedDate != null
                      ? AppColors.textPrimary
                      : AppColors.textHint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchButton() {
    return FloatingActionButton(
      mini: true,
      heroTag: 'searchBtn',
      backgroundColor: AppColors.primary,
      onPressed: _performSearch,
      child: const Icon(Icons.search, color: Colors.white),
    );
  }

  Future<void> _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2021, 8, 1),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      ref.read(searchProvider.notifier).setSelectedDate(picked);
    }
  }

  void _performSearch() {
    ref.read(searchProvider.notifier).search();
  }
}
