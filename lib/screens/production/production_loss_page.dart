import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/supabase_service.dart';

class ProductionLoss {
  final int id;
  final DateTime occurredAt;
  final String shift;
  final String supervisor;
  final String operatorName;
  final String gradeName;
  final double quantity;
  final DateTime createdAt;

  ProductionLoss({
    required this.id,
    required this.occurredAt,
    required this.shift,
    required this.supervisor,
    required this.operatorName,
    required this.gradeName,
    required this.quantity,
    required this.createdAt,
  });

  factory ProductionLoss.fromJson(Map<String, dynamic> json) {
    return ProductionLoss(
      id: json['id'] as int,
      occurredAt: DateTime.parse(json['occurred_at'] ?? json['created_at']),
      shift: json['shift'] ?? '',
      supervisor: json['supervisor'] ?? '',
      operatorName: json['operator'] ?? '',
      gradeName: json['grade_name'] ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class ProductionLossPage extends StatefulWidget {
  const ProductionLossPage({super.key});

  @override
  State<ProductionLossPage> createState() => _ProductionLossPageState();
}

class _ProductionLossPageState extends State<ProductionLossPage> {
  Future<List<ProductionLoss>>? _futureLosses;

  @override
  void initState() {
    super.initState();
    _futureLosses = fetchLosses();
  }

  void _refreshLosses() {
    setState(() {
      _futureLosses = fetchLosses();
    });
  }

  Future<List<ProductionLoss>> fetchLosses() async {
    final supabase = await SupabaseService().client;
    final response = await supabase
        .from('production_losses')
        .select()
        .order('occurred_at', ascending: false);
    final list = response as List<dynamic>?;
    if (list == null) return [];
    return list
        .map<ProductionLoss>(
          (e) => ProductionLoss.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  void _showAddLossDialog() {
    final _formKey = GlobalKey<FormState>();
    DateTime _selectedDate = DateTime.now();
    String _selectedShift = 'day';
    final _supervisorController = TextEditingController();
    final _operatorController = TextEditingController();
    final _gradeNameController = TextEditingController();
    final _quantityController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.add, color: Colors.red),
                              const SizedBox(width: 8),
                              const Text(
                                'Add Production Loss',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today),
                        title: const Text('Date'),
                        subtitle: Text(
                          DateFormat('MMM dd, yyyy').format(_selectedDate),
                        ),
                        trailing: const Icon(Icons.edit),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            _selectedDate = date;
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedShift,
                        decoration: const InputDecoration(
                          labelText: 'Shift',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'day', child: Text('Day')),
                          DropdownMenuItem(
                            value: 'night',
                            child: Text('Night'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) _selectedShift = v;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _supervisorController,
                        decoration: const InputDecoration(
                          labelText: 'Supervisor',
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _operatorController,
                        decoration: const InputDecoration(
                          labelText: 'Operator',
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _gradeNameController,
                        decoration: const InputDecoration(
                          labelText: 'Grade Name',
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null) return 'Invalid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              if (!_formKey.currentState!.validate()) return;
                              final supabase = await SupabaseService().client;
                              await supabase.from('production_losses').insert({
                                'occurred_at': _selectedDate.toIso8601String(),
                                'shift': _selectedShift,
                                'supervisor': _supervisorController.text.trim(),
                                'operator': _operatorController.text.trim(),
                                'grade_name': _gradeNameController.text.trim(),
                                'quantity': double.parse(
                                  _quantityController.text,
                                ),
                              });
                              if (!mounted) return;
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Production loss recorded'),
                                ),
                              );
                              _refreshLosses();
                            },
                            child: const Text('Submit'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  void _showEditLossDialog(ProductionLoss loss) {
    final _formKey = GlobalKey<FormState>();
    DateTime _selectedDate = loss.occurredAt;
    String _selectedShift = loss.shift;
    final _supervisorController = TextEditingController(text: loss.supervisor);
    final _operatorController = TextEditingController(text: loss.operatorName);
    final _gradeNameController = TextEditingController(text: loss.gradeName);
    final _quantityController = TextEditingController(
      text: loss.quantity.toString(),
    );

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.edit, color: Colors.red),
                              const SizedBox(width: 8),
                              const Text(
                                'Edit Production Loss',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today),
                        title: const Text('Date'),
                        subtitle: Text(
                          DateFormat('MMM dd, yyyy').format(_selectedDate),
                        ),
                        trailing: const Icon(Icons.edit),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            _selectedDate = date;
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedShift,
                        decoration: const InputDecoration(
                          labelText: 'Shift',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'day', child: Text('Day')),
                          DropdownMenuItem(
                            value: 'night',
                            child: Text('Night'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) _selectedShift = v;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _supervisorController,
                        decoration: const InputDecoration(
                          labelText: 'Supervisor',
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _operatorController,
                        decoration: const InputDecoration(
                          labelText: 'Operator',
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _gradeNameController,
                        decoration: const InputDecoration(
                          labelText: 'Grade Name',
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null) return 'Invalid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                final supabase = await SupabaseService().client;
                                await supabase
                                    .from('production_losses')
                                    .update({
                                      'occurred_at':
                                          _selectedDate.toIso8601String(),
                                      'shift': _selectedShift,
                                      'supervisor':
                                          _supervisorController.text.trim(),
                                      'operator':
                                          _operatorController.text.trim(),
                                      'grade_name':
                                          _gradeNameController.text.trim(),
                                      'quantity': double.parse(
                                        _quantityController.text,
                                      ),
                                    })
                                    .eq('id', loss.id);
                                Navigator.pop(context);
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Production loss updated'),
                                  ),
                                );
                                _refreshLosses();
                              }
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Production Loss'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddLossDialog,
            tooltip: 'Add Record',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await SupabaseService().signOut();
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<ProductionLoss>>(
          future: _futureLosses,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: \\${snapshot.error}'));
            }
            final losses = snapshot.data ?? [];
            if (losses.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'No production losses recorded yet.',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Record'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: _showAddLossDialog,
                    ),
                  ],
                ),
              );
            }
            return ListView.separated(
              itemCount: losses.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final loss = losses[index];
                return Center(
                  child: SizedBox(
                    width: 400,
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                loss.shift == 'day'
                                    ? Colors.yellow[700]
                                    : Colors.indigo[400],
                            child: Icon(
                              loss.shift == 'day'
                                  ? Icons.wb_sunny
                                  : Icons.nightlight_round,
                              color: Colors.white,
                            ),
                          ),
                          title: Wrap(
                            spacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                DateFormat(
                                  'MMM dd, yyyy',
                                ).format(loss.occurredAt),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Chip(
                                label: Text(loss.shift.toUpperCase()),
                                backgroundColor:
                                    loss.shift == 'day'
                                        ? Colors.yellow[100]
                                        : Colors.indigo[100],
                                avatar: Icon(
                                  loss.shift == 'day'
                                      ? Icons.wb_sunny
                                      : Icons.nightlight_round,
                                  size: 18,
                                  color:
                                      loss.shift == 'day'
                                          ? Colors.orange
                                          : Colors.indigo,
                                ),
                              ),
                              Tooltip(
                                message: 'Supervisor',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.person,
                                      size: 18,
                                      color: Colors.blueGrey,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      loss.supervisor,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Tooltip(
                                  message: 'Operator',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.engineering,
                                        size: 16,
                                        color: Colors.teal,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(loss.operatorName),
                                    ],
                                  ),
                                ),
                                Tooltip(
                                  message: 'Grade',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.grade,
                                        size: 16,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(loss.gradeName),
                                    ],
                                  ),
                                ),
                                Tooltip(
                                  message: 'Quantity',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.numbers,
                                        size: 16,
                                        color: Colors.deepOrange,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(loss.quantity.toString()),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.blueAccent,
                            ),
                            tooltip: 'Edit Record',
                            onPressed: () => _showEditLossDialog(loss),
                          ),
                          onTap: () => _showEditLossDialog(loss),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLossDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Record'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
