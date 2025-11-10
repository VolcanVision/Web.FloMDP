import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.1), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 12),
                ),
                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 8,
                    color: Colors.grey[400],
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 8,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 7, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MetricsRow extends StatelessWidget {
  final List<MetricCard> cards;

  const MetricsRow({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    // Use a responsive Wrap so cards flow naturally on small screens and
    // avoid RenderFlex overflow when vertical space is tight.
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        // Decide columns: 1 column for narrow (<420), otherwise 2 columns
        final columns = maxWidth < 420 ? 1 : 2;
        final spacing = 8.0;
        final itemWidth = (maxWidth - (columns - 1) * spacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children:
              cards
                  .map(
                    (c) => SizedBox(
                      width: itemWidth.clamp(120.0, maxWidth),
                      child: c,
                    ),
                  )
                  .toList(),
        );
      },
    );
  }
}
