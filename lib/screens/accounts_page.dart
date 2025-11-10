import 'package:flutter/material.dart';
import '../widgets/wire_card.dart';
import '../services/supabase_service.dart';
import '../widgets/todo_list_widget.dart';
import '../models/calendar_task.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payments / Accounts'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await SupabaseService().signOut();
              } catch (_) {}
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Urgent Payments Section
            WireCard(
              title: 'Pending Orders / Payments Past Due',
              child: Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.warning_outlined,
                              color: Colors.red[700],
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order #1001',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.red[800],
                                  ),
                                ),
                                Text(
                                  'Past due by 5 days',
                                  style: TextStyle(
                                    color: Colors.red[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red[600],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'URGENT',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Orders Summary Section
            WireCard(
              title: 'Orders Summary',
              child: Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildOrderTile(
                      orderNumber: 'Order #1002',
                      status: 'urgent',
                      color: Colors.red,
                      icon: Icons.priority_high,
                    ),
                    SizedBox(height: 12),
                    _buildOrderTile(
                      orderNumber: 'Order #1003',
                      status: 'pending',
                      color: Colors.orange,
                      icon: Icons.schedule,
                    ),
                    SizedBox(height: 12),
                    _buildOrderTile(
                      orderNumber: 'Order #1004',
                      status: 'completed',
                      color: Colors.green,
                      icon: Icons.check_circle,
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Payment Analytics Section
            WireCard(
              title: 'Payment Analytics',
              child: Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildAnalyticsCard(
                            title: 'Outstanding',
                            amount: '\$12,450',
                            color: Colors.red,
                            icon: Icons.payment_outlined,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _buildAnalyticsCard(
                            title: 'Received',
                            amount: '\$45,200',
                            color: Colors.green,
                            icon: Icons.account_balance_wallet_outlined,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildAnalyticsCard(
                            title: 'Pending',
                            amount: '\$8,750',
                            color: Colors.orange,
                            icon: Icons.schedule_outlined,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _buildAnalyticsCard(
                            title: 'Total Revenue',
                            amount: '\$66,400',
                            color: Colors.blue,
                            icon: Icons.trending_up_outlined,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Todos Section
            TodoListWidget(category: TaskCategory.accounts),
          ],
        ),
      ),
      // Footer removed; use left sidebar
    );
  }

  Widget _buildOrderTile({
    required String orderNumber,
    required String status,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          // Make the text area flexible so the row can shrink on small widths
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Order number may be long; ellipsize to avoid overflow
                Text(
                  orderNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                // Status is shorter but still constrained
                Text(
                  status.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    required String amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
