import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'goal_providers.dart';
import '../../../core/constants/app_colors.dart';

class GoalCreationScreen extends ConsumerStatefulWidget {
  const GoalCreationScreen({super.key});

  @override
  ConsumerState<GoalCreationScreen> createState() => _GoalCreationScreenState();
}

class _GoalCreationScreenState extends ConsumerState<GoalCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _targetValueController = TextEditingController();
  final _unitController = TextEditingController();
  final _customCategoryController = TextEditingController();

  String _selectedCategory = 'Fitness';
  String _selectedFrequency = 'Daily';
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _enableReminders = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 8, minute: 0);

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Fitness', 'icon': Icons.directions_run, 'defaultUnit': 'km'},
    {'name': 'Reading', 'icon': Icons.menu_book, 'defaultUnit': 'pages'},
    {'name': 'Hydration', 'icon': Icons.local_drink, 'defaultUnit': 'liters'},
    {'name': 'Health', 'icon': Icons.spa, 'defaultUnit': 'minutes'},
    {'name': 'Study', 'icon': Icons.school, 'defaultUnit': 'hours'},
    {'name': 'Others', 'icon': Icons.more_horiz, 'defaultUnit': 'times'},
  ];

  @override
  void initState() {
    super.initState();
    _unitController.text = 'km'; // Default fitness unit
    // Set default end date to tomorrow (1 day after start date)
    _endDate = _startDate.add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetValueController.dispose();
    _unitController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  void _onCategoryChanged(String name, String defaultUnit) {
    setState(() {
      _selectedCategory = name;
      _unitController.text = defaultUnit;
    });
  }

  void _onFrequencyChanged(String freq) {
    setState(() {
      _selectedFrequency = freq;
      if (freq == 'Weekly') {
        _endDate = _startDate.add(const Duration(days: 7));
      } else if (freq == 'Monthly') {
        _endDate = _startDate.add(const Duration(days: 30));
      } else {
        // Daily: user must manually select, default to 1 day after start date
        _endDate = _startDate.add(const Duration(days: 1));
      }
    });
  }

  Future<void> _selectStartDate() async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate.isBefore(today) ? today : _startDate,
      firstDate: today,
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Automatically adjust End Date based on new Start Date
        if (_selectedFrequency == 'Weekly') {
          _endDate = _startDate.add(const Duration(days: 7));
        } else if (_selectedFrequency == 'Monthly') {
          _endDate = _startDate.add(const Duration(days: 30));
        } else {
          // Daily: adjust only if current end date is before new start date
          if (_endDate != null && _endDate!.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final initialDate = _endDate ?? _startDate.add(
      _selectedFrequency == 'Weekly'
          ? const Duration(days: 7)
          : (_selectedFrequency == 'Monthly' ? const Duration(days: 30) : const Duration(days: 1)),
    );

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(_startDate) ? _startDate : initialDate,
      firstDate: _startDate,
      lastDate: DateTime(2030),
      selectableDayPredicate: (DateTime date) {
        // Do not allow past dates or dates earlier than start date
        if (date.isBefore(_startDate)) return false;

        final cleanDate = DateTime(date.year, date.month, date.day);
        final cleanStart = DateTime(_startDate.year, _startDate.month, _startDate.day);
        final diffInDays = cleanDate.difference(cleanStart).inDays;

        if (_selectedFrequency == 'Weekly') {
          return diffInDays > 0 && diffInDays % 7 == 0;
        } else if (_selectedFrequency == 'Monthly') {
          return diffInDays > 0 && diffInDays % 30 == 0;
        }
        return true; // Daily
      },
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _selectReminderTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked != null) {
      setState(() {
        _reminderTime = picked;
      });
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an End Date'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final cleanStart = DateTime(_startDate.year, _startDate.month, _startDate.day);
      final cleanEnd = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
      final diffInDays = cleanEnd.difference(cleanStart).inDays;

      if (cleanEnd.isBefore(cleanStart)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End Date cannot be earlier than Start Date'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (_selectedFrequency == 'Weekly' && (diffInDays == 0 || diffInDays % 7 != 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Weekly goals must have an End Date in 7-day intervals from the Start Date'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (_selectedFrequency == 'Monthly' && (diffInDays == 0 || diffInDays % 30 != 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Monthly goals must have an End Date in 30-day intervals from the Start Date'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final categoryToSubmit = _selectedCategory == 'Others'
          ? (_customCategoryController.text.trim().isNotEmpty
              ? _customCategoryController.text.trim()
              : 'Others')
          : _selectedCategory;

      final reminderTimeStr = _enableReminders
          ? "${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}"
          : null;

      await ref.read(goalControllerProvider.notifier).createGoal(
        title: _titleController.text.trim(),
        category: categoryToSubmit,
        targetValue: double.parse(_targetValueController.text),
        unit: _unitController.text.trim(),
        frequency: _selectedFrequency,
        endDate: _endDate,
        reminderTime: reminderTimeStr,
      );

      if (mounted) {
        if (ref.read(goalControllerProvider).hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${ref.read(goalControllerProvider).error}'),
              backgroundColor: AppColors.danger,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Goal Created & Match Found!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final goalState = ref.watch(goalControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Goal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Title Input
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Goal Title',
                    hintText: 'e.g. Run 6 km, Drink water, Read books',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Goal Title is required';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // 2. Category Row List
                Text(
                  'Select Category',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = _selectedCategory == cat['name'];
                      return GestureDetector(
                        onTap: () => _onCategoryChanged(cat['name'], cat['defaultUnit']),
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                cat['icon'],
                                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                cat['name'],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                if (_selectedCategory == 'Others') ...[
                  TextFormField(
                    controller: _customCategoryController,
                    decoration: InputDecoration(
                      labelText: 'Custom Category Name',
                      hintText: 'e.g. Meditate, Pushups, Coding',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (val) {
                      if (_selectedCategory == 'Others' && (val == null || val.trim().isEmpty)) {
                        return 'Custom Category Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                // 3. Target Value and Unit Inputs
                Row(
                  children: [
                    // Target Value
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _targetValueController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Target Value',
                          hintText: 'e.g. 6, 10, 3',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          if (double.tryParse(val) == null || double.parse(val) <= 0) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Unit
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _unitController,
                        readOnly: _selectedCategory != 'Others',
                        decoration: InputDecoration(
                          labelText: 'Unit',
                          hintText: 'e.g. km, pages, liters',
                          filled: _selectedCategory != 'Others',
                          fillColor: _selectedCategory != 'Others'
                              ? theme.colorScheme.onSurface.withAlpha(15)
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          helperText: _selectedCategory != 'Others' ? 'Locked to category' : 'Custom unit',
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 4. Frequency Segment Selector
                Text(
                  'Frequency',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Daily', label: Text('Daily')),
                    ButtonSegment(value: 'Weekly', label: Text('Weekly')),
                    ButtonSegment(value: 'Monthly', label: Text('Monthly')),
                  ],
                  selected: {_selectedFrequency},
                  onSelectionChanged: (newSelection) {
                    _onFrequencyChanged(newSelection.first);
                  },
                ),
                const SizedBox(height: 24),

                // 5. Calendar Date Selection
                Text(
                  'Duration',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Start Date
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectStartDate,
                        icon: const Icon(Icons.calendar_month, size: 16),
                        label: Text(
                          'Start: ${_startDate.day}/${_startDate.month}/${_startDate.year % 100}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // End Date
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectEndDate,
                        icon: const Icon(Icons.calendar_month, size: 16),
                        label: Text(
                          _endDate == null 
                              ? 'End: Open' 
                              : 'End: ${_endDate!.day}/${_endDate!.month}/${_endDate!.year % 100}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // 6. Reminder Settings
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daily Reminders',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Switch(
                      value: _enableReminders,
                      onChanged: (val) {
                        setState(() {
                          _enableReminders = val;
                        });
                      },
                    ),
                  ],
                ),
                if (_enableReminders) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _selectReminderTime,
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text(
                        'Reminder Time: ${_reminderTime.format(context)}',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 48),

                // 6. Action Button
                ElevatedButton(
                  onPressed: goalState.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: goalState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save and Sync Competitors', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
