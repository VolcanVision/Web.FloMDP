import 'package:flutter/material.dart';

class PageHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const PageHeader({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, style: TextStyle(color: Colors.black87)),
      backgroundColor: Colors.white,
      elevation: 1,
      iconTheme: IconThemeData(color: Colors.black87),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
