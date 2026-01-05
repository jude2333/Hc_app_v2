import 'package:flutter/material.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';

class TimeLinePage extends StatelessWidget {
  final WorkOrder workOrder;

  const TimeLinePage({Key? key, required this.workOrder}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final timelineData = workOrder.timeLine;

    if (timelineData.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Time Line'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: const Center(
          child: Text('No timeline data available'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Chip(
              label: const Text(
                'Time Line',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.orange,
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: timelineData.length,
        itemBuilder: (context, index) {
          final timeline = timelineData[index].toString();
          final parts = _formatTimeline(timeline);

          return _TimelineItem(
            date: parts[0],
            author: parts[1],
            description: parts[2],
            isFirst: index == 0,
            isLast: index == timelineData.length - 1,
          );
        },
      ),
    );
  }

  List<String> _formatTimeline(String item) {
    final parts = item.split('|');
    if (parts.length >= 3) {
      return [
        parts[0].trim(), // Date: "14-12-2022"
        parts[1].trim(), // Author: "Testing User"
        parts[2].trim(), // Description: "Work Order Created"
      ];
    }
    return [item, '', ''];
  }
}

class _TimelineItem extends StatelessWidget {
  final String date;
  final String author;
  final String description;
  final bool isFirst;
  final bool isLast;

  const _TimelineItem({
    required this.date,
    required this.author,
    required this.description,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (!isFirst)
                  Container(
                    width: 2,
                    height: 20,
                    color: Colors.pink,
                  ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.pink,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.pink,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$date - $author - $description',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
