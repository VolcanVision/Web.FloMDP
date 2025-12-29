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
    final supabase = SupabaseService().client;
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
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = DateTime.now();
    String selectedShift = 'day';
    final supervisorController = TextEditingController();
    final operatorController = TextEditingController();
    final gradeNameController = TextEditingController();
    final quantityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gradient Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade800, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Add Production Loss',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              
              // Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date Input
                        InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null && mounted) {
                               // Simplification for dialog state
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            child: Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Shift Input
                        DropdownButtonFormField<String>(
                          value: selectedShift,
                          decoration: const InputDecoration(
                            labelText: 'Shift',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.access_time),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'day', child: Text('Day')),
                            DropdownMenuItem(value: 'night', child: Text('Night')),
                          ],
                          onChanged: (v) {
                            if (v != null) selectedShift = v;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: supervisorController,
                          decoration: const InputDecoration(
                            labelText: 'Supervisor',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => v?.isEmpty == true ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: operatorController,
                          decoration: const InputDecoration(
                            labelText: 'Operator',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.engineering_outlined),
                          ),
                          validator: (v) => v?.isEmpty == true ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: gradeNameController,
                          decoration: const InputDecoration(
                            labelText: 'Grade Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.grade_outlined),
                          ),
                          validator: (v) => v?.isEmpty == true ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: quantityController,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.numbers),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (double.tryParse(v) == null) return 'Invalid number';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final supabase = SupabaseService().client;
                        try {
                          await supabase.from('production_losses').insert({
                            'occurred_at': selectedDate.toIso8601String(),
                            'shift': selectedShift,
                            'supervisor': supervisorController.text.trim(),
                            'operator': operatorController.text.trim(),
                            'grade_name': gradeNameController.text.trim(),
                            'quantity': double.parse(quantityController.text),
                          });
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Production loss recorded')),
                            );
                            _refreshLosses();
                          }
                        } catch (e) {
                          if (mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Submit'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditLossDialog(ProductionLoss loss) {
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = loss.occurredAt;
    String selectedShift = loss.shift;
    final supervisorController = TextEditingController(text: loss.supervisor);
    final operatorController = TextEditingController(text: loss.operatorName);
    final gradeNameController = TextEditingController(text: loss.gradeName);
    final quantityController = TextEditingController(text: loss.quantity.toString());

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 500),
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Gradient Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade800, Colors.blue.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_note, color: Colors.white),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Edit Production Loss',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),

                  // Scrollable Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date Input
                            InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) {
                                  setStateDialog(() => selectedDate = date);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Date',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                ),
                                child: Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Shift Input
                            DropdownButtonFormField<String>(
                              value: selectedShift,
                              decoration: const InputDecoration(
                                labelText: 'Shift',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.access_time),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'day', child: Text('Day')),
                                DropdownMenuItem(value: 'night', child: Text('Night')),
                              ],
                              onChanged: (v) {
                                if (v != null) setStateDialog(() => selectedShift = v);
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: supervisorController,
                              decoration: const InputDecoration(
                                labelText: 'Supervisor',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (v) => v?.isEmpty == true ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: operatorController,
                              decoration: const InputDecoration(
                                labelText: 'Operator',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.engineering_outlined),
                              ),
                              validator: (v) => v?.isEmpty == true ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: gradeNameController,
                              decoration: const InputDecoration(
                                labelText: 'Grade Name',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.grade_outlined),
                              ),
                              validator: (v) => v?.isEmpty == true ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: quantityController,
                              decoration: const InputDecoration(
                                labelText: 'Quantity',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.numbers),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (double.tryParse(v) == null) return 'Invalid number';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              final supabase = SupabaseService().client;
                              try {
                                await supabase.from('production_losses').update({
                                  'occurred_at': selectedDate.toIso8601String(),
                                  'shift': selectedShift,
                                  'supervisor': supervisorController.text.trim(),
                                  'operator': operatorController.text.trim(),
                                  'grade_name': gradeNameController.text.trim(),
                                  'quantity': double.parse(quantityController.text),
                                }).eq('id', loss.id);
                                
                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Production loss updated')),
                                  );
                                  _refreshLosses();
                                }
                              } catch (e) {
                                if (mounted) {
                                   ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
          ),
        ),
      ),
    );
  }

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
          children: const [
            Text(
              'Production Loss',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Track and manage production discrepancies',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
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
        backgroundColor: Colors.blue.shade700,
      ),
    );
  }
}
