import 'package:flutter/material.dart';
import '../../widgets/back_to_dashboard.dart';
import '../../services/lab_test_service.dart';
import '../../services/excel_export_service.dart';
import '../../models/lab_test.dart';
import '../../models/sub_test.dart';
import 'package:intl/intl.dart';
import '../../auth/auth_service.dart';

class LabTestPage extends StatefulWidget {
  const LabTestPage({super.key});

  @override
  State<LabTestPage> createState() => _LabTestPageState();
}

class _LabTestPageState extends State<LabTestPage> {
  final LabTestService _labTestService = LabTestService();
  List<LabTest> _activeTests = [];
  List<LabTest> _completedTests = [];
  int _activeCount = 0;
  int _completedCount = 0;
  bool _isLoading = true;
  bool _showActive = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // mark loading immediately if still mounted
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final counts = await _labTestService.getTestCounts();
      final activeTests = await _labTestService.getActiveTests();

      if (!mounted) return;
      setState(() {
        _activeCount = counts['active'] ?? 0;
        _completedCount = counts['completed'] ?? 0;
        _activeTests = activeTests;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    }
  }

  Future<void> _loadCompletedTests() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final completed = await _labTestService.getCompletedTests();
      if (!mounted) return;
      setState(() {
        _completedTests = completed;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading completed tests: $e')),
      );
    }
  }

  void _showTestDialog(LabTest test) {
    showDialog(
      context: context,
      builder:
          (context) => TestDetailsDialog(test: test, onTestUpdated: _loadData),
    );
  }

  void _showAddTestDialog() {
    showDialog(
      context: context,
      builder: (context) => AddTestDialog(onTestAdded: _loadData),
    );
  }

  Future<void> _markTestAsPending(LabTest test) async {
    if (test.id == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot update test without id')),
        );
      }
      return;
    }
    try {
      // server and services consider an active test to have status 'active'
      final updated = test.copyWith(status: 'active', completedAt: null);
      await _labTestService.updateTest(updated);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Test marked as pending')));
        // Refresh both lists so the test moves from completed -> active immediately
        await _loadData();
        await _loadCompletedTests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error marking pending: $e')));
      }
    }
  }

  Future<void> _markTestAsCompleted(LabTest test) async {
    if (test.id == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot update test without id')),
        );
      }
      return;
    }
    try {
      final updated = test.copyWith(
        status: 'completed',
        completedAt: DateTime.now(),
      );
      await _labTestService.updateTest(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test marked as completed')),
        );
        // refresh both lists
        await _loadData();
        await _loadCompletedTests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error marking completed: $e')));
      }
    }
  }

  Future<void> _exportLabTestsToExcel() async {
    try {
      // Get all tests (both active and completed)
      final List<LabTest> allTests = [..._activeTests, ..._completedTests];
      
      // If completed tests are empty, load them first
      if (_completedTests.isEmpty && _completedCount > 0) {
        final completed = await _labTestService.getCompletedTests();
        allTests.addAll(completed);
      }

      if (allTests.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No tests to export')),
          );
        }
        return;
      }

      final headers = [
        'Test Name',
        'Status',
        'Created Date',
        'Completed Date',
        'Sub-Tests',
        'Notes',
      ];

      final List<List<dynamic>> rows = [];
      
      for (final test in allTests) {
        // Get sub-tests for this test
        List<SubTest> subTests = [];
        if (test.id != null) {
          try {
            subTests = await _labTestService.getSubTests(test.id!);
          } catch (_) {
            subTests = [];
          }
        }

        final subTestsStr = subTests
            .map((s) => '${s.testName}: ${s.result ?? 'N/A'}')
            .join('; ');

        rows.add([
          test.testName ?? test.materialName ?? 'Unnamed Test',
          test.status?.toUpperCase() ?? 'ACTIVE',
          test.createdAt != null
              ? DateFormat('dd/MM/yyyy').format(test.createdAt!)
              : '',
          test.completedAt != null
              ? DateFormat('dd/MM/yyyy').format(test.completedAt!)
              : '',
          subTestsStr,
          test.notes ?? '',
        ]);
      }

      await ExcelExportService.instance.exportToCsv(
        headers: headers,
        rows: rows,
        fileName: 'lab_tests_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lab tests exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting tests: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
        leading: (ModalRoute.of(context)?.settings.name == '/lab_testing/dashboard' && 
                  (ModalRoute.of(context)?.settings.arguments as Map?)?['homeDashboard'] == null)
            ? IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () async {
                  await AuthService.logout();
                  Navigator.pushReplacementNamed(context, '/login');
                },
                tooltip: 'Logout',
              )
            : const BackToDashboardButton(),
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
              'Lab Testing',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Quality assurance & testing',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: _exportLabTestsToExcel,
            tooltip: 'Download All Tests',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTestDialog,
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Stats Cards (clickable)
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatsCard(
                            'Active Tests',
                            _activeCount,
                            Colors.orange,
                            Icons.science,
                            onTap: () async {
                              if (!_showActive) {
                                // show active list
                                setState(() => _showActive = true);
                                // ensure counts are fresh
                                await _loadData();
                              }
                            },
                            selected: _showActive,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatsCard(
                            'Completed Tests',
                            _completedCount,
                            Colors.green,
                            Icons.check_circle,
                            onTap: () async {
                              if (_showActive) {
                                setState(() => _showActive = false);
                                await _loadCompletedTests();
                              }
                            },
                            selected: !_showActive,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Tests List (active or completed)
                    Expanded(
                      child: Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                _showActive
                                    ? 'Active Tests'
                                    : 'Completed Tests',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child:
                                  (_showActive ? _activeTests : _completedTests)
                                          .isEmpty
                                      ? Center(
                                        child: Text(
                                          _showActive
                                              ? 'No active tests'
                                              : 'No completed tests',
                                        ),
                                      )
                                      : ListView.builder(
                                        itemCount:
                                            (_showActive
                                                    ? _activeTests
                                                    : _completedTests)
                                                .length,
                                        itemBuilder: (context, index) {
                                          final test =
                                              (_showActive
                                                  ? _activeTests
                                                  : _completedTests)[index];
                                          return ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor:
                                                  _showActive
                                                      ? Colors.orange.shade100
                                                      : Colors.green.shade100,
                                              child: Icon(
                                                Icons.science,
                                                color:
                                                    _showActive
                                                        ? Colors.orange.shade700
                                                        : Colors.green.shade700,
                                              ),
                                            ),
                                            title: Text(
                                              test.testName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            subtitle: Text(
                                              test.testDate != null
                                                  ? DateFormat(
                                                    'MMM dd, yyyy',
                                                  ).format(test.testDate!)
                                                  : 'No date set',
                                            ),
                                            trailing:
                                                _showActive
                                                    ? IconButton(
                                                      icon: Icon(
                                                        Icons.check_circle,
                                                        color:
                                                            Colors
                                                                .green
                                                                .shade700,
                                                      ),
                                                      tooltip:
                                                          'Mark as Completed',
                                                      onPressed: () async {
                                                        await _markTestAsCompleted(
                                                          test,
                                                        );
                                                      },
                                                    )
                                                    : IconButton(
                                                      icon: Icon(
                                                        Icons.pending,
                                                        color:
                                                            Colors
                                                                .orange
                                                                .shade700,
                                                      ),
                                                      tooltip:
                                                          'Mark as Pending',
                                                      onPressed: () async {
                                                        await _markTestAsPending(
                                                          test,
                                                        );
                                                      },
                                                    ),
                                            onTap: () => _showTestDialog(test),
                                          );
                                        },
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

  Widget _buildStatsCard(
    String title,
    int count,
    Color color,
    IconData icon, {
    VoidCallback? onTap,
    bool selected = false,
  }) {
    return Card(
      elevation: 0,
      color: selected ? color.withOpacity(0.06) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 12),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TestDetailsDialog extends StatefulWidget {
  final LabTest test;
  final VoidCallback onTestUpdated;

  const TestDetailsDialog({
    super.key,
    required this.test,
    required this.onTestUpdated,
  });

  @override
  State<TestDetailsDialog> createState() => _TestDetailsDialogState();
}

class _TestDetailsDialogState extends State<TestDetailsDialog> {
  final LabTestService _labTestService = LabTestService();
  final TextEditingController _compositionController = TextEditingController();

  bool _isEditingComposition = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _compositionController.text = widget.test.composition ?? '';
  }

  @override
  void dispose() {
    _compositionController.dispose();
    super.dispose();
  }

  Future<void> _saveComposition() async {
    setState(() => _isSaving = true);
    try {
      await _labTestService.updateComposition(
        widget.test.id!,
        _compositionController.text,
      );
      setState(() {
        _isEditingComposition = false;
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Composition saved successfully')),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving composition: $e')));
      }
    }
  }

  Future<void> _exportSingleTestToExcel() async {
    try {
      // Get sub-tests for this test
      List<SubTest> subTests = [];
      if (widget.test.id != null) {
        try {
          subTests = await _labTestService.getSubTests(widget.test.id!);
        } catch (_) {
          subTests = [];
        }
      }

      final headers = [
        'Field',
        'Value',
      ];

      final rows = <List<dynamic>>[
        ['Test Name', widget.test.testName ?? 'Unnamed Test'],
        ['Status', widget.test.status?.toUpperCase() ?? 'ACTIVE'],
        ['Created Date', widget.test.createdAt != null
            ? DateFormat('dd/MM/yyyy').format(widget.test.createdAt!)
            : 'N/A'],
        ['Completed Date', widget.test.completedAt != null
            ? DateFormat('dd/MM/yyyy').format(widget.test.completedAt!)
            : 'N/A'],
        ['Notes', widget.test.notes ?? ''],
        ['', ''], // Empty row
        ['Sub-Tests', ''],
      ];

      // Add sub-tests
      for (final subTest in subTests) {
        rows.add(['  ${subTest.testName}', subTest.result ?? 'N/A']);
      }

      if (subTests.isEmpty) {
        rows.add(['  No sub-tests', '']);
      }

      await ExcelExportService.instance.exportToCsv(
        headers: headers,
        rows: rows,
        fileName: 'lab_test_${widget.test.testName?.replaceAll(' ', '_') ?? widget.test.id}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting test: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addSubTest() {
    showDialog(
      context: context,
      builder:
          (context) => AddSubTestDialog(
            labTestId: widget.test.id!,
            onSubTestAdded: () {
              setState(() {}); // Refresh the UI
            },
          ),
    );
  }

  Future<void> _deleteSubTest(int subTestId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Test'),
            content: const Text('Are you sure you want to delete this test?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await _labTestService.deleteSubTest(subTestId);
        setState(() {}); // Refresh the UI
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Test deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting test: $e')));
        }
      }
    }
  }

  Future<void> _confirmAndDeleteTest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Test'),
            content: const Text(
              'Are you sure you want to delete this test and all its sub-tests? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await _deleteTest();
    }
  }

  Future<void> _deleteTest() async {
    if (widget.test.id == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot delete test without id')),
        );
      }
      return;
    }

    try {
      await _labTestService.deleteTest(widget.test.id!);
      if (mounted) {
        Navigator.of(context).pop(); // close details dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test deleted successfully')),
        );
        widget.onTestUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting test: $e')));
      }
    }
  }

  void _showEditSubTestDialog(SubTest subTest) {
    final nameCtrl = TextEditingController(text: subTest.testName);
    final resultCtrl = TextEditingController(text: subTest.result ?? '');
    DateTime pickedDate = subTest.testDate ?? DateTime.now();

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Edit Sub-test'),
            content: StatefulBuilder(
              builder: (ctx, setStateDialog) {
                return SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Test Name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: pickedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setStateDialog(() => pickedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.grey.shade50,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: Colors.grey[700],
                              ),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat('MMM dd, yyyy').format(pickedDate),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: resultCtrl,
                        decoration: const InputDecoration(labelText: 'Result'),
                      ),
                    ],
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final updated = subTest.copyWith(
                    testName: nameCtrl.text,
                    testDate: pickedDate,
                    result: resultCtrl.text.isEmpty ? null : resultCtrl.text,
                    updatedAt: DateTime.now(),
                  );
                  try {
                    await _labTestService.updateSubTest(updated);
                    if (mounted) {
                      setState(() {}); // refresh dialog UI
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sub-test updated')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error updating sub-test: $e')),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade800, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.test.testName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Download test',
                    icon: const Icon(Icons.download, color: Colors.white),
                    onPressed: _exportSingleTestToExcel,
                  ),
                  IconButton(
                    tooltip: 'Delete test',
                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                    onPressed: () => _confirmAndDeleteTest(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Test Name (header already shows this, but keeping for context)
                    // Material Name section removed - same as test name

                    // Composition (editable, hidden from capture)
                    Text(
                      'Composition',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child:
                              _isEditingComposition
                                  ? TextField(
                                    controller: _compositionController,
                                    maxLines: 3,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      hintText: 'Enter composition details...',
                                    ),
                                  )
                                  : Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _compositionController.text.isEmpty
                                          ? 'No composition specified'
                                          : _compositionController.text,
                                    ),
                                  ),
                        ),
                        const SizedBox(width: 8),
                        if (_isEditingComposition)
                          // Compact save button to reduce visual weight
                          ElevatedButton(
                            onPressed: _isSaving ? null : _saveComposition,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              minimumSize: const Size(60, 36),
                              visualDensity: VisualDensity.compact,
                            ),
                            child:
                                _isSaving
                                    ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.save, size: 16),
                                        SizedBox(width: 6),
                                        Text(
                                          'Save',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Edit composition',
                            onPressed:
                                () => setState(
                                  () => _isEditingComposition = true,
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Tests Section
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tests',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Sub-tests for this lab entry',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.blue,
                          ),
                          onPressed: () => _addSubTest(),
                          tooltip: 'Add Test',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<SubTest>>(
                      future: _labTestService.getSubTests(widget.test.id!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'Error loading tests: ${snapshot.error}',
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          );
                        }

                        final subTests = snapshot.data ?? [];
                        if (subTests.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Center(
                              child: Text(
                                'No tests added yet',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: subTests.length,
                          itemBuilder: (context, index) {
                            final subTest = subTests[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 0,
                              color: Colors.grey.shade50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Colors.grey.shade100),
                              ),
                              child: ListTile(
                                // Removed leading icon per request (cleaner dialog)
                                title: Text(subTest.testName),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Date: ${subTest.testDate != null ? DateFormat('MMM dd, yyyy').format(subTest.testDate!) : 'Not specified'}',
                                    ),
                                    Text(
                                      'Result: ${subTest.result ?? 'Pending'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.blue,
                                      ),
                                      tooltip: 'Edit sub-test',
                                      onPressed:
                                          () => _showEditSubTestDialog(subTest),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed:
                                          () => _deleteSubTest(subTest.id!),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Add Test Dialog
class AddTestDialog extends StatefulWidget {
  final VoidCallback onTestAdded;

  const AddTestDialog({super.key, required this.onTestAdded});

  @override
  State<AddTestDialog> createState() => _AddTestDialogState();
}

class _AddTestDialogState extends State<AddTestDialog> {
  final LabTestService _labTestService = LabTestService();
  final TextEditingController _materialNameController = TextEditingController();
  final TextEditingController _compositionController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _materialNameController.dispose();
    _compositionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_materialNameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a material name')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final test = LabTest(
        testName: _materialNameController.text, // Use material name as test name
        materialName: _materialNameController.text,
        composition:
            _compositionController.text.isEmpty
                ? null
                : _compositionController.text,
        testDate: DateTime.now(), // Default to today
        result: null, // No initial result
        status: 'active', // Always start as active
        createdAt: DateTime.now(),
        completedAt: null,
      );

      await _labTestService.createTest(test);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test material created successfully')),
        );
        Navigator.of(context).pop();
        widget.onTestAdded();
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating test: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.science, color: Colors.blue[700]),
          const SizedBox(width: 8),
          const Text('Add New Test'),
        ],
      ),
      content: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Test Details',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _materialNameController,
                decoration: InputDecoration(
                  labelText: 'Test Name *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.science_outlined),
                  hintText: 'e.g. Raw Material Batch #123',
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _compositionController,
                decoration: InputDecoration(
                  labelText: 'Composition (Optional)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.list_alt),
                  hintText: 'e.g. 70% Polymer, 30% Filler',
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Text(
                'You can add specific sub-tests (e.g. pH, Moisture) after creating this entry.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          child:
              _isSaving
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Create'),
        ),
      ],
    );
  }
}

// Add Test Dialog
class AddSubTestDialog extends StatefulWidget {
  final int labTestId;
  final VoidCallback onSubTestAdded;

  const AddSubTestDialog({
    super.key,
    required this.labTestId,
    required this.onSubTestAdded,
  });

  @override
  State<AddSubTestDialog> createState() => _AddSubTestDialogState();
}

class _AddSubTestDialogState extends State<AddSubTestDialog> {
  final LabTestService _labTestService = LabTestService();
  final TextEditingController _testNameController = TextEditingController();
  final TextEditingController _resultController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _testNameController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_testNameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a test name')));
      return;
    }

    if (_resultController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a test result')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final subTest = SubTest(
        labTestId: widget.labTestId,
        testName: _testNameController.text,
        testDate: _selectedDate,
        result: _resultController.text,
      );

      await _labTestService.createSubTest(subTest);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test added successfully')),
        );
      }
      widget.onSubTestAdded();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding test: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Test'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _testNameController,
              decoration: const InputDecoration(
                labelText: 'Test Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.science),
                hintText: 'e.g. pH Test, Moisture Test',
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.grey[700]),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('MMM dd, yyyy').format(_selectedDate),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _resultController,
              decoration: const InputDecoration(
                labelText: 'Test Result',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.assignment_turned_in_outlined),
                hintText: 'e.g. Pass / Fail / 7.2 pH',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          child:
              _isSaving
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Add'),
        ),
      ],
    );
  }
}
