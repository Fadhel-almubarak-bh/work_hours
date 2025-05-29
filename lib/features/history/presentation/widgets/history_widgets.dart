import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EditEntryDialog extends StatefulWidget {
  final String entryKey;
  final DateTime? clockInTime;
  final DateTime? clockOutTime;
  final bool isOffDay;
  final String? offDayDescription;

  const EditEntryDialog({
    super.key,
    required this.entryKey,
    this.clockInTime,
    this.clockOutTime,
    this.isOffDay = false,
    this.offDayDescription,
  });

  @override
  State<EditEntryDialog> createState() => _EditEntryDialogState();
}

class _EditEntryDialogState extends State<EditEntryDialog> {
  late bool _isOffDay;
  late TextEditingController _descriptionController;
  late TimeOfDay _clockInTime;
  late TimeOfDay _clockOutTime;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _isOffDay = widget.isOffDay;
    _descriptionController = TextEditingController(text: widget.offDayDescription);
    _selectedDate = DateFormat('yyyy-MM-dd').parse(widget.entryKey);
    
    // Initialize time values
    if (widget.clockInTime != null) {
      _clockInTime = TimeOfDay.fromDateTime(widget.clockInTime!);
    } else {
      _clockInTime = TimeOfDay.now();
    }
    
    if (widget.clockOutTime != null) {
      _clockOutTime = TimeOfDay.fromDateTime(widget.clockOutTime!);
    } else {
      _clockOutTime = TimeOfDay.now();
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context, bool isClockIn) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isClockIn ? _clockInTime : _clockOutTime,
    );
    if (picked != null) {
      setState(() {
        if (isClockIn) {
          _clockInTime = picked;
        } else {
          _clockOutTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Entry'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Off Day'),
              value: _isOffDay,
              onChanged: (bool value) {
                setState(() {
                  _isOffDay = value;
                });
              },
            ),
            if (_isOffDay)
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter reason for off day',
                ),
                maxLines: 2,
              )
            else ...[
              ListTile(
                title: const Text('Clock In Time'),
                subtitle: Text(_clockInTime.format(context)),
                trailing: const Icon(Icons.access_time),
                onTap: () => _selectTime(context, true),
              ),
              ListTile(
                title: const Text('Clock Out Time'),
                subtitle: Text(_clockOutTime.format(context)),
                trailing: const Icon(Icons.access_time),
                onTap: () => _selectTime(context, false),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final result = <String, dynamic>{
              'isOffDay': _isOffDay,
            };

            if (_isOffDay) {
              result['description'] = _descriptionController.text;
            } else {
              // Create DateTime objects for the selected date and times
              final clockInDateTime = DateTime(
                _selectedDate.year,
                _selectedDate.month,
                _selectedDate.day,
                _clockInTime.hour,
                _clockInTime.minute,
              );
              final clockOutDateTime = DateTime(
                _selectedDate.year,
                _selectedDate.month,
                _selectedDate.day,
                _clockOutTime.hour,
                _clockOutTime.minute,
              );

              result['clockInTime'] = clockInDateTime;
              result['clockOutTime'] = clockOutDateTime;
            }

            Navigator.pop(context, result);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
