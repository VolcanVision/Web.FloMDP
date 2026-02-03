import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A comprehensive Help & Support dialog widget that provides:
/// - Quick Help Section (Getting Started, Role Guides)
/// - FAQs (6-7 expandable questions)
/// - Contact Information (Email, Phone, Report Bug)
/// - App Info (Version, Build Number, Last Updated)
class HelpSupportDialog extends StatefulWidget {
  const HelpSupportDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const HelpSupportDialog(),
    );
  }

  @override
  State<HelpSupportDialog> createState() => _HelpSupportDialogState();
}

class _HelpSupportDialogState extends State<HelpSupportDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<int> _expandedFaqs = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 500,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(context),
            // Tab Bar
            _buildTabBar(),
            // Tab Content
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildQuickHelpTab(),
                  _buildFaqsTab(),
                  _buildContactTab(),
                  _buildAppInfoTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.help_outline_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Help & Support',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Get help and find answers',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: Colors.blue.shade700,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        indicatorSize: TabBarIndicatorSize.label,
        indicatorColor: Colors.blue.shade700,
        indicatorWeight: 3,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tabs: const [
          Tab(text: 'Quick Help'),
          Tab(text: 'FAQs'),
          Tab(text: 'Contact'),
          Tab(text: 'App Info'),
        ],
      ),
    );
  }

  // ============ QUICK HELP TAB ============
  Widget _buildQuickHelpTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Getting Started Section
          _buildSectionTitle('Getting Started', Icons.play_circle_outline),
          const SizedBox(height: 12),
          _buildHelpCard(
            title: 'Welcome to FloMDP',
            description:
                'FloMDP is a comprehensive Supply Chain Management system designed to streamline your operations from order creation to delivery.',
            icon: Icons.waving_hand,
            color: Colors.amber,
          ),
          const SizedBox(height: 12),
          _buildHelpCard(
            title: 'Dashboard Overview',
            description:
                'Your dashboard provides a quick overview of key metrics including active orders, pending purchases, inventory status, and more. Use the grid menu to navigate between different modules.',
            icon: Icons.dashboard_outlined,
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildHelpCard(
            title: 'Navigation',
            description:
                'Use the grid menu (⊞) in the header to quickly access different sections. The settings menu (⚙️) provides access to preferences, help, and logout options.',
            icon: Icons.menu_open,
            color: Colors.teal,
          ),

          const SizedBox(height: 24),

          // Role Guides Section
          _buildSectionTitle('Role Guides', Icons.people_outline),
          const SizedBox(height: 12),

          _buildRoleGuide(
            role: 'Admin',
            color: Colors.purple,
            icon: Icons.admin_panel_settings,
            guides: [
              'Full access to all modules and settings',
              'Manage orders, production, inventory, and accounts',
              'View comprehensive reports and analytics',
              'Access calendar for task scheduling',
              'Configure system preferences and user accounts',
            ],
          ),
          const SizedBox(height: 12),

          _buildRoleGuide(
            role: 'Production',
            color: Colors.orange,
            icon: Icons.precision_manufacturing,
            guides: [
              'View and manage production queue',
              'Update order production status',
              'Track inventory levels',
              'Record production losses',
              'Manage dispatch for completed orders',
            ],
          ),
          const SizedBox(height: 12),

          _buildRoleGuide(
            role: 'Accounts',
            color: Colors.green,
            icon: Icons.account_balance_wallet,
            guides: [
              'Manage purchases and payment tracking',
              'Process order payments and installments',
              'Handle dispatch and shipping operations',
              'View order history and financial reports',
              'Track pending and completed transactions',
            ],
          ),

          const SizedBox(height: 24),

          // Common Features
          _buildSectionTitle('Common Features', Icons.stars_outlined),
          const SizedBox(height: 12),

          _buildFeatureItem(
            'Orders',
            'Create, edit, and track customer orders from creation to delivery.',
            Icons.list_alt,
          ),
          _buildFeatureItem(
            'Inventory',
            'Monitor stock levels, set minimum quantities, and receive low stock alerts.',
            Icons.inventory_2,
          ),
          _buildFeatureItem(
            'Calendar',
            'Schedule tasks, set reminders, and manage recurring activities.',
            Icons.calendar_today,
          ),
          _buildFeatureItem(
            'Cost Calculator',
            'Calculate product costs and generate estimates for customers.',
            Icons.calculate,
          ),
          _buildFeatureItem(
            'Lab Tests',
            'Record and track quality control lab test results.',
            Icons.science,
          ),
          _buildFeatureItem(
            'Reports',
            'Generate and export reports for orders, inventory, and financials.',
            Icons.assessment,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue.shade700),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildHelpCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleGuide({
    required String role,
    required Color color,
    required IconData icon,
    required List<String> guides,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                '$role Role',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...guides.map((guide) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, size: 16, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        guide,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ FAQs TAB ============
  Widget _buildFaqsTab() {
    final faqs = [
      {
        'question': 'How do I create a new order?',
        'answer':
            'Navigate to the Orders section from the grid menu, then tap the "+" button or "New Order" option. Fill in the client details, add products with quantities, set due dates, and submit the order. The order will appear in your orders list and can be tracked through production.',
      },
      {
        'question': 'How do I update inventory quantities?',
        'answer':
            'Go to the Inventory section from the grid menu. You can manually update quantities by tapping on an item and editing the stock level. You can also set minimum quantity thresholds to receive low stock alerts. Inventory is automatically updated when orders are dispatched.',
      },
      {
        'question': 'How do payments and installments work?',
        'answer':
            'When creating or editing an order, you can record advance payments. Additional installments can be added later from the order details. The system tracks paid amounts and pending balances automatically. Orders show payment status as PAID, PARTIAL, or UNPAID.',
      },
      {
        'question': 'How do I track order status through production?',
        'answer':
            'Orders flow through stages: New → Confirmed → In Production → Completed → Ready for Dispatch → Dispatched → Delivered. You can view the current status in the Orders list or Production Queue. Each status change is logged for tracking.',
      },
      {
        'question': 'How do I schedule tasks on the calendar?',
        'answer':
            'Open the Calendar from the grid menu. Tap on any date to add a new task. You can set task details, assign it to a category (Admin, Production, Accounts, Purchase), set reminders, and even make tasks recurring (daily, weekly, monthly).',
      },
      {
        'question': 'How do I record a purchase?',
        'answer':
            'Go to Purchases from the grid menu. Tap "Add Purchase" and enter supplier details, items purchased, quantities, amounts, and payment information. Track payment status and set reminders for pending payments.',
      },
      {
        'question': 'How do I export data to Excel?',
        'answer':
            'Many screens support Excel export. Look for the download icon (↓) in the app bar or within data tables. Tap it to generate and share a CSV/Excel file containing the displayed data. This works for orders, inventory, purchases, and history.',
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade50, Colors.blue.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.purple.shade400),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tap on any question to expand the answer',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.purple.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(faqs.length, (index) {
            final faq = faqs[index];
            final isExpanded = _expandedFaqs.contains(index);
            return _buildFaqItem(
              index: index,
              question: faq['question']!,
              answer: faq['answer']!,
              isExpanded: isExpanded,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFaqItem({
    required int index,
    required String question,
    required String answer,
    required bool isExpanded,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded ? Colors.blue.shade200 : Colors.grey.shade200,
        ),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedFaqs.remove(index);
              } else {
                _expandedFaqs.add(index);
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        question,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      answer,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============ CONTACT TAB ============
  Widget _buildContactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Contact Methods
          _buildContactCard(
            icon: Icons.email_outlined,
            title: 'Email Support',
            subtitle: 'support@flomdp.com',
            description: 'Get help via email. We typically respond within 24 hours.',
            color: Colors.blue,
            onTap: () => _copyToClipboard('support@flomdp.com', 'Email copied!'),
          ),
          const SizedBox(height: 16),

          _buildContactCard(
            icon: Icons.phone_outlined,
            title: 'Phone Support',
            subtitle: '+91 98765 43210',
            description: 'Available Monday to Friday, 9 AM - 6 PM IST',
            color: Colors.green,
            onTap: () => _copyToClipboard('+91 98765 43210', 'Phone number copied!'),
          ),
          const SizedBox(height: 16),

          _buildContactCard(
            icon: Icons.bug_report_outlined,
            title: 'Report a Bug',
            subtitle: 'Found an issue? Let us know!',
            description: 'Help us improve by reporting bugs and unexpected behavior.',
            color: Colors.orange,
            onTap: () => _showReportBugDialog(),
          ),

          const SizedBox(height: 24),

          // Additional Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.grey.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'For urgent issues, please call our support line during business hours.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 20, color: Colors.grey.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Business Hours: Mon-Fri, 9:00 AM - 6:00 PM IST',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showReportBugDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.bug_report, color: Colors.orange.shade600),
            const SizedBox(width: 12),
            const Text('Report a Bug'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This feature is coming soon!',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'In the meantime, please send bug reports to:',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.email, size: 18, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  const Text(
                    'bugs@flomdp.com',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              _copyToClipboard('bugs@flomdp.com', 'Bug report email copied!');
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Copy Email'),
          ),
        ],
      ),
    );
  }

  // ============ APP INFO TAB ============
  Widget _buildAppInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // App Logo/Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'FloMDP',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          Text(
            'Supply Chain Management',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 32),

          // App Info Cards
          _buildInfoRow('App Version', '1.0.0', Icons.verified),
          const SizedBox(height: 12),
          _buildInfoRow('Build Number', '2026.01.20.001', Icons.build_circle),
          const SizedBox(height: 12),
          _buildInfoRow('Last Updated', 'January 20, 2026', Icons.update),
          const SizedBox(height: 12),
          _buildInfoRow('Platform', 'Flutter / Dart', Icons.code),

          const SizedBox(height: 32),

          // Legal Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildLegalItem('Privacy Policy'),
                const Divider(height: 20),
                _buildLegalItem('Terms of Service'),
                const Divider(height: 20),
                _buildLegalItem('Open Source Licenses'),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            '© 2026 FloMDP. All rights reserved.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: Colors.blue.shade600),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalItem(String title) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title - Coming soon'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Extension to get shade from Color (for MaterialColor compatibility)
extension ColorShade on Color {
  Color get shade700 {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor();
  }
}
