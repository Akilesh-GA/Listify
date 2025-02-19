import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  tz.initializeTimeZones();
  runApp(ListifyApp());
}

class ListifyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Listify',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: AppBarTheme(
          color: Colors.blue,
        ),
      ),
      home: TodoListScreen(),
    );
  }
}

class TodoListScreen extends StatefulWidget {
  @override
  _TodoListScreenState createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  final TextEditingController _taskController = TextEditingController();
  DateTime? _selectedDeadline;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  void _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tapped logic here
      },
    );
  }

  Future<void> _scheduleNotification(String task, DateTime deadline) async {
    final DateTime scheduledTime = deadline.subtract(Duration(hours: 2));
    final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'your_channel_id',
      'your_channel_name',
      channelDescription: 'your_channel_description',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Task Reminder',
      'The task "$task" is due in 2 hours',
      tzScheduledTime,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.inexact,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  void _addTodoItem(String task, DateTime deadlineDateTime) async {
    if (task.isNotEmpty) {
      await _firestore.collection('todos').add({
        'task': task,
        'deadline': deadlineDateTime,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _scheduleNotification(task, deadlineDateTime);
      _taskController.clear();
      _selectedDeadline = null;
    }
  }

  void _deleteTodoItem(String docId) async {
    await _firestore.collection('todos').doc(docId).delete();
  }

  Widget _buildTodoItem(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>?;
    var deadlineTimestamp = data != null && data.containsKey('deadline') ? doc['deadline'] : null;
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: ListTile(
        title: Text(doc['task']),
        subtitle: Text(deadlineTimestamp != null
            ? 'Deadline: ${deadlineTimestamp.toDate()}'
            : 'No deadline set'),
        trailing: IconButton(
          icon: Icon(Icons.delete, color: Colors.grey),
          onPressed: () => _deleteTodoItem(doc.id),
        ),
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: BorderSide(color: Colors.lightBlue, width: 2.0),
        ),
      ),
    );
  }

  Future<void> _selectDeadline(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDeadline = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  void _promptAddTodoItem() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('New Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _taskController,
                decoration: InputDecoration(hintText: 'Task'),
                autofocus: true,
              ),
              SizedBox(height: 16.0),
              TextButton(
                onPressed: () => _selectDeadline(context),
                child: Text(
                  _selectedDeadline == null
                      ? 'Select Deadline'
                      : 'Deadline: ${_selectedDeadline!.toLocal()}'.split(' ')[0],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                _taskController.clear();
                setState(() {
                  _selectedDeadline = null;
                });
              },
            ),
            TextButton(
              child: Text('Add'),
              onPressed: () {
                final task = _taskController.text;
                if (_selectedDeadline != null) {
                  _addTodoItem(task, _selectedDeadline!);
                  Navigator.of(context).pop();
                } else {
                  // Show an error message if the deadline is not selected
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please select a deadline')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Listify'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => setState(() {}), // Refresh the list
          ),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('todos').orderBy('timestamp', descending: false).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      return _buildTodoItem(docs[index]);
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16.0),
              margin: const EdgeInsets.only(bottom: 32.0), // Increase bottom margin
              child: ElevatedButton(
                onPressed: _promptAddTodoItem,
                child: Text('Add Task'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0), // Increase button size
                  textStyle: TextStyle(fontSize: 18.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0), // Rectangle with rounded corners
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
