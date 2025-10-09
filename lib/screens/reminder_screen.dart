import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../db/reminder_db.dart';
import '../services/notification_service.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<Map<String, dynamic>> _allReminders = [];
  List<Map<String, dynamic>> _selectedDayReminders = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initSetup();
  }

  Future<void> _initSetup() async {
    await NotificationService.instance.initialize();
    await _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    try {
      final reminders = await ReminderDb.instance.getReminders();
      if (!mounted) return;
      setState(() {
        _allReminders = reminders;
        _selectedDayReminders = _getRemindersForDay(_selectedDay);
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getRemindersForDay(DateTime day) {
    return _allReminders.where((reminder) {
      final reminderDate = DateTime.tryParse(reminder['dateTime'] ?? '');
      return reminderDate != null && isSameDay(reminderDate, day);
    }).toList();
  }

  Future<void> _addReminder() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddReminderDialog(selectedDate: _selectedDay),
    );

    if (result != null) {
      final id = DateTime.now().microsecondsSinceEpoch.remainder(1 << 31);
      final reminder = {
        'title': result['title'],
        'description': result['description'],
        'dateTime': result['dateTime'].toIso8601String(),
        'isCompleted': 0,
        'notificationId': id,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await ReminderDb.instance.createReminder(reminder);

      await NotificationService.instance.scheduleReminder(
        id: id,
        title: result['title'],
        body: result['description']?.isNotEmpty == true
            ? result['description']
            : 'You have a reminder!',
        scheduledTime: result['dateTime'],
      );

      if (!mounted) return;
      await _loadReminders();
    }
  }

  Future<void> _toggleComplete(int id, bool currentStatus) async {
    await ReminderDb.instance.toggleComplete(id, !currentStatus);
    if (mounted) _loadReminders();
  }

  Future<void> _deleteReminder(int id, int notificationId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Reminder'),
        content: const Text('Are you sure you want to delete this reminder?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ReminderDb.instance.deleteReminder(id);
      await NotificationService.instance.cancelNotification(notificationId);
      if (mounted) _loadReminders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final surfaceColor = theme.colorScheme.surface;
    final cardColor = theme.cardColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(
          'Reminders',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Calendar
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                  _selectedDayReminders = _getRemindersForDay(selectedDay);
                });
              },
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              eventLoader: _getRemindersForDay,
              calendarStyle: CalendarStyle(
                defaultTextStyle: TextStyle(color: theme.colorScheme.onSurface),
                weekendTextStyle: TextStyle(
                  color: isDark ? Colors.redAccent.shade100 : Colors.red,
                ),
                outsideTextStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                ),
                todayDecoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: isDark
                      ? Colors.pinkAccent.shade100
                      : Colors.pinkAccent,
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
                selectedTextStyle: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
                titleTextStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                formatButtonTextStyle: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
                formatButtonDecoration: BoxDecoration(
                  border: Border.all(color: primaryColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: theme.colorScheme.onSurface,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  fontWeight: FontWeight.bold,
                ),
                weekendStyle: TextStyle(
                  color: isDark ? Colors.redAccent.shade100 : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Reminders for ${DateFormat('MMM dd, yyyy').format(_selectedDay)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${_selectedDayReminders.length} items',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : _selectedDayReminders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 80,
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No reminders for this day',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _selectedDayReminders.length,
                    itemBuilder: (context, index) {
                      final reminder = _selectedDayReminders[index];
                      final dateTime = DateTime.tryParse(
                        reminder['dateTime'] ?? '',
                      );
                      if (dateTime == null) return const SizedBox.shrink();
                      final isCompleted = reminder['isCompleted'] == 1;
                      final isExpired = dateTime.isBefore(DateTime.now());

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: theme.colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        elevation: isDark ? 4 : 2,
                        shadowColor: isDark
                            ? Colors.black.withOpacity(0.5)
                            : Colors.black.withOpacity(0.1),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: GestureDetector(
                            onTap: () =>
                                _toggleComplete(reminder['id'], isCompleted),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isCompleted
                                      ? Colors.green
                                      : theme.colorScheme.outline,
                                  width: 2,
                                ),
                                color: isCompleted
                                    ? Colors.green
                                    : Colors.transparent,
                              ),
                              child: isCompleted
                                  ? const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                          title: Text(
                            reminder['title'],
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isCompleted
                                  ? theme.colorScheme.onSurface.withOpacity(0.5)
                                  : (isExpired
                                        ? (isDark
                                              ? Colors.redAccent.shade100
                                              : Colors.redAccent)
                                        : theme.colorScheme.onSurface),
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (reminder['description'] != null &&
                                  reminder['description'].isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    reminder['description'],
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('hh:mm a').format(dateTime),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.delete,
                              color: isDark
                                  ? Colors.redAccent.shade100
                                  : Colors.redAccent,
                            ),
                            onPressed: () => _deleteReminder(
                              reminder['id'],
                              reminder['notificationId'],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addReminder,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Reminder',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

//  Add Reminder Dialog
class _AddReminderDialog extends StatefulWidget {
  final DateTime selectedDate;
  const _AddReminderDialog({required this.selectedDate});

  @override
  State<_AddReminderDialog> createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends State<_AddReminderDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedTime = TimeOfDay.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return AlertDialog(
      backgroundColor: theme.dialogBackgroundColor,
      title: Text(
        'New Reminder',
        style: TextStyle(color: theme.colorScheme.onSurface),
      ),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: theme.colorScheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                prefixIcon: Icon(Icons.title, color: primaryColor),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                labelStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: theme.colorScheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                prefixIcon: Icon(Icons.description, color: primaryColor),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.5),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: Icon(Icons.access_time, color: primaryColor),
                title: Text(
                  'Time',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                subtitle: Text(
                  _selectedTime.format(context),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                onTap: _pickTime,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Please enter a title'),
                  backgroundColor: theme.colorScheme.error,
                ),
              );
              return;
            }

            final dateTime = DateTime(
              widget.selectedDate.year,
              widget.selectedDate.month,
              widget.selectedDate.day,
              _selectedTime.hour,
              _selectedTime.minute,
            );

            Navigator.pop(context, {
              'title': _titleController.text.trim(),
              'description': _descriptionController.text.trim(),
              'dateTime': dateTime,
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
