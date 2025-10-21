import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'login.dart';

class InternDashboard extends StatefulWidget {
  @override
  _InternDashboardState createState() => _InternDashboardState();
}

class _InternDashboardState extends State<InternDashboard> {
  String userName = '';
  String userRole = 'Intern';
  int selectedTab = 0;

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  void loadUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('user_name') ?? 'Intern';
      userRole = prefs.getString('user_role') ?? 'intern';
    });
  }

  void _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String todayDate = DateFormat('EEEE, MMMM d, y').format(DateTime.now());
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, $userName ($userRole)', 
                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(todayDate, 
                 style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedTab,
            onDestinationSelected: (int index) {
              setState(() => selectedTab = index);
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.blue[50],
            selectedIconTheme: IconThemeData(color: Colors.blue[700]),
            selectedLabelTextStyle: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold),
            destinations: [
              NavigationRailDestination(
                icon: Icon(Icons.book),
                label: Text('Logbook'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history),
                label: Text('Past Logs'),
              ),
            ],
          ),
          VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: selectedTab == 0
                ? LogbookEntryWidget()
                : PastLogsWidget(),
          ),
        ],
      ),
    );
  }
}

// ==================== LOGBOOK ENTRY WIDGET ====================
class LogbookEntryWidget extends StatefulWidget {
  @override
  _LogbookEntryWidgetState createState() => _LogbookEntryWidgetState();
}

class _LogbookEntryWidgetState extends State<LogbookEntryWidget> {
  final _todaysWorkController = TextEditingController();
  final _challengesController = TextEditingController();
  final _tomorrowPlanController = TextEditingController();
  
  String _selectedStatus = 'Working';
  String _selectedTaskStack = 'Frontend';
  bool _loading = false;
  bool _hasSubmittedToday = false;

  final List<String> _statusOptions = ['Working', 'WFH', 'Leave'];
  final List<String> _taskStackOptions = [
    'Frontend',
    'Backend',
    'DataScience',
    'UIUX',
    'DevOps',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _checkTodaySubmission();
  }

  void _checkTodaySubmission() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final response = await ApiService.getRequest('/intern/logbook?date=$today');
    
    if (response['success'] && response['logs'] != null && response['logs'].isNotEmpty) {
      setState(() {
        _hasSubmittedToday = true;
      });
    }
  }

  void _submitLogbook() async {
    // Validate form
    if (_todaysWorkController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter today\'s work'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _loading = true);

    final response = await ApiService.postRequest('/intern/logbook', {
      'status': _selectedStatus,
      'task_stack': _selectedTaskStack,
      'todays_work': _todaysWorkController.text.trim(),
      'challenges': _challengesController.text.trim(),
      'tomorrow_plan': _tomorrowPlanController.text.trim(),
    });

    setState(() => _loading = false);

    if (response['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logbook submitted successfully!'), backgroundColor: Colors.green),
      );
      _todaysWorkController.clear();
      _challengesController.clear();
      _tomorrowPlanController.clear();
      setState(() => _hasSubmittedToday = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Failed to submit'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String todayFormatted = DateFormat('EEEE, MMMM d, y').format(DateTime.now());
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 800),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_note, size: 32, color: Colors.blue[700]),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Logbook Entry',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              todayFormatted,
                              style: TextStyle(color: Colors.blue[700], fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  if (_hasSubmittedToday) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[700], size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Already Submitted',
                                  style: TextStyle(
                                    color: Colors.green[900],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'You have already submitted your logbook for today. Check "Past Logs" to view.',
                                  style: TextStyle(color: Colors.green[800], fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  SizedBox(height: 24),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Note: You can only submit today\'s log. Past or future entries are not allowed.',
                            style: TextStyle(color: Colors.blue[900], fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Divider(height: 32),
                  
                  Text('Status *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Row(
                    children: _statusOptions.map((status) {
                      return Expanded(
                        child: RadioListTile<String>(
                          title: Text(status),
                          value: status,
                          groupValue: _selectedStatus,
                          onChanged: _hasSubmittedToday ? null : (value) {
                            setState(() => _selectedStatus = value!);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  
                  SizedBox(height: 24),
                  Text('Task Stack *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedTaskStack,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.work),
                    ),
                    items: _taskStackOptions.map((stack) {
                      return DropdownMenuItem(value: stack, child: Text(stack));
                    }).toList(),
                    onChanged: _hasSubmittedToday ? null : (value) {
                      setState(() => _selectedTaskStack = value!);
                    },
                  ),
                  
                  SizedBox(height: 24),
                  Text('Today\'s Work *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  TextField(
                    controller: _todaysWorkController,
                    maxLines: 4,
                    enabled: !_hasSubmittedToday,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Describe what you worked on today...',
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  Text('Challenges (Optional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  TextField(
                    controller: _challengesController,
                    maxLines: 3,
                    enabled: !_hasSubmittedToday,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Any challenges or blockers you faced...',
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  Text('Tomorrow\'s Plan (Optional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  TextField(
                    controller: _tomorrowPlanController,
                    maxLines: 3,
                    enabled: !_hasSubmittedToday,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'What do you plan to work on tomorrow...',
                    ),
                  ),
                  
                  SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_loading || _hasSubmittedToday) ? null : _submitLogbook,
                      icon: _loading ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ) : Icon(Icons.send),
                      label: Text(
                        _hasSubmittedToday ? 'Already Submitted Today' : (_loading ? 'Submitting...' : 'Submit Logbook'),
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: _hasSubmittedToday ? Colors.grey : Colors.blue[700],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== PAST LOGS WIDGET ====================
class PastLogsWidget extends StatefulWidget {
  @override
  _PastLogsWidgetState createState() => _PastLogsWidgetState();
}

class _PastLogsWidgetState extends State<PastLogsWidget> {
  List<dynamic> _logs = [];
  List<dynamic> _filteredLogs = [];
  DateTime? _selectedDate;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    
    String url = '/intern/logbook';
    if (_selectedDate != null) {
      url += '?date=${DateFormat('yyyy-MM-dd').format(_selectedDate!)}';
    }
    
    final response = await ApiService.getRequest(url);
    
    setState(() {
      _loading = false;
      if (response['success']) {
        _logs = response['logs'] ?? [];
        _filteredLogs = _logs;
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select Date to Filter Logs',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue[700]!,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _loadLogs();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDate = null;
    });
    _loadLogs();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Working':
        return Colors.green;
      case 'WFH':
        return Colors.blue;
      case 'Leave':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getTaskStackColor(String taskStack) {
    switch (taskStack) {
      case 'Frontend':
        return Colors.purple;
      case 'Backend':
        return Colors.indigo;
      case 'DataScience':
        return Colors.teal;
      case 'UIUX':
        return Colors.pink;
      case 'DevOps':
        return Colors.deepOrange;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.history, size: 28, color: Colors.blue[700]),
              SizedBox(width: 12),
              Text('Past Logs', 
                   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              if (_logs.isNotEmpty) ...[
                SizedBox(width: 12),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_filteredLogs.length} entries',
                    style: TextStyle(
                      color: Colors.blue[900],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              Spacer(),
              if (_selectedDate != null) ...[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.blue[900]),
                      SizedBox(width: 8),
                      Text(
                        DateFormat('MMM d, yyyy').format(_selectedDate!),
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      InkWell(
                        onTap: _clearDateFilter,
                        child: Icon(Icons.clear, size: 16, color: Colors.blue[900]),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
              ],
              ElevatedButton.icon(
                onPressed: () => _selectDate(context),
                icon: Icon(Icons.calendar_month),
                label: Text('Select Date'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _loadLogs,
                icon: Icon(Icons.refresh),
                label: Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator())
              : _filteredLogs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.grey[400]),
                          SizedBox(height: 16),
                          Text(
                            _selectedDate != null 
                                ? 'No logs found for selected date' 
                                : 'No logs found',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                          if (_selectedDate != null) ...[
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _clearDateFilter,
                              child: Text('Clear Filter'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _filteredLogs.length,
                      itemBuilder: (context, index) {
                        final log = _filteredLogs[index];
                        final logDate = DateTime.parse(log['date']);
                        final isToday = logDate.year == DateTime.now().year &&
                                       logDate.month == DateTime.now().month &&
                                       logDate.day == DateTime.now().day;
                        
                        return Card(
                          margin: EdgeInsets.only(bottom: 16),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isToday 
                                ? BorderSide(color: Colors.blue[700]!, width: 2)
                                : BorderSide.none,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.calendar_today, 
                                                  size: 20, 
                                                  color: Colors.blue[900]),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            DateFormat('EEEE, MMMM d, y').format(logDate),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (isToday)
                                            Text(
                                              'Today\'s Entry',
                                              style: TextStyle(
                                                color: Colors.blue[700],
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(log['status']).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            log['status'] == 'Working' 
                                                ? Icons.work 
                                                : log['status'] == 'WFH' 
                                                    ? Icons.home 
                                                    : Icons.event_busy,
                                            size: 14,
                                            color: _getStatusColor(log['status']),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            log['status'],
                                            style: TextStyle(
                                              color: _getStatusColor(log['status']),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _getTaskStackColor(log['task_stack']).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        log['task_stack'],
                                        style: TextStyle(
                                          color: _getTaskStackColor(log['task_stack']),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Divider(height: 24),
                                _buildSection('Today\'s Work', log['todays_work'], Icons.work_outline),
                                if (log['challenges'] != null && log['challenges'].toString().isNotEmpty) ...[
                                  SizedBox(height: 16),
                                  _buildSection('Challenges', log['challenges'], Icons.warning_amber_outlined),
                                ],
                                if (log['tomorrow_plan'] != null && log['tomorrow_plan'].toString().isNotEmpty) ...[
                                  SizedBox(height: 16),
                                  _buildSection('Tomorrow\'s Plan', log['tomorrow_plan'], Icons.assignment_outlined),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, String? content, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.blue[700]),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            content ?? 'N/A',
            style: TextStyle(color: Colors.grey[800], fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}
