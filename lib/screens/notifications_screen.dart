// lib/screens/notifications_screen.dart
import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<Map<String, dynamic>> _notificationDetails = [
    {
      'from_name': 'No Notifications Found.',
      'msg_header': '',
      'msg_body': 'N/A',
      'updated': '',
      'status': 'N/A',
    },
  ];

  List<Map<String, dynamic>> _tableData = [];
  List<bool> _show = [];
  bool _loading = false;
  String _search = '';
  String _snackbarText = '';
  bool _snackbar = false;
  bool _overlay = false;

  @override
  void initState() {
    super.initState();
    _updateScreen();
  }

  void _updateScreen() {
    setState(() {
      _loading = true;
      _tableData = List.from(_notificationDetails);
      _show = List.filled(_tableData.length, false);
      _loading = false;
    });
  }

  void _searchDetails() {
    setState(() {
      if (_search.isEmpty) {
        _tableData = List.from(_notificationDetails);
      } else {
        _tableData = _notificationDetails.where((item) {
          final searchLower = _search.toLowerCase();
          return item['from_name'].toLowerCase().contains(searchLower) ||
              item['msg_header'].toLowerCase().contains(searchLower) ||
              item['msg_body'].toLowerCase().contains(searchLower);
        }).toList();
      }
      // Fixed: Properly initialize _show list after filtering
      _show = List.filled(_tableData.length, false);
    });
  }

  void _toggle(int index) {
    setState(() {
      // Fixed: Added bounds checking for safety
      if (index >= 0 && index < _show.length) {
        _show[index] = !_show[index];
      }
    });
  }

  void _changeStatus(Map<String, dynamic> doc) {
    setState(() {
      doc['status'] = 'Seen';
      _snackbarText = 'Successfully Updated';
      _snackbar = true;
    });

    // Hide snackbar after 2 seconds automatically
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _snackbar = false;
        });
      }
    });

    // Simulate update
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _updateScreen();
      }
    });
  }

  Color _getStatusColor(String? status) {
    if (status == 'New') {
      return Colors.blue;
    } else if (status == 'Seen') {
      return Colors.grey;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _search = value;
                });
                _searchDetails();
              },
            ),
          ),

          // Notifications list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _tableData.isEmpty
                    ? const Center(child: Text('No notifications found'))
                    : ListView.builder(
                        itemCount: _tableData.length,
                        itemBuilder: (context, index) {
                          final item = _tableData[index];
                          // Fixed: Added bounds checking before accessing _show[index]
                          final isExpanded =
                              index < _show.length ? _show[index] : false;

                          return Card(
                            margin: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                ListTile(
                                  title: Text(item['from_name']),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Msg: ${item['msg_header']}'),
                                      Text('Date: ${item['updated']}'),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Text('Status: '),
                                          InkWell(
                                            onTap: () => _changeStatus(item),
                                            child: Chip(
                                              label: Text(item['status']),
                                              backgroundColor: _getStatusColor(
                                                      item['status'])
                                                  .withOpacity(0.2),
                                              side: BorderSide(
                                                color: _getStatusColor(
                                                    item['status']),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(isExpanded
                                        ? Icons.expand_less
                                        : Icons.expand_more),
                                    onPressed: () => _toggle(index),
                                  ),
                                ),
                                if (isExpanded)
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Divider(),
                                        const Text(
                                          'Message Detail',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(item['msg_body']),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      // Snackbar for notifications
      bottomSheet: _snackbar
          ? Container(
              color: Colors.green,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _snackbarText,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _snackbar = false;
                      });
                    },
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
