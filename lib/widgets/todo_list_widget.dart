import 'package:flutter/material.dart';
import '../models/calendar_task.dart';
import '../services/calendar_tasks_service.dart';
import '../theme/pastel_colors.dart';

class TodoListWidget extends StatefulWidget {
  final TaskCategory category; // Filter by category (admin/production/accounts)

  const TodoListWidget({super.key, required this.category});

  @override
  State<TodoListWidget> createState() => _TodoListWidgetState();
}

class _TodoListWidgetState extends State<TodoListWidget> {
  final CalendarTasksService _tasksService = CalendarTasksService();
  List<CalendarTask> _todos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  Future<void> _loadTodos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final allTasks = await _tasksService.fetchAll();
      // Filter by category and only incomplete tasks
      final filteredTodos =
          allTasks
              .where(
                (task) => task.category == widget.category && !task.isCompleted,
              )
              .toList();
      // Sort by date (ascending)
      filteredTodos.sort((a, b) => a.date.compareTo(b.date));
      if (!mounted) return;
      setState(() {
        _todos = filteredTodos;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading todos: $e')));
    }
  }

  Future<void> _toggleComplete(CalendarTask task) async {
    final updated = CalendarTask(
      id: task.id,
      title: task.title,
      description: task.description,
      date: task.date,
      category: task.category,
      isCompleted: !task.isCompleted,
      assignedTo: task.assignedTo,
      assignedBy: task.assignedBy,
      orderId: task.orderId,
      createdBy: task.createdBy,
      createdAt: task.createdAt,
      updatedAt: DateTime.now(),
    );

    final success = await _tasksService.update(updated);
    if (success) {
      _loadTodos(); // Refresh list
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: ${_tasksService.lastError}'),
          ),
        );
      }
    }
  }

  List<CalendarTask> get _todayTasks {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _todos.where((task) {
      final taskDate = DateTime(task.date.year, task.date.month, task.date.day);
      return taskDate.isBefore(today.add(Duration(days: 1)));
    }).toList();
  }

  List<CalendarTask> get _upcomingTasks {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _todos.where((task) {
      final taskDate = DateTime(task.date.year, task.date.month, task.date.day);
      return taskDate.isAfter(today);
    }).toList();
  }

  void _showAllTodosDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            titlePadding: const EdgeInsets.fromLTRB(16, 16, 12, 0),
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Todos',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
            content: Container(
              width: double.maxFinite,
              constraints: const BoxConstraints(maxHeight: 500),
              child:
                  _todos.isEmpty
                      ? const Center(child: Text('No pending todos'))
                      : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _todos.length,
                        separatorBuilder:
                            (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final todo = _todos[index];
                          return _buildTodoItem(todo, isDialog: true);
                        },
                      ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayTasks = _todayTasks.take(3).toList();
    final upcomingTasks = _upcomingTasks;

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Todos',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[800],
                  ),
                ),
                Row(
                  children: [
                    if (_todos.isNotEmpty)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.list, size: 16),
                        label: const Text('View All'),
                        onPressed: _showAllTodosDialog,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade200),
                          foregroundColor: Colors.blueGrey[800],
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            _isLoading
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                )
                : _todos.isEmpty
                ? Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Center(
                    child: Text(
                      'No pending todos',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ),
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Today & Overdue Section
                    if (todayTasks.isNotEmpty) ...[
                        Text(
                          'By Today',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            // Match the color used for 'Upcoming Tasks' for visual consistency
                            color: Colors.blue[800],
                          ),
                        ),
                      SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: todayTasks.length,
                        separatorBuilder:
                            (context, index) => Divider(height: 1),
                        itemBuilder: (context, index) {
                          return _buildTodoItem(todayTasks[index]);
                        },
                      ),
                      if (_todayTasks.length > 3) ...[
                        SizedBox(height: 8),
                        Center(
                          child: Text(
                            '+ ${_todayTasks.length - 3} more',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],

                    // Upcoming Section (no tasks shown, just count)
                    if (upcomingTasks.isNotEmpty) ...[
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Upcoming Tasks',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${upcomingTasks.length}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodoItem(CalendarTask todo, {bool isDialog = false}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(todo.date.year, todo.date.month, todo.date.day);
    final isOverdue = taskDate.isBefore(today) && !todo.isCompleted;
    // Use pastel colors for the slim left accent bar and date/icon
    final dateColor =
        isOverdue ? PastelColors.pastelRed : PastelColors.pastelBlueGrey;
    final accentColor = _getCategoryColor(todo.category);

    // choose sizes for dialog (smaller) vs inline dashboard
    final double titleSize = isDialog ? 12.0 : 13.0;
    final double descSize = isDialog ? 11.0 : 12.0;
    final double dateSize = isDialog ? 10.0 : 11.0;
    final EdgeInsetsGeometry containerPadding =
        isDialog
            ? const EdgeInsets.symmetric(horizontal: 6, vertical: 6)
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 8);
    final double accentHeight = isDialog ? 44.0 : 56.0;

    // Minimal todo row with slim accent bar, checkbox, content, and date/status pill
    return Container(
      margin:
          isDialog
              ? const EdgeInsets.symmetric(vertical: 4)
              : const EdgeInsets.symmetric(vertical: 6),
      padding: containerPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // slim accent bar showing due/overdue color
          Container(
            width: 4,
            height: accentHeight,
            decoration: BoxDecoration(
              color: dateColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(width: isDialog ? 8 : 10),
          // checkbox (use smaller visual density when in dialog)
          Theme(
            data: Theme.of(context).copyWith(
              checkboxTheme: CheckboxThemeData(
                visualDensity:
                    isDialog
                        ? const VisualDensity(horizontal: -2, vertical: -2)
                        : VisualDensity.standard,
              ),
            ),
            child: Checkbox(
              value: todo.isCompleted,
              onChanged: (value) {
                _toggleComplete(todo);
                if (isDialog) Navigator.pop(context);
              },
            ),
          ),
          SizedBox(width: isDialog ? 4 : 6),
          // content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Assignment flow
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: _getRoleColor(todo.assignedBy).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        // Show the actual assigner role (assignedBy), capitalize first letter
                        todo.assignedBy != null && todo.assignedBy!.isNotEmpty
                            ? todo.assignedBy![0].toUpperCase() + todo.assignedBy!.substring(1)
                            : 'Unknown',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: _getRoleColor(todo.assignedBy),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child:
                          Icon(Icons.arrow_forward, size: 8, color: Colors.grey),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getCategoryName(todo.category),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ),
                    if (todo.isRecurring) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.repeat, size: 10, color: Colors.purple),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  todo.title,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w600,
                    decoration:
                        todo.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (todo.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    todo.description,
                    style: TextStyle(
                      fontSize: descSize,
                      color: Colors.grey[700],
                    ),
                    maxLines: isDialog ? null : 1,
                    overflow:
                        isDialog ? TextOverflow.visible : TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: isDialog ? 6 : 8),
          // date / overdue pill
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: isDialog ? 12 : 14,
                    color: dateColor,
                  ),
                  SizedBox(width: isDialog ? 4 : 6),
                  Text(
                    _formatDate(todo.date),
                    style: TextStyle(
                      fontSize: dateSize,
                      color: dateColor,
                      fontWeight:
                          isOverdue ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              if (isOverdue) SizedBox(height: isDialog ? 4 : 6),
            ],
          ),
        ],
      ),
    );
  }

  String _getCategoryName(TaskCategory category) {
    switch (category) {
      case TaskCategory.admin:
        return 'Admin';
      case TaskCategory.production:
        return 'Production';
      case TaskCategory.accounts:
        return 'Accounts';
      case TaskCategory.labTesting:
        return 'Lab Testing';

    }
  }

  Color _getCategoryColor(TaskCategory category) {
    switch (category) {
      case TaskCategory.admin:
        return Colors.blue.shade700;
      case TaskCategory.production:
        return Colors.purple.shade700;
      case TaskCategory.accounts:
        return Colors.orange.shade700;
      case TaskCategory.labTesting:
        return Colors.teal.shade700;
    }
  }

  Color _getRoleColor(String? role) {
    if (role == null) return Colors.grey;
    final r = role.toLowerCase();
    if (r.contains('admin')) return Colors.blue.shade700;
    if (r.contains('production')) return Colors.purple.shade700;
    if (r.contains('account')) return Colors.orange.shade700;
    if (r.contains('lab')) return Colors.teal.shade700;
    return Colors.grey.shade700;
  }


  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);

    if (taskDate == today) {
      return 'Today';
    } else if (taskDate == today.add(Duration(days: 1))) {
      return 'Tomorrow';
    } else if (taskDate == today.subtract(Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
