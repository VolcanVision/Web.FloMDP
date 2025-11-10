import 'package:flutter/material.dart';

class WireCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Color? titleColor;
  const WireCard({
    super.key,
    required this.title,
    required this.child,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: titleColor ?? Colors.black87,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
