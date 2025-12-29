import 'package:flutter/material.dart';
// header import removed
import '../widgets/wire_card.dart';
import '../widgets/back_to_dashboard.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        toolbarHeight: 76,
        centerTitle: false,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: const BackToDashboardButton(),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade800, Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reports & Analytics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Business intelligence',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 800) {
              return _buildWideLayout(context);
            } else {
              return _buildNarrowLayout(context);
            }
          },
        ),
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildSalesChart(),
              SizedBox(height: 16),
              _buildReturnsChart(),
              SizedBox(height: 16),
              _buildClientFeedback(),
            ],
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _buildQuickCalculator(context),
              SizedBox(height: 16),
              _buildTasksWidget(context),
              SizedBox(height: 16),
              _buildMiniCalendar(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context) {
    return Column(
      children: [
        _buildSalesChart(),
        SizedBox(height: 16),
        _buildReturnsChart(),
        SizedBox(height: 16),
        _buildQuickCalculator(context),
        SizedBox(height: 16),
        _buildClientFeedback(),
        SizedBox(height: 16),
        _buildTasksWidget(context),
        SizedBox(height: 16),
        _buildMiniCalendar(context),
      ],
    );
  }

  Widget _buildSalesChart() {
    return WireCard(
      title: 'Sales Summary',
      child: Container(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[100]!, Colors.blue[50]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.trending_up, color: Colors.blue[700], size: 32),
                    SizedBox(height: 8),
                    Text(
                      'Sales Chart',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric('This Month', '\$25,400', Colors.blue),
                _buildMetric('Last Month', '\$22,100', Colors.green),
                _buildMetric('Growth', '+15%', Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnsChart() {
    return WireCard(
      title: 'Returns Summary',
      child: Container(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red[100]!, Colors.red[50]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.trending_down, color: Colors.red[700], size: 32),
                    SizedBox(height: 8),
                    Text(
                      'Returns Chart',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric('Returns', '156', Colors.red),
                _buildMetric('Rate', '2.1%', Colors.orange),
                _buildMetric('Resolved', '142', Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientFeedback() {
    return WireCard(
      title: 'Client Feedback',
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildFeedbackItem(
              'Client A - Manufacturing Corp',
              'Excellent quality and fast delivery. Very satisfied with the service.',
              4.8,
              Colors.green,
            ),
            SizedBox(height: 12),
            _buildFeedbackItem(
              'Client B - Retail Solutions',
              'Good product but packaging could be improved.',
              4.2,
              Colors.blue,
            ),
            SizedBox(height: 12),
            _buildFeedbackItem(
              'Client C - Distribution Ltd',
              'Outstanding customer support and product quality.',
              4.9,
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCalculator(BuildContext context) {
    return WireCard(
      title: 'Quick Calculator',
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.calculate, color: Colors.green[700]),
                      SizedBox(width: 8),
                      Text(
                        'Cost Calculator',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Calculate production costs and analyze recipe profitability',
                    style: TextStyle(color: Colors.green[600]),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                '/admin/calculator',
                arguments: {'homeDashboard': '/admin/dashboard'},
              ),
              icon: Icon(Icons.open_in_new),
              label: Text('Open Calculator'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksWidget(BuildContext context) {
    return WireCard(
      title: 'Quick Tasks',
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTaskItem('Review production schedule', false),
            _buildTaskItem('Update inventory levels', true),
            _buildTaskItem('Process pending orders', false),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                '/admin/calendar',
                arguments: {'homeDashboard': '/admin/dashboard'},
              ),
              icon: Icon(Icons.add_task),
              label: Text('Manage Tasks'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniCalendar(BuildContext context) {
    return WireCard(
      title: 'Calendar Overview',
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple[200]!),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month,
                      color: Colors.purple[700],
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'December 2024',
                      style: TextStyle(
                        color: Colors.purple[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '5 tasks scheduled',
                      style: TextStyle(color: Colors.purple[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                '/admin/calendar',
                arguments: {'homeDashboard': '/admin/dashboard'},
              ),
              icon: Icon(Icons.open_in_new),
              label: Text('Open Calendar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[600],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildFeedbackItem(
    String client,
    String feedback,
    double rating,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  client,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 16),
                  Text(
                    rating.toString(),
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            feedback,
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(String task, bool completed) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Checkbox(
            value: completed,
            onChanged: (value) {},
            activeColor: Colors.green,
          ),
          Expanded(
            child: Text(
              task,
              style: TextStyle(
                decoration: completed ? TextDecoration.lineThrough : null,
                color: completed ? Colors.grey[600] : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
