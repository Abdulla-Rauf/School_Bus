// lib/screens/calendar/add_event_dialog.dart
import 'package:flutter/material.dart';

import '../../../../models/calendar_model.dart';
import '../../../../models/school_config_model.dart';
import '../../../../models/teacher_model.dart';
import '../../../../models/user_model.dart';

class AddEventDialog extends StatefulWidget {
  final UserModel user;
  final Teacher? teacher;
  final SchoolConfig? schoolConfig;
  final List<String> teacherClasses;
  final Function(CalendarEvent) onEventAdded;
  final CalendarEvent? existingEvent;
  final SchoolCalendar? schoolCalendar;

  const AddEventDialog({
    super.key,
    required this.user,
    this.teacher,
    this.schoolConfig,
    required this.teacherClasses,
    required this.onEventAdded,
    this.existingEvent,
    this.schoolCalendar,
  });

  @override
  _AddEventDialogState createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  late EventType _selectedType;
  late DateTime _startDate;
  late DateTime _endDate;
  late bool _isFullDay;
  late List<String> _selectedClasses;
  late bool _allClasses;

  @override
  void initState() {
    super.initState();

    if (widget.existingEvent != null) {
      _titleController.text = widget.existingEvent!.title;
      _descriptionController.text = widget.existingEvent!.description;
      _selectedType = widget.existingEvent!.type;
      _startDate = widget.existingEvent!.startDate;
      _endDate = widget.existingEvent!.endDate;
      _isFullDay = widget.existingEvent!.isFullDay;
      _selectedClasses = List.from(widget.existingEvent!.affectedClasses);
      _allClasses = widget.existingEvent!.isForAllClasses;
    } else {
      _selectedType = EventType.event;
      _startDate = DateTime.now();
      _endDate = DateTime.now();
      _isFullDay = true;
      _selectedClasses = [];
      _allClasses = true;

      if (widget.user.role == 'teacher' &&
          widget.teacher != null &&
          widget.teacher!.primaryClass.isNotEmpty) {
        _allClasses = false;
        _selectedClasses = [widget.teacher!.primaryClass];
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool _isWorkingDay(DateTime date) {
    if (widget.schoolCalendar == null) {
      return date.weekday <= 5;
    }

    final dayOfWeek = date.weekday;
    final workingDay = widget.schoolCalendar!.workingDays.firstWhere(
      (wd) => wd.dayOfWeek == dayOfWeek,
      orElse: () => WorkingDay(dayOfWeek: dayOfWeek, isWorkingDay: false),
    );

    return workingDay.isWorkingDay;
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  List<String> _getAvailableClasses() {
    if (widget.user.role == 'teacher') {
      return widget.teacherClasses.where((c) => c.isNotEmpty).toList();
    } else if (widget.schoolConfig != null) {
      List<String> allClasses = [];
      for (var schoolClass in widget.schoolConfig!.classes) {
        allClasses.addAll(schoolClass.getFullClassNames());
      }
      return allClasses..sort();
    }
    return [];
  }

  void _saveEvent() {
    if (_formKey.currentState!.validate()) {
      if (_endDate.isBefore(_startDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End date cannot be before start date')),
        );
        return;
      }

      CalendarEvent event = CalendarEvent(
        id:
            widget.existingEvent?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        startDate: _startDate,
        endDate: _endDate,
        isFullDay: _isFullDay,
        affectedClasses: _allClasses ? [] : _selectedClasses,
        createdBy: widget.user.role == 'teacher' ? 'teacher' : 'school',
        creatorId: widget.user.specificId,
        creatorName: widget.user.name,
        color: null,
        createdAt: widget.existingEvent?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      widget.onEventAdded(event);
      Navigator.pop(context);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final availableClasses = _getAvailableClasses();

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        width: MediaQuery.of(context).size.width * 0.9,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existingEvent != null
                    ? 'Edit Calendar Event'
                    : 'Add Calendar Event',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),

              // Event Type
              DropdownButtonFormField<EventType>(
                initialValue: _selectedType,
                decoration: InputDecoration(
                  labelText: 'Event Type',
                  labelStyle: const TextStyle(color: Colors.black54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black87),
                  ),
                ),
                items: EventType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(
                      type.toString().split('.').last,
                      style: const TextStyle(color: Colors.black87),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Event Title',
                  labelStyle: const TextStyle(color: Colors.black54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black87),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter event title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: const TextStyle(color: Colors.black54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black87),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Date Range
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Start Date',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[100],
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _selectDate(context, true),
                          child: Text(_formatDate(_startDate)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'End Date',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[100],
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _selectDate(context, false),
                          child: Text(_formatDate(_endDate)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Working Day Indicator
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isWorkingDay(_startDate)
                      ? Colors.green[50]
                      : Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isWorkingDay(_startDate)
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isWorkingDay(_startDate)
                          ? Icons.work
                          : Icons.beach_access,
                      color: _isWorkingDay(_startDate)
                          ? Colors.green
                          : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isWorkingDay(_startDate)
                            ? 'Selected date is a working day'
                            : 'Selected date is a holiday/weekend',
                        style: TextStyle(
                          color: _isWorkingDay(_startDate)
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Affected Classes
              if (availableClasses.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _allClasses,
                          onChanged: (value) {
                            setState(() {
                              _allClasses = value ?? false;
                              if (_allClasses) {
                                _selectedClasses.clear();
                              } else if (widget.user.role == 'teacher' &&
                                  widget.teacher != null) {
                                _selectedClasses = [
                                  widget.teacher!.primaryClass,
                                ];
                              }
                            });
                          },
                        ),
                        const Text(
                          'For All Classes',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (!_allClasses) ...[
                      const Text(
                        'Select Specific Classes:',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: availableClasses.map((className) {
                          bool isSelected = _selectedClasses.contains(
                            className,
                          );
                          return FilterChip(
                            label: Text(
                              className,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            selected: isSelected,
                            backgroundColor: Colors.grey[100],
                            selectedColor: Colors.black87,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedClasses.add(className);
                                } else {
                                  _selectedClasses.remove(className);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _saveEvent,
                      child: Text(
                        widget.existingEvent != null
                            ? 'Update Event'
                            : 'Add Event',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
