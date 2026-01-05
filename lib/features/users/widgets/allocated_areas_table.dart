import 'package:flutter/material.dart';

/// Table widget to display allocated areas for a user.
class AllocatedAreasTable extends StatelessWidget {
  final List<dynamic> areas;

  const AllocatedAreasTable({super.key, required this.areas});

  @override
  Widget build(BuildContext context) {
    if (areas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No allocated areas',
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: Table(
        border: TableBorder.all(color: Colors.grey[300]!, width: 1),
        columnWidths: const {
          0: FlexColumnWidth(1),
          1: FlexColumnWidth(3),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: Colors.grey[200],
            ),
            children: const [
              Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Pincode',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Area',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          ...areas.map((area) => TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(area['pincode'] ?? '',
                        style: const TextStyle(fontSize: 14)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(area['area'] ?? '',
                        style: const TextStyle(fontSize: 14)),
                  ),
                ],
              )),
        ],
      ),
    );
  }
}
