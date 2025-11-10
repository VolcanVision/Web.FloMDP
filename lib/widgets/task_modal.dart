import 'package:flutter/material.dart';

class TaskModal {
  static show(BuildContext ctx) {
    showDialog(
        context: ctx,
        builder: (_) {
          return AlertDialog(
            title: Text('Assign Task'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(decoration: InputDecoration(labelText: 'Title')),
              TextField(decoration: InputDecoration(labelText: 'Due Date')),
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx), child: Text('Assign'))
            ],
          );
        });
  }
}
