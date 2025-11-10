import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
// sidebar removed project-wide
import '../widgets/back_to_dashboard.dart';
import '../models/calendar_task.dart';
import '../services/calendar_tasks_service.dart';
import '../services/order_payments_service.dart';
import '../services/shipment_service.dart';
import '../services/advance_payments_service.dart';
// order_installment and order_history models are used indirectly via services

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  late final CalendarTasksService _tasksService;
  late final OrderPaymentsService _paymentsService;
  late final ShipmentService _shipmentService;
  List<CalendarTask> _tasks = [];
  List<CalendarTask> _extraEvents = []; // installments & shipped events
  List<CalendarTask> _filteredTasks = [];
  bool _isLoading = true;

  // Simple filter state for calendar/tasks
  final List<String> _filters = [
    'All',
    'Todos',
    'Admin',
    'Production',
    'Accounts',
    'Installments',
    'Shipped',
  ];
  // Multi-select filter set. Defaults to All selected.
  Set<String> _selectedFilters = {'All'};

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tasksService = CalendarTasksService();
    _paymentsService = OrderPaymentsService();
    _shipmentService = ShipmentService();
    _selectedDay = _focusedDay;
    // Run filtering immediately on every search input change for instant feedback
    _searchController.addListener(() {
      setState(() {
        _filterTasks();
      });
    });
    // Load tasks from database
    _loadTasks();
  }

  /// Refresh only the extra events (installments / advances / shipped)
  /// Called when the filter changes to ensure calendar markers are up-to-date.
  Future<void> _refreshExtraEvents() async {
    try {
      final installs = await _paymentsService.getAllInstallments();
      final advances = await AdvancePaymentsService.instance.getAllAdvances();
      final shipped = await _shipmentService.getOrderHistory();

      final extra = <CalendarTask>[];
      for (final i in installs) {
        if (i.paidDate != null && i.paidDate!.isNotEmpty) {
          final paidDt = DateTime.tryParse(i.paidDate!);
          if (paidDt != null) {
            extra.add(
              CalendarTask(
                title: 'Installment paid: \u20B9${i.amount.toStringAsFixed(0)}',
                description: 'installment-paid|order:${i.orderId}|id:${i.id}',
                date: paidDt,
                category: TaskCategory.accounts,
              ),
            );
          }
        }
      }

      for (final s in shipped) {
        if (s.shippedAt == null) continue;
        final dt = DateTime.tryParse(s.shippedAt!);
        if (dt == null) continue;
        extra.add(
          CalendarTask(
            title: 'Shipped: #${s.orderNumber ?? ''}',
            description: 'shipped|order:${s.id}',
            date: dt,
            category: TaskCategory.production,
          ),
        );
      }

      for (final a in advances) {
        if (a.paidAt.isEmpty) continue;
        final dt = DateTime.tryParse(a.paidAt);
        if (dt == null) continue;
        extra.add(
          CalendarTask(
            title: 'Advance paid: \u20B9${a.amount.toStringAsFixed(0)}',
            description: 'advance-paid|order:${a.orderId}|id:${a.id}',
            date: dt,
            category: TaskCategory.accounts,
          ),
        );
      }

      setState(() {
        _extraEvents = extra;
      });
    } catch (e) {
      // ignore errors silently but log in debug
      // developer can inspect logs if needed
      // print('[Calendar] refreshExtraEvents error: $e');
    }
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await _tasksService.fetchAll();
      // fetch extra events (installment paid dates & shipped dates)
      final installs = await _paymentsService.getAllInstallments();
      final advances = await AdvancePaymentsService.instance.getAllAdvances();
      final shipped = await _shipmentService.getOrderHistory();

      final extra = <CalendarTask>[];
      for (final i in installs) {
        // Only mark installment paid dates (remove due-date markers as requested)
        if (i.paidDate != null && i.paidDate!.isNotEmpty) {
          final paidDt = DateTime.tryParse(i.paidDate!);
          if (paidDt != null) {
            extra.add(
              CalendarTask(
                title: 'Admin (Todos): \u20B9${i.amount.toStringAsFixed(0)}',
                description: 'installment-paid|order:${i.orderId}|id:${i.id}',
                date: paidDt,
                category: TaskCategory.accounts,
              ),
            );
          }
        }
      }

      for (final s in shipped) {
        if (s.shippedAt == null) continue;
        final dt = DateTime.tryParse(s.shippedAt!);
        if (dt == null) continue;
        extra.add(
          CalendarTask(
            title: 'Shipped: #${s.orderNumber ?? ''}',
            description: 'shipped|order:${s.id}',
            date: dt,
            category: TaskCategory.production,
          ),
        );
      }

      // Add advance (paid) events from advances table
      for (final a in advances) {
        if (a.paidAt.isEmpty) continue;
        final dt = DateTime.tryParse(a.paidAt);
        if (dt == null) continue;
        extra.add(
          CalendarTask(
            title: 'Advance paid: \u20B9${a.amount.toStringAsFixed(0)}',
            description: 'advance-paid|order:${a.orderId}|id:${a.id}',
            date: dt,
            // mark advances as accounts but color them explicitly in _eventColor
            category: TaskCategory.accounts,
          ),
        );
      }

      setState(() {
        _tasks = tasks;
        _extraEvents = extra;
        _isLoading = false;
      });
      _filterTasks();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading tasks: $e')));
      }
    }
  }

  // (helpers removed) We now call services directly from _loadTasks

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterTasks() {
    // If the user selected an extra-event filter (Installments or Shipped)
    // show matching extra-events as read-only rows in the tasks list so users
    // can see which dates are being highlighted on the calendar.
    // Filter combined tasks by the selected filter set and the search query.
    _filteredTasks =
        [..._tasks, ..._extraEvents].where((t) => _matchesFilters(t)).toList();
  }

  bool _matchesFilters(CalendarTask t) {
    final q = _searchController.text.toLowerCase();
    final matchesQuery =
        q.isEmpty ||
        t.title.toLowerCase().contains(q) ||
        t.description.toLowerCase().contains(q);

    if (!matchesQuery) return false;

    // Apply the selected filters set
    if (_selectedFilters.isEmpty || _selectedFilters.contains('All'))
      return true;

    // show only todo items (exclude explicit extra event tags) when 'Todos' selected
    final isExtra =
        t.description.startsWith('installment-paid') ||
        t.description.startsWith('advance-paid') ||
        t.description.startsWith('shipped');

    // If Todos is selected and the task is not an extra event, allow it
    if (_selectedFilters.contains('Todos') && !isExtra) return true;

    // Category filters
    if (_selectedFilters.contains('Admin') &&
        !isExtra &&
        _getCategoryName(t.category) == 'Admin')
      return true;
    if (_selectedFilters.contains('Production') &&
        !isExtra &&
        _getCategoryName(t.category) == 'Production')
      return true;
    if (_selectedFilters.contains('Accounts') &&
        !isExtra &&
        _getCategoryName(t.category) == 'Accounts')
      return true;

    // Extra-event filters
    if (_selectedFilters.contains('Installments') &&
        t.description.startsWith('installment-paid'))
      return true;
    if (_selectedFilters.contains('Shipped') &&
        t.description.startsWith('shipped'))
      return true;

    return false;
  }

  Future<void> _addTask(CalendarTask t) async {
    final created = await _tasksService.create(t);
    if (created != null) {
      setState(() {
        _tasks.add(created);
        _filterTasks();
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Task created successfully')));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create task: ${_tasksService.lastError}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteTask(int idx) async {
    final task = _tasks[idx];
    if (task.id == null) {
      // If no ID, just remove from local list
      setState(() {
        _tasks.removeAt(idx);
        _filterTasks();
      });
      return;
    }

    final success = await _tasksService.remove(task.id!);
    if (success) {
      setState(() {
        _tasks.removeAt(idx);
        _filterTasks();
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Task deleted')));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: ${_tasksService.lastError}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleComplete(int idx) async {
    final task = _tasks[idx];
    final updatedTask = CalendarTask(
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

    final success = await _tasksService.update(updatedTask);
    if (success) {
      setState(() {
        _tasks[idx] = updatedTask;
        _filterTasks();
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: ${_tasksService.lastError}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<CalendarTask> _getTasksForDay(DateTime day) {
    final combined = [
      ..._tasks.where((t) => isSameDay(t.date, day)),
      ..._extraEvents.where((t) => isSameDay(t.date, day)),
    ];
    // Apply the selected filters set to calendar markers as well
    if (_selectedFilters.isEmpty || _selectedFilters.contains('All'))
      return combined;

    return combined.where((t) {
      final isExtra =
          t.description.startsWith('installment-paid') ||
          t.description.startsWith('advance-paid') ||
          t.description.startsWith('shipped');

      if (_selectedFilters.contains('Todos') && !isExtra) return true;
      if (_selectedFilters.contains('Admin') &&
          !isExtra &&
          _getCategoryName(t.category) == 'Admin')
        return true;
      if (_selectedFilters.contains('Production') &&
          !isExtra &&
          _getCategoryName(t.category) == 'Production')
        return true;
      if (_selectedFilters.contains('Accounts') &&
          !isExtra &&
          _getCategoryName(t.category) == 'Accounts')
        return true;
      if (_selectedFilters.contains('Installments') &&
          t.description.startsWith('installment-paid'))
        return true;
      if (_selectedFilters.contains('Shipped') &&
          t.description.startsWith('shipped'))
        return true;

      return false;
    }).toList();
  }

  Color _eventColor(CalendarTask t) {
    final desc = t.description;
    // prioritize explicit event tags
    // show installments as grey (user requested grey dots when "Installments" filter is active)
    if (desc.startsWith('installment-paid')) return Colors.grey.shade600;
    if (desc.startsWith('advance-paid'))
      return Colors.grey.shade600; // advances shown as grey
    if (desc.startsWith('shipped')) return Colors.green.shade600;
    // mark account todos/events red as requested (todos still red)
    if (t.category == TaskCategory.accounts) return Colors.red.shade600;
    // fallback to category mapping
    return _getCategoryColor(t.category);
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder:
          (_) => AddTaskDialog(
            selectedDate: _selectedDay ?? _focusedDay,
            onTaskAdded: _addTask,
          ),
    );
  }

  void _showTasksForDayDialog(DateTime day) {
    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, dialogSetState) {
              // local, mutable snapshot of the tasks for this day so the dialog
              // can update immediately when the user toggles a checkbox.
              List<CalendarTask> tasks = _getTasksForDay(day);

              return AlertDialog(
                titlePadding: EdgeInsets.zero,
                title: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade700, Colors.blue.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(6),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tasks on ${day.day}/${day.month}/${day.year}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                content: Builder(
                  builder: (innerCtx) {
                    final maxHeight = MediaQuery.of(innerCtx).size.height * 0.6;
                    return SizedBox(
                      width: double.maxFinite,
                      child:
                          tasks.isEmpty
                              ? Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text('No tasks for this date.'),
                              )
                              : ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: maxHeight,
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: tasks.length,
                                  separatorBuilder:
                                      (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, idx) {
                                    final t = tasks[idx];
                                    final originalIndex = _tasks.indexOf(t);
                                    final isExtra = originalIndex == -1;
                                    return Card(
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ListTile(
                                        dense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                        leading: Container(
                                          width: 36,
                                          height: 36,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.blue.shade400,
                                                Colors.indigo.shade400,
                                              ],
                                            ),
                                          ),
                                          child: Text(
                                            (t.title.isNotEmpty
                                                    ? t.title[0]
                                                    : '?')
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          t.title,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            decoration:
                                                t.isCompleted
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        subtitle: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6,
                                          ),
                                          child: Text(
                                            '${t.date.day}/${t.date.month}/${t.date.year}',
                                            style: TextStyle(
                                              color: Colors.blue.shade700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        trailing:
                                            isExtra
                                                ? null
                                                : Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Checkbox(
                                                      value: t.isCompleted,
                                                      onChanged: (v) async {
                                                        // Toggle completion and refresh the local dialog state
                                                        await _toggleComplete(
                                                          originalIndex,
                                                        );
                                                        dialogSetState(() {
                                                          tasks =
                                                              _getTasksForDay(
                                                                day,
                                                              );
                                                        });
                                                      },
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.delete,
                                                        color: Colors.red,
                                                      ),
                                                      onPressed: () async {
                                                        // Close dialog then delete and refresh underlying list
                                                        Navigator.of(ctx).pop();
                                                        await _deleteTask(
                                                          _tasks.indexOf(t),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                    );
                  },
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Calendar'),
        leading: const BackToDashboardButton(),
        elevation: 0,
        backgroundColor: Colors.blue.shade700,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
        ),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _buildCalendarBody(),
    );
  }

  Widget _buildCalendarBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Hero header removed per request (calendar now sits directly under AppBar)
          Card(
            color: Colors.blue.shade50,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.blue.shade100),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TableCalendar<CalendarTask>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                // Only allow month view per request
                availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                eventLoader: _getTasksForDay,
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.w700,
                  ),
                  formatButtonTextStyle: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                  formatButtonDecoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: Colors.blue.shade700,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: Colors.blue.shade700,
                  ),
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  todayTextStyle: TextStyle(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    if (events.isEmpty) return const SizedBox.shrink();
                    final dots =
                        (events.cast<CalendarTask>())
                            .take(3)
                            .map(
                              (e) => Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: _eventColor(e),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                            .toList();
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: dots,
                      ),
                    );
                  },
                ),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                  // Open dialog listing tasks for the tapped date
                  _showTasksForDayDialog(selected);
                },
                onFormatChanged: (fmt) => setState(() => _calendarFormat = fmt),
                onPageChanged:
                    (focused) => setState(() => _focusedDay = focused),
              ),
            ),
          ),

          // Label guide above tasks section (only text labels per request)
          const SizedBox(height: 8),
          _buildLabelGuide(),

          // Filters removed as requested
          SizedBox(height: 12),

          Card(
            color: Colors.blue.shade50,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.blue.shade100),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Tasks',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const Spacer(),
                      // Minimalist filter dropdown with search below it
                      SizedBox(
                        width: 220,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildFilterDropdown(width: 220),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${_countEventsForFilter()} items',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            _buildSearchBox(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 360,
                    child:
                        _filteredTasks.isEmpty
                            ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inbox_outlined,
                                  color: Colors.blue.shade300,
                                  size: 28,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'No tasks',
                                  style: TextStyle(color: Colors.blue.shade700),
                                ),
                              ],
                            )
                            : ListView.separated(
                              itemCount: _filteredTasks.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, idx) {
                                final t = _filteredTasks[idx];
                                final originalIndex = _tasks.indexOf(t);
                                return _taskTile(t, originalIndex);
                              },
                            ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search tasks',
          prefixIcon: Icon(Icons.search, color: Colors.blue.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          hintStyle: TextStyle(color: Colors.blue.shade700),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({double width = 120}) {
    String label;
    if (_selectedFilters.isEmpty || _selectedFilters.contains('All')) {
      label = 'All';
    } else if (_selectedFilters.length == 1) {
      label = _selectedFilters.first;
    } else {
      label = '${_selectedFilters.length} selected';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showFilterMultiSelectDialog(),
        child: Container(
          width: width,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade100),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(Icons.filter_list, size: 18, color: Colors.blue.shade500),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: Colors.blue.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterMultiSelectDialog() {
    final temp = Set<String>.from(_selectedFilters);
    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setStateDialog) {
              final selectedCount =
                  temp.isEmpty || temp.contains('All')
                      ? (_filters.length)
                      : temp.length;
              return AlertDialog(
                titlePadding: EdgeInsets.zero,
                title: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade700, Colors.blue.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(6),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Select filters',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        selectedCount == _filters.length
                            ? 'All'
                            : '$selectedCount selected',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                content: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                    minWidth: 280,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children:
                          _filters.map((f) {
                            final checked = temp.contains(f);
                            return CheckboxListTile(
                              controlAffinity: ListTileControlAffinity.leading,
                              value: checked,
                              visualDensity: VisualDensity.compact,
                              title: Text(f),
                              onChanged: (v) {
                                setStateDialog(() {
                                  if (v == true) {
                                    if (f == 'All') {
                                      temp.clear();
                                      temp.add('All');
                                    } else {
                                      temp.remove('All');
                                      temp.add(f);
                                    }
                                  } else {
                                    temp.remove(f);
                                  }
                                });
                              },
                            );
                          }).toList(),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                    ),
                    onPressed: () async {
                      setState(() {
                        _selectedFilters =
                            temp.isEmpty ? {'All'} : Set.from(temp);
                      });
                      // Refresh extra events if necessary
                      if (_selectedFilters.contains('Installments') ||
                          _selectedFilters.contains('Shipped') ||
                          _selectedFilters.contains('All')) {
                        await _refreshExtraEvents();
                      }
                      setState(() {
                        _filterTasks();
                      });
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Apply'),
                  ),
                ],
              );
            },
          ),
    );
  }

  int _countEventsForFilter() {
    final combined = [..._tasks, ..._extraEvents];
    if (_selectedFilters.isEmpty || _selectedFilters.contains('All'))
      return combined.length;
    return combined.where((t) {
      final isExtra =
          t.description.startsWith('installment-paid') ||
          t.description.startsWith('advance-paid') ||
          t.description.startsWith('shipped');

      if (_selectedFilters.contains('Todos') && !isExtra) return true;
      if (_selectedFilters.contains('Admin') &&
          !isExtra &&
          _getCategoryName(t.category) == 'Admin')
        return true;
      if (_selectedFilters.contains('Production') &&
          !isExtra &&
          _getCategoryName(t.category) == 'Production')
        return true;
      if (_selectedFilters.contains('Accounts') &&
          !isExtra &&
          _getCategoryName(t.category) == 'Accounts')
        return true;
      if (_selectedFilters.contains('Installments') &&
          t.description.startsWith('installment-paid'))
        return true;
      if (_selectedFilters.contains('Shipped') &&
          t.description.startsWith('shipped'))
        return true;

      return false;
    }).length;
  }

  // legacy legend helper removed — label guide now provides the textual legend above Tasks

  Widget _buildLabelGuide() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _labelChip(Colors.blue.shade600, 'Admin todo'),
          _labelChip(Colors.purple, 'Production todo'),
          _labelChip(Colors.red.shade600, 'Accounts todo'),
          _labelChip(Colors.grey.shade600, 'Installment paid'),
          _labelChip(Colors.green.shade600, 'Shipments'),
        ],
      ),
    );
  }

  Widget _labelChip(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // _filterChipNew removed along with filters UI

  Widget _categoryChip(String label, Color color) {
    // Use a pastel background and darker label for better readability on phones
    final bg = color.withOpacity(0.12);
    final border = color.withOpacity(0.18);
    final textColor = color is MaterialColor ? color.shade700 : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _statusPill(bool done) {
    final text = done ? 'Done' : 'Todo';
    final dot = done ? Colors.teal : Colors.orange;
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
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
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

  Widget _taskTile(CalendarTask t, int originalIndex) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade50),
      ),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Colors.blue.shade400, Colors.indigo.shade400],
            ),
          ),
          child: Text(
            (t.title.isNotEmpty ? t.title[0] : '?').toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(
          t.title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            decoration: t.isCompleted ? TextDecoration.lineThrough : null,
            color: Colors.black87,
          ),
        ),
        subtitle: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              '${t.date.day}/${t.date.month}/${t.date.year}',
              style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
            ),
            _categoryChip(
              _getCategoryName(t.category),
              _getCategoryColor(t.category),
            ),
            _statusPill(t.isCompleted),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: t.isCompleted,
              onChanged: (_) => _toggleComplete(originalIndex),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteTask(originalIndex),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(TaskCategory c) {
    switch (c) {
      case TaskCategory.admin:
        return Colors.blue;
      case TaskCategory.production:
        return Colors.purple;
      case TaskCategory.accounts:
        return Colors.red; // show Accounts category in red in task list
    }
  }

  String _getCategoryName(TaskCategory c) {
    switch (c) {
      case TaskCategory.admin:
        return 'Admin';
      case TaskCategory.production:
        return 'Production';
      case TaskCategory.accounts:
        return 'Accounts';
    }
  }
}

class AddTaskDialog extends StatefulWidget {
  final DateTime selectedDate;
  final void Function(CalendarTask) onTaskAdded;

  const AddTaskDialog({
    super.key,
    required this.selectedDate,
    required this.onTaskAdded,
  });

  @override
  _AddTaskDialogState createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  DateTime? _selDate;
  TaskCategory _cat = TaskCategory.production;

  @override
  void initState() {
    super.initState();
    _selDate = widget.selectedDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  String _getCategoryLabel(TaskCategory c) {
    switch (c) {
      case TaskCategory.admin:
        return 'Admin';
      case TaskCategory.production:
        return 'Production';
      case TaskCategory.accounts:
        return 'Accounts';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(
        'Add Todo',
        style: TextStyle(
          color: Colors.blue.shade900,
          fontWeight: FontWeight.w700,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SizedBox(
            width:
                MediaQuery.of(context).size.width < 440
                    ? MediaQuery.of(context).size.width - 40
                    : 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _title,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _desc,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  keyboardType: TextInputType.multiline,
                  minLines: 3,
                  maxLines: 5,
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Date: ${_selDate!.day}/${_selDate!.month}/${_selDate!.year}',
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                  trailing: Icon(
                    Icons.calendar_today,
                    color: Colors.blue.shade700,
                  ),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _selDate!,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setState(() => _selDate = d);
                  },
                ),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: DropdownButton<TaskCategory>(
                      value: _cat,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      items:
                          TaskCategory.values
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(_getCategoryLabel(e)),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _cat = v!),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Colors.blue.shade700)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            if (_title.text.trim().isEmpty) return;
            widget.onTaskAdded(
              CalendarTask(
                title: _title.text.trim(),
                description: _desc.text.trim(),
                date: _selDate!,
                category: _cat,
              ),
            );
            Navigator.pop(context);
          },
          child: const Text('Add', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
