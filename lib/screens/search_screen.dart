import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'work_order_page.dart'; // reusable desktop view
import '../services/postgresService.dart';
import 'package:anderson_crm_flutter/screens/work_order_page.dart'
    show DesktopTable;

/* ----------  providers  ---------- */
final searchTypePod = StateProvider<String>((_) => 'Mobile');
final searchQueryPod = StateProvider<String>((_) => '');
final selectedDatePod = StateProvider<DateTime?>((_) => null);
final sortByPod = StateProvider<String>((_) => 'Name');
final searchResultsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async {
    final type = ref.watch(searchTypePod);
    final q = ref.watch(searchQueryPod);
    final date = ref.watch(selectedDatePod);
    final svc = ref.read(postgresServiceProvider);
    final sort = ref.watch(sortByPod);

    if (q.isEmpty && date == null) return [];

    List<Map<String, dynamic>> rows = [];

    try {
      switch (type) {
        case 'Mobile':
          if (q.length != 10) {
            return [];
          }
          try {
            final mobile = int.tryParse(q);
            if (mobile == null ||
                mobile <= 999999999 ||
                mobile >= 10000000000) {
              return [];
            }
          } catch (e) {
            return [];
          }
          rows = await svc.searchPatients(q, 'Mobile');
          // Apply mobile-specific sorting (like Vue.js)
          rows.sort((a, b) {
            try {
              final dateA = _parseAppointmentDate(a['appointment_date'] ?? '');
              final dateB = _parseAppointmentDate(b['appointment_date'] ?? '');
              return dateB.compareTo(dateA); // Descending order (newest first)
            } catch (e) {
              return 0;
            }
          });
          break;
        case 'Date':
          if (date == null) return [];
          rows = await svc.searchPatients(
              DateFormat('yyyy-MM-dd').format(date), 'Date');
          break;
        case 'Name':
          if (q.isEmpty) return [];
          rows = await svc.searchPatients(q, 'Name');
          debugPrint('Name search returned ${rows.length} results');
          if (rows.isNotEmpty) {
            debugPrint('First row valid: ${rows.first['name'] != null}');
          }
          break;
        default:
          rows = [];
      }

      // Apply user-selected sorting
      _sortList(rows, sort);

      return rows;
    } catch (e) {
      debugPrint('Search provider error: $e');
      return [];
    }
  },
);

DateTime _parseAppointmentDate(String dateStr) {
  try {
    // Handle "DD-MM-YYYY" format from work orders
    final parts = dateStr.split('-');
    if (parts.length == 3) {
      return DateTime(
        int.parse(parts[2]), // year
        int.parse(parts[1]), // month
        int.parse(parts[0]), // day
      );
    }
  } catch (e) {
    debugPrint('Error parsing appointment date: $dateStr, error: $e');
  }
  return DateTime(1970);
}

// void _showSnackbar(WidgetRef ref, String message) {
//   // You can implement snackbar logic here or use your existing approach
//   debugPrint('Snackbar: $message');
// }

void _sortList(List<Map<String, dynamic>> list, String key) {
  switch (key) {
    case 'Name':
      list.sort((a, b) =>
          (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
      break;
    case 'Mobile':
      list.sort((a, b) => (a['mobile'] ?? '')
          .toString()
          .compareTo((b['mobile'] ?? '').toString()));
      break;
    case 'Date':
      list.sort((a, b) => (a['appointment_date'] ?? '')
          .toString()
          .compareTo((b['appointment_date'] ?? '').toString()));
      break;
    case 'Time':
      list.sort((a, b) => (a['sort_time'] ?? 0).compareTo(b['sort_time'] ?? 0));
      break;
    case 'Tech. Status':
      list.sort((a, b) => (a['status'] ?? '')
          .toString()
          .compareTo((b['status'] ?? '').toString()));
      break;
    case 'Server Status':
      list.sort((a, b) => (a['server_status'] ?? '')
          .toString()
          .compareTo((b['server_status'] ?? '').toString()));
      break;
  }
}

/* ----------  search page  ---------- */
class SearchScreen2 extends ConsumerWidget {
  const SearchScreen2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(searchResultsProvider);
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          _buildHeader(context, ref),
          _buildSearchBar(context, ref),
          _buildSortPanel(context, ref),
          const SizedBox(height: 16),
          /*  reuse the SAME reactive table we have  */
          Expanded(
            child: asyncList.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (rows) => rows.isEmpty
                  ? _buildEmpty()
                  : isMobile
                      ? DesktopTable(rows: rows)
                      : DesktopTable(rows: rows), // existing widget
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Row(
        children: [
          Chip(
            label: Text(
              'Search HC Patients',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            backgroundColor: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, WidgetRef ref) {
    final type = ref.watch(searchTypePod);
    final query = ref.watch(searchQueryPod);
    final date = ref.watch(selectedDatePod);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          /*  radio chips  */
          Row(
            children: ['Mobile', 'Date', 'Name']
                .map((t) => _RadioChip(t, type, ref))
                .toList(),
          ),
          const Spacer(),
          /*  input field  */
          Expanded(
            flex: 4,
            child: type == 'Date'
                ? _DateField(date, ref)
                : TextField(
                    controller: TextEditingController(text: query),
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.orange),
                      ),
                    ),
                    keyboardType: type == 'Mobile'
                        ? TextInputType.phone
                        : TextInputType.text,
                    inputFormatters: type == 'Mobile'
                        ? [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ]
                        : null,
                    onChanged: (v) =>
                        ref.read(searchQueryPod.notifier).state = v,
                    onSubmitted: (_) => _triggerSearch(ref),
                  ),
          ),
          const SizedBox(width: 8),
          /*  search button  */
          FloatingActionButton(
            mini: true,
            onPressed: () => _triggerSearch(ref),
            backgroundColor: Colors.orange,
            child: const Icon(Icons.search, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _RadioChip(String value, String group, WidgetRef ref) {
    final isSel = value == group;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(value),
        selected: isSel,
        onSelected: (_) {
          ref.read(searchTypePod.notifier).state = value;
          ref.read(searchQueryPod.notifier).state = '';
          ref.read(selectedDatePod.notifier).state = null;
        },
        selectedColor: Colors.orange.shade100,
        backgroundColor: Colors.white,
      ),
    );
  }

  Widget _DateField(DateTime? date, WidgetRef ref) {
    final ctrl = TextEditingController(
        text: date == null ? '' : DateFormat('yyyy-MM-dd').format(date));
    return TextField(
      controller: ctrl,
      readOnly: true,
      decoration: const InputDecoration(
        labelText: 'Date Search',
        border: OutlineInputBorder(),
        suffixIcon: Icon(Icons.calendar_today, color: Colors.orange),
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: ref.context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2021, 8, 1),
          lastDate: DateTime.now(),
          builder: (_, child) => Theme(
            data: Theme.of(ref.context).copyWith(
              colorScheme: const ColorScheme.light(primary: Colors.orange),
            ),
            child: child!,
          ),
        );
        if (picked != null) {
          ref.read(selectedDatePod.notifier).state = picked;
          _triggerSearch(ref);
        }
      },
    );
  }

  Widget _buildSortPanel(BuildContext context, WidgetRef ref) {
    final isExpanded = ref.watch(sortExpandedPod);
    final selected = ref.watch(sortByPod);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          /*  header  */
          InkWell(
            onTap: () => ref.read(sortExpandedPod.notifier).state = !isExpanded,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Sort by',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          /*  options  */
          if (isExpanded)
            ...[
              'Name',
              'Mobile',
              'Date',
              'Time',
              'Tech. Status',
              'Server Status'
            ].map((k) => _SortTile(k, selected, ref)).toList(),
        ],
      ),
    );
  }

  Widget _SortTile(String key, String group, WidgetRef ref) {
    final isSel = key == group;
    return InkWell(
      onTap: () {
        ref.read(sortByPod.notifier).state = key;
        _applySorting(ref);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(key,
                style: TextStyle(
                  color: isSel ? Colors.blue.shade700 : Colors.black87,
                  fontWeight: isSel ? FontWeight.w500 : FontWeight.normal,
                )),
            if (isSel) Icon(Icons.check, size: 16, color: Colors.blue.shade700),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 80, color: Colors.orange),
          SizedBox(height: 16),
          Text('Enter search criteria above',
              style: TextStyle(fontSize: 18, color: Colors.grey)),
          SizedBox(height: 8),
          Text('Search by Mobile, Date, or Name',
              style: TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }

  /* -------------------------------------------------------- */
  /* --------------------  helpers  ------------------------- */
  /* -------------------------------------------------------- */
  void _triggerSearch(WidgetRef ref) {
    // ref.read(appNotifierProvider.notifier).setStatus('Searching patients'); // ✅ legal here
    ref.invalidate(searchResultsProvider); // re-run provider
  }

  void _applySorting(WidgetRef ref) {
    final key = ref.read(sortByPod);
    final rows = ref.read(searchResultsProvider).value ?? [];
    if (rows.isEmpty) return;

    List<Map<String, dynamic>> sorted = List.from(rows);
    switch (key) {
      case 'Name':
        sorted.sort((a, b) => (a['name'] ?? '')
            .toString()
            .compareTo((b['name'] ?? '').toString()));
        break;
      case 'Mobile':
        sorted.sort((a, b) => (a['mobile'] ?? '')
            .toString()
            .compareTo((b['mobile'] ?? '').toString()));
        break;
      case 'Date':
        sorted.sort((a, b) => (a['appointment_date'] ?? '')
            .toString()
            .compareTo((b['appointment_date'] ?? '').toString()));
        break;
      case 'Time':
        sorted.sort(
            (a, b) => (a['sort_time'] ?? 0).compareTo(b['sort_time'] ?? 0));
        break;
      case 'Tech. Status':
        sorted.sort((a, b) => (a['status'] ?? '')
            .toString()
            .compareTo((b['status'] ?? '').toString()));
        break;
      case 'Server Status':
        sorted.sort((a, b) => (a['server_status'] ?? '')
            .toString()
            .compareTo((b['server_status'] ?? '').toString()));
        break;
    }
    // push sorted list back into provider without re-fetching
    // ref.read(searchResultsProvider.notifier).state = AsyncValue.data(sorted);
  }
}

/* ----------  tiny providers  ---------- */
final sortExpandedPod = StateProvider<bool>((_) => false);
