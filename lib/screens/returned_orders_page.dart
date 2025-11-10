import 'package:flutter/material.dart';
import '../widgets/wire_card.dart';
import '../widgets/back_to_dashboard.dart';

// Company Feedback model for returned orders context
class CompanyFeedback {
  final String date; // ISO string for simplicity
  final String company;
  final String? orderNo;
  final String? product;
  final String message;
  final List<String> tags; // categories like damage, delivery, etc.
  String sentiment; // negative | neutral | positive
  String status; // open | resolved
  final List<String> notes;

  CompanyFeedback({
    required this.date,
    required this.company,
    this.orderNo,
    this.product,
    required this.message,
    this.tags = const [],
    this.sentiment = 'neutral',
    this.status = 'open',
    List<String>? notes,
  }) : notes = notes ?? [];

  Color get sentimentColor {
    switch (sentiment.toLowerCase()) {
      case 'negative':
        return Colors.red;
      case 'positive':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  bool get isResolved => status.toLowerCase() == 'resolved';
}

class ReturnedOrdersPage extends StatefulWidget {
  const ReturnedOrdersPage({Key? key}) : super(key: key);

  @override
  State<ReturnedOrdersPage> createState() => _ReturnedOrdersPageState();
}

class _ReturnedOrdersPageState extends State<ReturnedOrdersPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _searchQuery = '';
  // Filters removed from UI; simple search-only filtering

  final List<CompanyFeedback> _feedback = [
    CompanyFeedback(
      date: '2025-09-21',
      company: 'ABC Corp',
      orderNo: '#ORD-201',
      product: 'Plastic Bottles',
      message: 'Bottles arrived with several dents; requesting replacements.',
      sentiment: 'negative',
      status: 'open',
      tags: ['damage', 'packaging'],
    ),
    CompanyFeedback(
      date: '2025-09-19',
      company: 'XYZ Industries',
      orderNo: '#ORD-199',
      product: 'Containers',
      message: 'Delivery was prompt and as expected. Good job!',
      sentiment: 'positive',
      status: 'resolved',
      tags: ['delivery'],
      notes: ['Thanked the client and noted courier performance.'],
    ),
    CompanyFeedback(
      date: '2025-09-16',
      company: 'Tech Solutions',
      orderNo: '#ORD-193',
      product: 'Wire Frames',
      message: 'Some items did not match the specified dimensions.',
      sentiment: 'negative',
      status: 'open',
      tags: ['quality'],
    ),
    CompanyFeedback(
      date: '2025-09-12',
      company: 'GreenWorks',
      orderNo: '#ORD-188',
      product: 'Recycled Resin',
      message: 'Neutral experience, but packaging could be improved.',
      sentiment: 'neutral',
      status: 'resolved',
      tags: ['packaging'],
    ),
  ];

  List<CompanyFeedback> get filteredFeedback {
    final q = _searchQuery.trim().toLowerCase();
    final list = _feedback.where((f) {
      return q.isEmpty ||
          f.company.toLowerCase().contains(q) ||
          (f.orderNo ?? '').toLowerCase().contains(q) ||
          (f.product ?? '').toLowerCase().contains(q) ||
          f.message.toLowerCase().contains(q);
    }).toList();
    // newest first (ISO date strings sort lexicographically)
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ---- Filters & Inputs ----
  // removed chip filters under search bar

  // removed sorting UI

  // removed rating slider per requirements

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: 'Search orders...',
          prefixIcon: Icon(Icons.search, color: Colors.blue.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          labelStyle: TextStyle(color: Colors.blue.shade700),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  // removed sorting; use filteredFeedback order

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.blue.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.indigo.shade400,
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.assignment_return,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Returned Orders',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.blue.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Feedback and returns at a glance',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Search & Filters
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade100.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _buildSearchField(),
                ),

                const SizedBox(height: 12),
                // Overview (admin dashboard style)
                WireCard(
                  title: 'Overview',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 6,
                    ),
                    child: Builder(
                      builder: (context) {
                        final total = _feedback.length;
                        final open = _feedback
                            .where((f) => !f.isResolved)
                            .length;
                        final resolved = _feedback
                            .where((f) => f.isResolved)
                            .length;
                        final resolutionRate = total == 0
                            ? 0.0
                            : resolved / total;

                        final tiles = [
                          _iconStatTile(
                            icon: Icons.radio_button_checked,
                            label: 'Open',
                            value: '$open',
                            color: Colors.blue,
                          ),
                          _iconStatTile(
                            icon: Icons.check_circle,
                            label: 'Resolved',
                            value: '$resolved',
                            color: Colors.teal,
                          ),
                          _iconStatTile(
                            icon: Icons.all_inbox,
                            label: 'Total',
                            value: '$total',
                            color: Colors.indigo,
                          ),
                        ];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (int i = 0; i < tiles.length; i++) ...[
                                    SizedBox(width: 160, child: tiles[i]),
                                    if (i != tiles.length - 1)
                                      const SizedBox(width: 8),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Resolution rate',
                              style: TextStyle(
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: resolutionRate,
                                      minHeight: 8,
                                      backgroundColor: Colors.blue.shade50,
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.blue.shade400,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${(resolutionRate * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: Colors.blue.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Feedback List
                WireCard(
                  title: 'Returned Orders',
                  child: Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: filteredFeedback.isEmpty
                            ? Padding(
                                key: const ValueKey('empty'),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.inbox_outlined,
                                      color: Colors.blue.shade300,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'No results',
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                key: const ValueKey('list'),
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: filteredFeedback.length > 3
                                    ? 3
                                    : filteredFeedback.length,
                                separatorBuilder: (_, __) =>
                                    SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final f = filteredFeedback[index];
                                  return _feedbackTile(f);
                                },
                              ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () => _showAllOrdersSheet(),
                          icon: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade500,
                                  Colors.indigo.shade500,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.shade200.withValues(
                                    alpha: 0.6,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.list_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue.shade700,
                            side: BorderSide(color: Colors.blue.shade200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          label: const Text('View all'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        );

        return Scaffold(
          appBar: AppBar(
            leading: const BackToDashboardButton(),
            title: const Text('Returned Orders'),
            elevation: 0,
            foregroundColor: Colors.blue.shade900,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          body: content,
          // Footer removed; use sidebar
          // No bottomNavigationBar per app navigation rules
        );
      },
    );
  }

  // ---- Icon Stat Tile (admin style) ----
  Widget _iconStatTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Subtle status pill ----
  Widget _statusPill(bool resolved) {
    final text = resolved ? 'Resolved' : 'Open';
    final dotColor = resolved ? Colors.teal : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
          ),
        ],
      ),
    );
  }

  Widget _softChip(String label) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(color: Colors.blue.shade700, fontSize: 11),
      ),
      backgroundColor: Colors.blue.shade50,
      shape: StadiumBorder(side: BorderSide(color: Colors.blue.shade200)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
    );
  }

  // removed rating stars UI

  // ---- Actions ----
  void _toggleResolved(CompanyFeedback f) {
    setState(() {
      f.status = f.isResolved ? 'open' : 'resolved';
    });
  }

  void _showFeedbackDetails(CompanyFeedback f) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(f.company),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (f.orderNo != null || f.product != null)
                Text(
                  [f.product, f.orderNo].whereType<String>().join(' • '),
                  style: TextStyle(color: Colors.blueGrey[700]),
                ),
              const SizedBox(height: 8),
              _statusPill(f.isResolved),
              const SizedBox(height: 8),
              Text(f.message),
              const SizedBox(height: 8),
              const SizedBox(height: 8),
              if (f.tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  children: f.tags.map((t) => _softChip(t)).toList(),
                ),
              const SizedBox(height: 12),
              if (f.notes.isNotEmpty) ...[
                const Text(
                  'Notes:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                ...f.notes.map(
                  (n) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(n),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Add a note...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              final text = _noteController.text.trim();
              if (text.isNotEmpty) {
                setState(() {
                  f.notes.add(text);
                  _noteController.clear();
                });
              }
            },
            child: const Text('Add note'),
          ),
          FilledButton(
            onPressed: () {
              _toggleResolved(f);
              Navigator.pop(context);
            },
            child: Text(f.isResolved ? 'Reopen' : 'Mark Resolved'),
          ),
        ],
      ),
    );
  }

  // ---- Tiles & Dialogs ----
  Widget _feedbackTile(CompanyFeedback f) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Ensure a non-zero spacer to avoid zero-size hit-test targets
            const SizedBox(width: 8),
            Expanded(
              child: ListTile(
                onTap: () => _showFeedbackDetails(f),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                isThreeLine: true,
                leading: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.indigo.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Text(
                    (f.company.isNotEmpty ? f.company[0] : '?').toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        f.company,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (f.orderNo != null)
                      Text(
                        f.orderNo!,
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (f.product != null)
                      Text(
                        f.product!,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      f.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        _statusPill(f.isResolved),
                        if (f.tags.isNotEmpty) ...[
                          ...f.tags.take(2).map((t) => _softChip(t)),
                          if (f.tags.length > 2)
                            _softChip('+${f.tags.length - 2}'),
                        ],
                      ],
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      f.date,
                      style: TextStyle(
                        color: Colors.blue.shade600,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => _toggleResolved(f),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        f.isResolved ? 'Reopen' : 'Resolve',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllOrdersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final list = filteredFeedback;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, controller) => Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.blue.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'All Returned Orders',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Text(
                          'No orders found',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.separated(
                        controller: controller,
                        padding: const EdgeInsets.all(12),
                        itemBuilder: (context, index) =>
                            _feedbackTile(list[index]),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemCount: list.length,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
