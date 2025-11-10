import 'package:flutter/material.dart';

class AddProductModal {
  static show(BuildContext ctx) {
    showDialog(
        context: ctx,
        builder: (_) {
          return AlertDialog(
            title: Text('Add Product'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(decoration: InputDecoration(labelText: 'Product Name')),
              TextField(decoration: InputDecoration(labelText: 'Quantity')),
              TextField(
                  decoration: InputDecoration(labelText: 'Cost per unit')),
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx), child: Text('Add'))
            ],
          );
        });
  }
}
