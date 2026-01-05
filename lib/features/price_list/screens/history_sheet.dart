import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:anderson_crm_flutter/features/price_list/price_list.dart';

class HistorySheet extends ConsumerStatefulWidget {
  const HistorySheet({Key? key}) : super(key: key);

  @override
  ConsumerState<HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends ConsumerState<HistorySheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredHistory = [];
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final state = ref.read(priceListProvider);
      _filteredHistory = List.from(state.globalHistory);
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final state = ref.read(priceListProvider);
    final fullList = state.globalHistory;

    if (query.isEmpty) {
      setState(() {
        _filteredHistory = List.from(fullList);
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredHistory = fullList.where((item) {
        final summary = (item['summary'] ?? '').toString().toLowerCase();
        final action = (item['action'] ?? '').toString().toLowerCase();
        final name = (item['emp_name'] ?? '').toString().toLowerCase();

        return summary.contains(lowerQuery) ||
            action.contains(lowerQuery) ||
            name.contains(lowerQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(priceListProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Chip(
                label: Text('Add-Edit-Delete History',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    )),
                backgroundColor: Colors.orange,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search History...',
              prefixIcon: const Icon(Icons.search, size: 20),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
            onChanged: (val) {
              Future.delayed(const Duration(milliseconds: 300), () {
                if (_searchController.text == val) _onSearchChanged(val);
              });
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              border: Border(bottom: BorderSide(color: Colors.orange)),
            ),
            child: const Row(
              children: [
                _HeaderCell('Action', flex: 2),
                _HeaderCell('Summary', flex: 6),
                _HeaderCell('Name', flex: 2),
                _HeaderCell('Time', flex: 3),
              ],
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredHistory.isEmpty
                    ? const Center(
                        child: Text("No records found",
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _filteredHistory.length,
                        itemBuilder: (context, index) {
                          final item = _filteredHistory[index];

                          return RepaintBoundary(
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          item['action'] ?? '',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                _getActionColor(item['action']),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 6,
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8.0),
                                          child: Text(
                                            item['summary'] ?? '',
                                            style: const TextStyle(
                                                fontSize: 14, height: 1.3),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          item['emp_name'] ?? '',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          item['time_stamp'] ?? '',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black),
                                          textAlign: TextAlign.start,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1, thickness: 0.5),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Color _getActionColor(String? action) {
    switch (action?.toLowerCase()) {
      case 'created':
        return Colors.green;
      case 'updated':
        return Colors.blue;
      case 'deleted':
        return Colors.red;
      default:
        return Colors.black87;
    }
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  const _HeaderCell(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}
