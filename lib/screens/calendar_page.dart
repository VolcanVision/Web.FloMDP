import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
// sidebar removed project-wide
import '../widgets/back_to_dashboard.dart';
import '../models/calendar_task.dart';
import '../services/calendar_tasks_service.dart';
import '../services/order_payments_service.dart';
import '../services/shipment_service.dart';
import '../services/advance_payments_service.dart';
import '../services/purchases_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_service.dart';
import 'accounts/purchase_page.dart';
import 'accounts/orders_page.dart';
import '../models/purchase.dart';
import '../models/order.dart';
import '../services/orders_service.dart';
import 'package:intl/intl.dart';



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
  UserRole? _role;
  String? _currentUserAuthId;
  int? _currentUserId;

  // Simple filter state for calendar/tasks
  final List<String> _filters = [
    'All',
    'Admin',
    'Production', 
    'Accounts',
    'Shipped',
    'Advance',
    'Purchase',
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
    // Run filtering immediately on every search input change
    _searchController.addListener(() {
      setState(() {
        _filterTasks();
      });
    });
    
    // We defer user loading to didChangeDependencies or just call it here 
    // but WITHOUT route logic. Route logic moves to didChangeDependencies.
    // _initUserAndLoadTasks(); -> Moved call to didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only load if not already loading or loaded to avoid loops
    // But we need to check if _role is not yet set or if we just want to run once.
    // simpler: valid check.
    if (_role == null && _isLoading) {
      _initUserAndLoadTasks();
    }
  }

  Future<void> _initUserAndLoadTasks() async {
    // 1. Infer from route (safe here if called from didChangeDependencies or after build)
    UserRole? routeRole;
    try {
      final routeName = ModalRoute.of(context)?.settings.name;
      if (routeName != null) {
        if (routeName.startsWith('/production')) routeRole = UserRole.production;
        else if (routeName.startsWith('/admin')) routeRole = UserRole.admin;
        else if (routeName.startsWith('/accounts')) routeRole = UserRole.accounts;
        else if (routeName.startsWith('/lab_testing')) routeRole = UserRole.lab_testing;
      }
    } catch (_) {
      // ignore context errors
    }

    try {
      final user = Supabase.instance.client.auth.currentUser;
      debugPrint('[CalendarPage] Current auth user: ${user?.id}');
      if (user != null) {
        _currentUserAuthId = user.id;
        final res = await Supabase.instance.client
            .from('users')
            .select('id, role')
            .eq('auth_id', user.id)
            .maybeSingle();
        debugPrint('[CalendarPage] User lookup result: $res');
        if (res != null) {
          _currentUserId = res['id'];
          final roleStr = res['role'] as String?;
          if (roleStr != null && roleStr.isNotEmpty) {
            _role = UserRole.values.firstWhere(
              (e) => e.name == roleStr,
              orElse: () => routeRole ?? UserRole.production,
            );
          } else {
            _role = routeRole ?? UserRole.admin;
          }
        } else {
           // No user record found
          _role = routeRole ?? UserRole.admin;
        }
      } else {
        // No auth user
        _role = routeRole ?? UserRole.admin;
      }
    } catch (e) {
      debugPrint('[CalendarPage] Error fetching user info: $e');
      _role = routeRole ?? UserRole.admin;
    }
    await _loadTasks();
  }


  /// Refresh only the extra events (installments / advances / shipped)
  /// Called when the filter changes to ensure calendar markers are up-to-date.
  Future<void> _refreshExtraEvents() async {
    try {
      final installs = await _paymentsService.getAllInstallments();
      final advances = await AdvancePaymentsService.instance.getAllAdvances();
      final shipped = await _shipmentService.getOrderHistory();

      final extra = <CalendarTask>[];

      
      // Production users should not see advances or shipments (financial/logistics info) in calendar
      final isProduction = _role == UserRole.production;
      
        // ... (logic for advances/shipments/installments) is below, 
        // asking to wrap the loops or check inside.

      for (final i in installs) {
        if (isProduction) break;

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


      for (final s in shipped) {
        if (isProduction) break;

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
        if (isProduction) break;

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
      // Fetch purchases
      final purchases = await PurchasesService().fetchAll();

      final extra = <CalendarTask>[];
      final isProduction = _role == UserRole.production;

      for (final i in installs) {

        if (isProduction) break; // Skip for production
        // Only mark installment paid dates (remove due-date markers as requested)

        if (i.paidDate != null && i.paidDate!.isNotEmpty) {
          final paidDt = DateTime.tryParse(i.paidDate!);
          if (paidDt != null) {
            extra.add(
              CalendarTask(
                title: 'Installment: \u20B9${i.amount.toStringAsFixed(0)}',
                description: 'installment-paid|order:${i.orderId}|id:${i.id}',
                date: paidDt,
                category: TaskCategory.accounts,
              ),
            );
          }
        }
      }

      for (final s in shipped) {
        if (isProduction) break;

        if (s.shippedAt == null) continue;
        final dt = DateTime.tryParse(s.shippedAt!);
        if (dt == null) continue;
        // Get order details for more info
        extra.add(
          CalendarTask(
            title: 'Shipped: #${s.orderNumber ?? ''}',
            description: 'shipped|order:${s.id}|client:${s.clientName ?? ''}|products:${s.productsList ?? ''}',
            date: dt,
            category: TaskCategory.production,
          ),
        );
      }

      // Add advance (paid) events from advances table
      for (final a in advances) {
        if (isProduction) break;

        if (a.paidAt.isEmpty) continue;
        final dt = DateTime.tryParse(a.paidAt);
        if (dt == null) continue;
        extra.add(
          CalendarTask(
            title: 'Advance: \u20B9${a.amount.toStringAsFixed(0)}',
            description: 'advance-paid|order:${a.orderId}|id:${a.id}',
            date: dt,
            category: TaskCategory.accounts,
          ),
        );
      }

      // Add purchase events
      for (final p in purchases) {
        if (isProduction) break;

        if (p.purchaseDate == null) continue;
        extra.add(
          CalendarTask(
            title: 'Purchase: ${p.companyName}',
            description: 'purchase|id:${p.id}|material:${p.material}|amount:${p.totalAmount?.toStringAsFixed(0) ?? '0'}',
            date: p.purchaseDate!,
            category: TaskCategory.accounts,
          ),
        );
      }

      // Generate recurring task instances for the visible range
      final rangeStart = DateTime.now().subtract(const Duration(days: 30));
      final rangeEnd = DateTime.now().add(const Duration(days: 90));
      final allTasks = <CalendarTask>[];
      
      for (final task in tasks) {
        allTasks.add(task);
        // Generate recurring instances
        if (task.isRecurring && task.parentTaskId == null) {
          final instances = task.generateRecurringInstances(rangeStart, rangeEnd);
          
          // Filter out instances that have a concrete task override (same date + parentTaskId link)
          // or if the concrete task IS the instance (in case we saved it).
          final filteredInstances = instances.where((inst) {
            final hasOverride = tasks.any((concrete) {
              if (concrete.parentTaskId != task.id) return false;
              // Check if same date
              return isSameDay(concrete.date, inst.date);
            });
            return !hasOverride;
          }).toList();
          
          allTasks.addAll(filteredInstances);
        }
      }

      setState(() {
        _tasks = allTasks;
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

    // Filter out completed tasks from the main view (fulfills "Hide for today" and "Skip for this week")
    if (t.isCompleted) return false;


    // Apply the selected filters set
    if (_selectedFilters.isEmpty || _selectedFilters.contains('All')) {
      return true;
    }

    // Identify the type of event
    final isInstallment = t.description.startsWith('installment-paid');
    final isAdvance = t.description.startsWith('advance-paid');
    final isShipped = t.description.startsWith('shipped');
    final isPurchase = t.description.startsWith('purchase');
    final isExtra = isInstallment || isAdvance || isShipped || isPurchase;

    // Category-based filters (Admin/Production/Accounts)
    if (_selectedFilters.contains('Admin') && t.category == TaskCategory.admin && !isExtra) return true;
    if (_selectedFilters.contains('Production') && t.category == TaskCategory.production && !isExtra) return true;
    if (_selectedFilters.contains('Accounts') && t.category == TaskCategory.accounts && !isExtra) return true;

    // Extra-event filters
    if (_selectedFilters.contains('Shipped') && isShipped) return true;
    if (_selectedFilters.contains('Advance') && isAdvance) return true;
    if (_selectedFilters.contains('Purchase') && isPurchase) return true;

    return false;
  }



  Future<void> _addTask(CalendarTask t) async {
    final created = await _tasksService.create(t);
    if (created != null) {
      await _loadTasks(); // Refresh to catch recurring instances
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
    if (idx < 0 || idx >= _tasks.length) return;
    final task = _tasks[idx];
    if (task.id == null) {
      // If no ID, it might be a generated instance or local-only
      setState(() {
        _tasks.removeAt(idx);
        _filterTasks();
      });
      return;
    }

    final success = await _tasksService.remove(task.id!);
    if (success) {
      await _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Task deleted')));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: ${_tasksService.lastError}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Future<void> _toggleComplete(int idx) async {
    final task = _tasks[idx];
    
    // If task has no ID (generated recurring instance), create a concrete task 
    // to represent this specific occurrence (e.g. marking it done).
    if (task.id == null) {
      final newTask = CalendarTask(
        title: task.title,
        description: task.description,
        date: task.date,
        category: task.category,
        isCompleted: !task.isCompleted,
        assignedTo: task.assignedTo,
        assignedBy: task.assignedBy,
        orderId: task.orderId,
        createdBy: task.createdBy,
        // Link to parent so we know it's an override/exception
        parentTaskId: task.parentTaskId, 
        isRecurring: false, // Individual instance is not itself recurring usually
      );
      
      await _addTask(newTask); 
      return;
    }

    // Normal update for existing tasks
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
      isRecurring: task.isRecurring,
      recurrenceType: task.recurrenceType,
      recurrenceInterval: task.recurrenceInterval,
      recurrenceEndDate: task.recurrenceEndDate,
      parentTaskId: task.parentTaskId,
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
      ..._tasks.where((t) => isSameDay(t.date, day) && !t.isCompleted),
      ..._extraEvents.where((t) => isSameDay(t.date, day) && !t.isCompleted),
    ];
    // Apply the selected filters set to calendar markers as well
    if (_selectedFilters.isEmpty || _selectedFilters.contains('All')) {
      return combined;
    }

    return combined.where((t) {
      final isInstallment = t.description.startsWith('installment-paid');
      final isAdvance = t.description.startsWith('advance-paid');
      final isShipped = t.description.startsWith('shipped');
      final isPurchase = t.description.startsWith('purchase');
      final isExtra = isInstallment || isAdvance || isShipped || isPurchase;

      if (_selectedFilters.contains('Todos') && !isExtra) return true;
      if (_selectedFilters.contains('Installments') && isInstallment) return true;
      if (_selectedFilters.contains('Shipped') && isShipped) return true;
      if (_selectedFilters.contains('Advance') && isAdvance) return true;
      if (_selectedFilters.contains('Purchase') && isPurchase) return true;

      return false;
    }).toList();
  }


  Color _eventColor(CalendarTask t) {
    final desc = t.description;
    // prioritize explicit event tags
    // show installments as grey (user requested grey dots when "Installments" filter is active)
    if (desc.startsWith('installment-paid')) return Colors.grey.shade600;
    if (desc.startsWith('advance-paid')) {
      return Colors.grey.shade600; // advances shown as grey
    }
    if (desc.startsWith('shipped')) return Colors.green.shade600;
    
    // Fallback to category mapping using the same logic as TodoListWidget
    return _getCategoryColor(t.category);
  }

  Color _getCategoryColor(TaskCategory category) {
    switch (category) {
      case TaskCategory.admin:
        return Colors.blue.shade700;
      case TaskCategory.production:
        // User requested PURPLE for Production
        return Colors.purple.shade700;
      case TaskCategory.accounts:
        // User requested ORANGE for Accounts
        return Colors.orange.shade700;
      case TaskCategory.labTesting:
        return Colors.teal.shade700;
    }
  }

  void _showManageRecurringTasksDialog() {
    final recurringTasks = _tasks.where((t) => t.isRecurring && t.parentTaskId == null).toList();
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          titlePadding: EdgeInsets.zero,
          title: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade700, Colors.purple.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.repeat, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Manage Recurring Tasks',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                Text(
                  '${recurringTasks.length} tasks',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: SizedBox(
            width: double.maxFinite,
            child: recurringTasks.isEmpty
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_repeat, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'No recurring tasks',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a recurring task to see it here',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                    ],
                  )
                : ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: recurringTasks.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, idx) {
                        final t = recurringTasks[idx];
                        return InkWell(
                          onTap: () => _showRecurringTaskDetailsDialog(ctx, t),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: _getCategoryColor(t.category),
                                  child: Text(
                                    t.title.isNotEmpty ? t.title[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      Text(
                                        'Repeats ${_getRecurrenceLabel(t.recurrenceType)} every ${t.recurrenceInterval}',
                                        style: TextStyle(fontSize: 12, color: Colors.purple.shade600),
                                      ),
                                      if (t.recurrenceEndDate != null)
                                        Text(
                                          'Until ${t.recurrenceEndDate!.day}/${t.recurrenceEndDate!.month}/${t.recurrenceEndDate!.year}',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                                  onPressed: () => _showRecurringDeleteOptionsDialog(ctx, t),
                                  tooltip: 'Delete',
                                ),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          ),
                        );
                      },

                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show details dialog for a recurring task with edit option
  void _showRecurringTaskDetailsDialog(BuildContext parentCtx, CalendarTask t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _getCategoryColor(t.category),
              child: Text(
                t.title.isNotEmpty ? t.title[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (t.description.isNotEmpty) ...[
                Text('Description', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                const SizedBox(height: 4),
                Text(t.description),
                const SizedBox(height: 16),
              ],
              Text('Category', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              const SizedBox(height: 4),
              Text(_getCategoryName(t.category)),
              const SizedBox(height: 16),
              Text('Recurrence', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              const SizedBox(height: 4),
              Text('${_getRecurrenceLabel(t.recurrenceType)} every ${t.recurrenceInterval}'),
              if (t.recurrenceEndDate != null) ...[
                const SizedBox(height: 8),
                Text('Until ${t.recurrenceEndDate!.day}/${t.recurrenceEndDate!.month}/${t.recurrenceEndDate!.year}'),
              ],
              const SizedBox(height: 16),
              Text('Start Date', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              const SizedBox(height: 4),
              Text('${t.date.day}/${t.date.month}/${t.date.year}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(parentCtx); // Close manage dialog
              _showEditTaskDialog(t);
            },
          ),
        ],
      ),
    );
  }

  /// Show delete options dialog for recurring tasks
  void _showRecurringDeleteOptionsDialog(BuildContext parentCtx, CalendarTask t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red.shade400),
            const SizedBox(width: 8),
            const Expanded(child: Text('Delete Recurring Task')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How would you like to delete "${t.title}"?'),
            const SizedBox(height: 16),
            // Option 1: Skip for this week
            InkWell(
              onTap: () async {
                Navigator.pop(ctx);
                // To skip for a week, we mark all occurrences in the next 7 days as complete
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final weekEnd = today.add(const Duration(days: 6));
                
                final parentId = t.parentTaskId ?? t.id;
                
                // Find all tasks related to this recurrence in the next 7 days
                final tasksToSkip = _tasks.where((task) {
                    // Include all instances with same parentTaskId or if this IS the parent
                    final isRelated = (parentId != null && (task.id == parentId || task.parentTaskId == parentId)) ||
                                     (t.id == null && task.title == t.title && task.isRecurring);
                    if (!isRelated) return false;
                    return !task.date.isAfter(weekEnd) && !task.date.isBefore(today);
                }).toList();

                // Also include the current task if it's a generated instance
                if (t.id == null && !tasksToSkip.contains(t)) {
                  tasksToSkip.add(t);
                }

                bool allSuccess = true;
                int skippedCount = 0;
                for (final task in tasksToSkip) {
                  if (task.isCompleted) continue;
                  
                  if (task.id == null) {
                    // It's a generated instance, create override
                    final concrete = CalendarTask(
                      title: task.title,
                      description: task.description,
                      date: task.date,
                      category: task.category,
                      isCompleted: true,
                      assignedTo: task.assignedTo,
                      assignedBy: task.assignedBy,
                      parentTaskId: parentId,
                      isRecurring: false,
                    );
                    final created = await _tasksService.create(concrete);
                    if (created != null) skippedCount++;
                  } else {
                    // It's a concrete task, just update it
                    final updated = CalendarTask(
                      id: task.id,
                      title: task.title,
                      description: task.description,
                      date: task.date,
                      category: task.category,
                      isCompleted: true,
                      assignedTo: task.assignedTo,
                      assignedBy: task.assignedBy,
                      isRecurring: task.isRecurring,
                      recurrenceType: task.recurrenceType,
                      recurrenceInterval: task.recurrenceInterval,
                      recurrenceEndDate: task.recurrenceEndDate,
                      parentTaskId: task.parentTaskId,
                    );
                    final success = await _tasksService.update(updated);
                    if (success) skippedCount++;
                    else allSuccess = false;
                  }
                }

                await _loadTasks();
                if (Navigator.canPop(parentCtx)) Navigator.pop(parentCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(allSuccess ? 'Skipped $skippedCount tasks for the next 7 days' : 'Some tasks could not be skipped')),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                  color: Colors.purple.shade50,
                ),
                child: Row(
                  children: [
                    Icon(Icons.date_range, color: Colors.purple.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Skip for a week', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.purple.shade700)),
                          Text('Hide all occurrences for the next 7 days', style: TextStyle(fontSize: 12, color: Colors.purple.shade400)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Option 2: Delete all occurrences permanently
            InkWell(
              onTap: () async {
                Navigator.pop(ctx);
                final parentId = t.parentTaskId ?? t.id;
                if (parentId != null) {
                  await _tasksService.remove(parentId);
                  await _loadTasks();
                  if (Navigator.canPop(parentCtx)) Navigator.pop(parentCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Recurring task deleted')),
                  );
                } else {
                  // For generated instances without parent, just show message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Use "Skip for this week" to hide this occurrence')),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                  color: Colors.red.shade50,
                ),
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Delete all occurrences', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red.shade700)),
                          Text('Remove this task permanently', style: TextStyle(fontSize: 12, color: Colors.red.shade400)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }




  void _showAddDialog() {
    showDialog(
      context: context,
      builder:
          (_) => AddTaskDialog(
            selectedDate: _selectedDay ?? _focusedDay,
            currentUserRole: _role,
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
                                                        // Admin or the person assigned to/by the task can complete it
                                                        final canEdit = _role == UserRole.admin || 
                                                                    t.assignedTo == _currentUserId || 
                                                                    t.assignedBy == _currentUserAuthId || 
                                                                    t.createdBy == _currentUserId;
                                                        
                                                        if (!canEdit) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(content: Text('You do not have permission to edit this task'))
                                                          );
                                                          return;
                                                        }

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
                                                    if (_role == UserRole.admin || t.createdBy == _currentUserId || t.assignedBy == _currentUserAuthId)
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
              'Calendar',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage your schedule',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          // Manage Recurring Tasks button
          IconButton(
            icon: const Icon(Icons.repeat, color: Colors.white),
            tooltip: 'Manage Recurring Tasks',
            onPressed: _showManageRecurringTasksDialog,
          ),
          // Clear completed tasks
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
            tooltip: 'Clear Completed',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear Completed Tasks'),
                  content: const Text('Remove all completed tasks?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                final success = await _tasksService.clearCompleted();
                if (success) {
                  await _loadTasks();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Completed tasks cleared')),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: ${_tasksService.lastError}')),
                    );
                  }
                }
              }
            },
          ),
        ],
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
                        'Tasks list',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_filteredTasks.length}',
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      _buildSearchBox(),
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
      width: 180,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search...',
          prefixIcon: Icon(Icons.search, color: Colors.blue.shade400, size: 18),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
          ),
          hintStyle: TextStyle(color: Colors.blue.shade400, fontSize: 13),
        ),
      ),
    );
  }




  // legacy legend helper removed — label guide now provides the textual legend above Tasks

  Widget _buildLabelGuide() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt_outlined, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Text(
                'Filter by type:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade900,
                ),
              ),
              const Spacer(),
              if (!_selectedFilters.contains('All'))
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedFilters = {'All'};
                      _filterTasks();
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Reset', style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _filterChip('Admin', Colors.blue.shade600, 'Admin'),
              _filterChip('Production', Colors.green.shade600, 'Production'),
              _filterChip('Accounts', Colors.orange.shade600, 'Accounts'),
              _filterChip('Shipped', Colors.purple.shade600, 'Shipped'),
              _filterChip('Advance', Colors.teal.shade600, 'Advance'),
              _filterChip('Purchase', Colors.indigo.shade600, 'Purchase'),
            ],
          ),

        ],
      ),
    );
  }

  Widget _filterChip(String label, Color color, String filterValue) {
    // If 'All' is selected, technically nothing is specifically highlighted as "selected" 
    // but everything is visible. If a specific filter is selected, it should be solid.
    final bool isSelected = _selectedFilters.contains(filterValue);
    final bool isAll = _selectedFilters.contains('All');
    
    return InkWell(
      onTap: () {
        setState(() {
          if (filterValue == 'All') {
            _selectedFilters = {'All'};
          } else {
            if (isAll) {
              _selectedFilters = {filterValue};
            } else {
              if (isSelected) {
                _selectedFilters.remove(filterValue);
                if (_selectedFilters.isEmpty) _selectedFilters.add('All');
              } else {
                _selectedFilters.add(filterValue);
              }
            }
          }
          _filterTasks();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
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
    final isExtra = t.description.startsWith('installment-paid') ||
                    t.description.startsWith('advance-paid') ||
                    t.description.startsWith('shipped') ||
                    t.description.startsWith('purchase');
    
    final isGeneratedRecurring = t.parentTaskId != null;
    
    // Determine accent color
    Color accentColor;
    if (t.description.startsWith('shipped')) {
      accentColor = Colors.green.shade600;
    } else if (t.description.startsWith('installment-paid') || t.description.startsWith('advance-paid')) {
      accentColor = Colors.grey.shade600;
    } else {
      accentColor = _getCategoryColor(t.category);
    }
    
    // Permission checks
    final canEdit = !isExtra && (_role == UserRole.admin || 
                    t.assignedTo == _currentUserId || 
                    t.assignedBy == _currentUserAuthId || 
                    t.createdBy == _currentUserId);
    
    final canDelete = !isExtra && !isGeneratedRecurring && (_role == UserRole.admin || 
                      t.createdBy == _currentUserId || 
                      t.assignedBy == _currentUserAuthId);
    
    // Date label
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final taskDate = DateTime(t.date.year, t.date.month, t.date.day);
    
    String dateLabel;
    if (taskDate == today) {
      dateLabel = 'Today';
    } else if (taskDate == tomorrow) {
      dateLabel = 'Tomorrow';
    } else {
      dateLabel = '${t.date.day}/${t.date.month}';
    }
    
    return InkWell(
      onTap: () => _showTaskDetailsDialog(t),
      borderRadius: BorderRadius.circular(12),
      child: Container(

      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left accent bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            // Main content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date label row
                    Align(
                      alignment: Alignment.topRight,
                      child: Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Assignment flow (if applicable)
                    if (!isExtra) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getRoleColor(t.assignedBy).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _sentenceCase(t.assignedBy ?? 'SYSTEM'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _getRoleColor(t.assignedBy),
                              ),
                            ),


                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(Icons.arrow_forward, size: 10, color: Colors.grey.shade400),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getCategoryName(t.category),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],

                    // Checkbox + Title row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isExtra)
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: t.isCompleted,
                              onChanged: canEdit ? (_) => _toggleComplete(originalIndex) : null,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                        else
                          const SizedBox(width: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  decoration: t.isCompleted ? TextDecoration.lineThrough : null,
                                  color: t.isCompleted ? Colors.grey : Colors.black87,
                                ),
                              ),
                              if (t.description.isNotEmpty && !isExtra) ...[
                                const SizedBox(height: 2),
                                Text(
                                  t.description,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Action icons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // View button (always shown)
                            IconButton(
                              icon: Icon(Icons.visibility_outlined, color: Colors.orange.shade600, size: 20),
                              onPressed: () => _showTaskDetailsDialog(t),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              tooltip: 'View Details',
                            ),
                            // Delete button (only for editable tasks)
                            if (canDelete)
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                                onPressed: () => t.isRecurring 
                                    ? _showRecurringDeleteOptionsDialog(context, t)
                                    : _deleteTask(originalIndex),

                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                tooltip: 'Delete',
                              ),
                          ],
                        ),
                      ],
                    ),
                    // Recurring indicator
                    if (t.isRecurring) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.repeat, size: 14, color: Colors.purple.shade700),
                            const SizedBox(width: 4),
                            Text(
                              'Recurring Task',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.purple.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Repeats ${_getRecurrenceLabel(t.recurrenceType)} every ${t.recurrenceInterval}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.purple.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


  
  String _getRecurrenceLabel(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.daily:
        return 'daily';
      case RecurrenceType.weekly:
        return 'weekly';
      case RecurrenceType.monthly:
        return 'monthly';
      case RecurrenceType.none:
        return '';
    }
  }
  
  void _showTaskDetailsDialog(CalendarTask t) {
    if (t.description.startsWith('purchase|')) {
      final parts = t.description.split('|');
      final idPart = parts.firstWhere((p) => p.startsWith('id:'), orElse: () => '');
      if (idPart.isNotEmpty) {
        final id = int.tryParse(idPart.split(':')[1]);
        if (id != null) {
          _showPurchaseTaskDialog(id);
          return;
        }
      }
    }

    if (t.description.startsWith('installment-paid|') || 
        t.description.startsWith('advance-paid|') || 
        t.description.startsWith('shipped|')) {
      final parts = t.description.split('|');
      final orderPart = parts.firstWhere((p) => p.startsWith('order:'), orElse: () => '');
      if (orderPart.isNotEmpty) {
        final orderId = int.tryParse(orderPart.split(':')[1]);
        if (orderId != null) {
          _showOrderTaskDialog(orderId, t.description.split('|')[0]);
          return;
        }
      }
    }

    final isExtra = t.description.startsWith('installment-paid') ||
                    t.description.startsWith('advance-paid') ||
                    t.description.startsWith('shipped');
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _getCategoryColor(t.category),
                      radius: 24,
                      child: Text(
                        (t.title.isNotEmpty ? t.title[0] : '?').toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Task\nDetails',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    if (!isExtra)
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue.shade700),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showEditTaskDialog(t);
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailRow('Title', t.title),
                      const SizedBox(height: 12),
                      _detailSection('Description', t.description.isEmpty ? 'No description' : t.description),
                      const SizedBox(height: 12),
                      // Date chip
                      Row(
                        children: [
                          Text('Date', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today, size: 14, color: Colors.blue.shade700),
                                const SizedBox(width: 6),
                                Text(
                                  '${t.date.day}/${t.date.month}/${t.date.year}',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Category chip
                      Row(
                        children: [
                          Text('Category', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(t.category).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _getCategoryColor(t.category).withOpacity(0.3)),
                            ),
                            child: Text(
                              _getCategoryName(t.category).toUpperCase(),
                              style: TextStyle(
                                color: _getCategoryColor(t.category),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Status chip
                      Row(
                        children: [
                          Text('Status', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: t.isCompleted ? Colors.green.shade50 : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: t.isCompleted ? Colors.green.shade300 : Colors.orange.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: t.isCompleted ? Colors.green : Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  t.isCompleted ? 'COMPLETED' : 'PENDING',
                                  style: TextStyle(
                                    color: t.isCompleted ? Colors.green.shade700 : Colors.orange.shade700,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (!isExtra) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        // Assignment info
                        Row(
                          children: [
                            Icon(Icons.person_outline, size: 18, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              'Assigned to: ${_getCategoryName(t.category)}',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.group_outlined, size: 18, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              'Assigned by: Admin',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ],
                      // Recurring info
                      if (t.isRecurring) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.repeat, color: Colors.purple.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Recurring Task',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.purple.shade700,
                                      ),
                                    ),
                                    Text(
                                      'Repeats ${_getRecurrenceLabel(t.recurrenceType)} every ${t.recurrenceInterval}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.purple.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Timestamps
                      if (t.createdAt != null || t.updatedAt != null) ...[
                        const SizedBox(height: 16),
                        if (t.createdAt != null)
                          Text(
                            'Created: ${t.createdAt!.day}/${t.createdAt!.month}/${t.createdAt!.year} ${t.createdAt!.hour}:${t.createdAt!.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        if (t.updatedAt != null)
                          Text(
                            'Updated: ${t.updatedAt!.day}/${t.updatedAt!.month}/${t.updatedAt!.year} ${t.updatedAt!.hour}:${t.updatedAt!.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _detailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ],
    );
  }
  
  Widget _detailSection(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }
  
  void _showEditTaskDialog(CalendarTask t) {
    final titleController = TextEditingController(text: t.title);
    final descController = TextEditingController(text: t.description);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Task', style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
            onPressed: () async {
              final updated = CalendarTask(
                id: t.id,
                title: titleController.text.trim(),
                description: descController.text.trim(),
                date: t.date,
                category: t.category,
                isCompleted: t.isCompleted,
                assignedTo: t.assignedTo,
                assignedBy: t.assignedBy,
                orderId: t.orderId,
                createdBy: t.createdBy,
                createdAt: t.createdAt,
                updatedAt: DateTime.now(),
                isRecurring: t.isRecurring,
                recurrenceType: t.recurrenceType,
                recurrenceInterval: t.recurrenceInterval,
                recurrenceEndDate: t.recurrenceEndDate,
                parentTaskId: t.parentTaskId,
              );
              
              final success = await _tasksService.update(updated);
              if (success) {
                Navigator.pop(ctx);
                await _loadTasks();
                setState(() => _filterTasks());
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to update task'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  



  void _showPurchaseTaskDialog(int id) async {
    final purchase = await PurchasesService().fetchById(id);
    if (purchase == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade400,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Text('Details',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                ],
              ),
              const SizedBox(height: 24),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _detailField('Company Name', purchase.companyName),
                      _detailField('Material', purchase.material),
                      _detailField('Quantity', purchase.quantity?.toStringAsFixed(2) ?? '0.00'),
                      _detailField('Cost per Unit', '₹${purchase.cost?.toStringAsFixed(0) ?? '0'}'),
                      _detailField('Total Amount', '₹${purchase.totalAmount?.toStringAsFixed(0) ?? '0'}', isAmount: true),
                      _detailField('Payment Status', (purchase.paymentStatus ?? 'unpaid').toUpperCase(), isStatus: true),
                      _detailField('Payment Due Date',
                          purchase.paymentDueDate != null ? DateFormat('yyyy-MM-dd').format(purchase.paymentDueDate!) : 'N/A'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (c) => PurchasePage(filterId: purchase.id)));
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('View Full Purchase Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderTaskDialog(int orderId, String type) async {
    final order = await OrdersService.instance.getOrderById(orderId);
    if (order == null) return;

    final items = await OrdersService.instance.getOrderItemsForOrder(orderId);
    final installments = await OrderPaymentsService().getInstallments(orderId);
    final advances = await AdvancePaymentsService.instance.getPaymentsForOrder(orderId);
    
    final totalAdvances = advances.fold(0.0, (sum, a) => sum + a.amount);
    final totalPaidInstallments = installments.where((i) => i.isPaid).fold(0.0, (sum, i) => sum + i.amount);
    final totalPaid = totalAdvances + totalPaidInstallments;
    final pending = order.totalAmount - totalPaid;


    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade400,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.payment_outlined, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Text('Payment Details',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                ],
              ),
              const SizedBox(height: 24),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _detailField('Order Number', order.orderNumber ?? 'N/A'),
                      _detailField('Client Name', order.clientName ?? 'N/A'),
                      _detailField('Products', items.map((i) => '${i.productName} (${i.quantity})').join(', ')),
                      _detailField('Total Amount', '₹${order.totalAmount.toStringAsFixed(0)}'),
                      _detailField('Paid', '₹${totalPaid.toStringAsFixed(0)}', valueColor: Colors.green.shade700),
                      _detailField('Pending', '₹${pending.toStringAsFixed(0)}', valueColor: Colors.red.shade700),
                      _detailField('Final Due Date', order.finalDueDate ?? 'N/A'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (c) => AccountsOrdersPage(filterId: order.id)));
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('View Full Order Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailField(String label, String value,
      {bool isAmount = false, bool isStatus = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white, // simplified for cleaner look according to image
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ??
                      (isAmount
                          ? Colors.blue.shade700
                          : (isStatus ? Colors.orange.shade700 : Colors.black87))),
            ),
          ),
        ],
      ),
    );
  }



  String _getCategoryName(TaskCategory c) {
    switch (c) {
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

  Color _getRoleColor(String? role) {
    if (role == null) return Colors.grey;
    final r = role.toLowerCase();
    if (r.contains('admin')) return Colors.blue.shade700;
    if (r.contains('production')) return Colors.purple.shade700;
    if (r.contains('account')) return Colors.orange.shade700;
    if (r.contains('lab')) return Colors.teal.shade700;
    return Colors.grey.shade700;
  }

  String _sentenceCase(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}

class AddTaskDialog extends StatefulWidget {
  final DateTime selectedDate;
  final UserRole? currentUserRole;
  final void Function(CalendarTask) onTaskAdded;

  const AddTaskDialog({
    super.key,
    required this.selectedDate,
    required this.currentUserRole,
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
  
  // Recurring task fields
  bool _isRecurring = false;
  RecurrenceType _recurrenceType = RecurrenceType.daily;
  int _recurrenceInterval = 1;
  DateTime? _recurrenceEndDate;

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
      case TaskCategory.labTesting:
        return 'Lab Testing';
    }
  }
  
  String _getRecurrenceLabel(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.daily:
        return 'Daily';
      case RecurrenceType.weekly:
        return 'Weekly';
      case RecurrenceType.monthly:
        return 'Monthly';
      case RecurrenceType.none:
        return 'None';
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

  String _sentenceCase(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
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
          maxHeight: MediaQuery.of(context).size.height * 0.75,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Static "From" field showing current user role
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'From: ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        _sentenceCase((widget.currentUserRole ?? UserRole.production).name),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _getRoleColor((widget.currentUserRole ?? UserRole.production).name),
                        ),
                      ),
                    ],
                  ),
                ),

                TextField(
                  controller: _title,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _desc,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  keyboardType: TextInputType.multiline,
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
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
                // "To" dropdown for task assignment
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_forward, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'To: ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Expanded(
                        child: DropdownButton<TaskCategory>(
                          value: _cat,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          items: TaskCategory.values
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
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Recurring task section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.repeat, color: Colors.purple.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Recurring Task',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.purple.shade700,
                            ),
                          ),
                          const Spacer(),
                          Switch(
                            value: _isRecurring,
                            onChanged: (v) => setState(() => _isRecurring = v),
                            activeThumbColor: Colors.purple.shade700,
                          ),
                        ],
                      ),
                      if (_isRecurring) ...[
                        const SizedBox(height: 12),
                        // Recurrence type
                        Row(
                          children: [
                            const Text('Repeat:', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.purple.shade200),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: DropdownButton<RecurrenceType>(
                                    value: _recurrenceType,
                                    isExpanded: true,
                                    underline: const SizedBox.shrink(),
                                    items: [
                                      RecurrenceType.daily,
                                      RecurrenceType.weekly,
                                      RecurrenceType.monthly,
                                    ].map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(_getRecurrenceLabel(e)),
                                    )).toList(),
                                    onChanged: (v) => setState(() => _recurrenceType = v!),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Interval
                        Row(
                          children: [
                            const Text('Every:', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 60,
                              child: TextField(
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  isDense: true,
                                ),
                                controller: TextEditingController(text: '$_recurrenceInterval'),
                                onChanged: (v) {
                                  final val = int.tryParse(v);
                                  if (val != null && val > 0) {
                                    _recurrenceInterval = val;
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _recurrenceType == RecurrenceType.daily
                                  ? 'day(s)'
                                  : _recurrenceType == RecurrenceType.weekly
                                      ? 'week(s)'
                                      : 'month(s)',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // End date
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            _recurrenceEndDate == null
                                ? 'End Date: No end'
                                : 'End Date: ${_recurrenceEndDate!.day}/${_recurrenceEndDate!.month}/${_recurrenceEndDate!.year}',
                            style: TextStyle(fontSize: 13, color: Colors.purple.shade700),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_recurrenceEndDate != null)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => setState(() => _recurrenceEndDate = null),
                                ),
                              IconButton(
                                icon: Icon(Icons.calendar_today, size: 18, color: Colors.purple.shade700),
                                onPressed: () async {
                                  final d = await showDatePicker(
                                    context: context,
                                    initialDate: _recurrenceEndDate ?? _selDate!.add(const Duration(days: 30)),
                                    firstDate: _selDate!,
                                    lastDate: DateTime(2030),
                                  );
                                  if (d != null) setState(() => _recurrenceEndDate = d);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
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
                assignedBy: (widget.currentUserRole ?? UserRole.production).name, // From: logged-in user
                isRecurring: _isRecurring,
                recurrenceType: _isRecurring ? _recurrenceType : RecurrenceType.none,
                recurrenceInterval: _recurrenceInterval,
                recurrenceEndDate: _recurrenceEndDate,
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
