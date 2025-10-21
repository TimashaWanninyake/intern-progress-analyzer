import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/ai_service.dart';
import 'login.dart';

class SupervisorDashboard extends StatefulWidget {
  @override
  _SupervisorDashboardState createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  int selectedTab = 0;
  String userName = '';
  String userRole = 'Supervisor';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  void _loadUserInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('user_name') ?? 'Supervisor';
      userRole = prefs.getString('user_role') ?? 'supervisor';
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
        backgroundColor: Colors.orange[700],
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
            backgroundColor: Colors.orange[50],
            selectedIconTheme: IconThemeData(color: Colors.orange[700]),
            selectedLabelTextStyle: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.bold),
            destinations: [
              NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text('View Interns'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.folder),
                label: Text('View Projects'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.smart_toy),
                label: Text('AI Reports'),
              ),
            ],
          ),
          VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: selectedTab == 0
                ? ViewInternsWidget()
                : selectedTab == 1
                    ? ViewProjectsWidget()
                    : AIReportsWidget(),
          ),
        ],
      ),
    );
  }
}

// ==================== VIEW INTERNS WIDGET ====================
class ViewInternsWidget extends StatefulWidget {
  @override
  _ViewInternsWidgetState createState() => _ViewInternsWidgetState();
}

class _ViewInternsWidgetState extends State<ViewInternsWidget> {
  List<dynamic> _interns = [];
  List<dynamic> _filteredInterns = [];
  List<dynamic> _projects = [];
  bool _loading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    setState(() => _loading = true);
    
    final internsResponse = await ApiService.getRequest('/supervisor/interns');
    final projectsResponse = await ApiService.getRequest('/projects');
    
    setState(() {
      _loading = false;
      if (internsResponse['success']) {
        _interns = internsResponse['interns'] ?? [];
        _filteredInterns = _interns;
      }
      if (projectsResponse['success']) {
        _projects = projectsResponse['projects'] ?? [];
      }
    });
  }

  void _searchInterns(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredInterns = _interns;
      } else {
        _filteredInterns = _interns.where((intern) {
          final name = intern['name'].toString().toLowerCase();
          final sltId = (intern['slt_id'] ?? '').toString().toLowerCase();
          final searchLower = query.toLowerCase();
          return name.contains(searchLower) || sltId.contains(searchLower);
        }).toList();
      }
    });
  }

  void _showInternDetails(dynamic intern) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );
    
    final response = await ApiService.getRequest('/supervisor/intern/${intern['id']}');
    Navigator.pop(context); // Close loading dialog
    
    if (response['success']) {
      final internDetails = response['intern'];
      _showInternDetailsDialog(internDetails);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load intern details'), backgroundColor: Colors.red),
      );
    }
  }

  void _showInternDetailsDialog(dynamic intern) async {
    // Load supervisors for the dropdown
    final supervisorsResponse = await ApiService.getRequest('/supervisors');
    final supervisors = supervisorsResponse['success'] ? supervisorsResponse['supervisors'] : [];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: Icon(Icons.person, color: Colors.blue[700]),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(intern['name'] ?? 'Unknown', style: TextStyle(fontSize: 18)),
                  Text(intern['slt_id'] ?? 'N/A', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
        content: Container(
          width: 700,
          height: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Basic Information Card
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Basic Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 12),
                        _buildDetailRow('SLT ID', intern['slt_id'] ?? 'N/A', Icons.badge),
                        _buildDetailRow('Name', intern['name'] ?? 'N/A', Icons.person),
                        _buildDetailRow('Email', intern['email'] ?? 'N/A', Icons.email),
                        _buildDetailRow('Joined', intern['created_at'] ?? 'N/A', Icons.date_range),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                
                // Project Assignments Section
                Row(
                  children: [
                    Icon(Icons.folder_open, color: Colors.orange[700]),
                    SizedBox(width: 8),
                    Text('Project Assignments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _showAssignProjectDialog(intern),
                      icon: Icon(Icons.add, size: 16),
                      label: Text('Assign Project'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                
                if (intern['projects'] != null && intern['projects'].length > 0)
                  ...List.generate(intern['projects'].length, (index) {
                    final project = intern['projects'][index];
                    final isActive = project['is_active'] == true || project['is_active'] == 1;
                    
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      elevation: isActive ? 3 : 1,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: isActive ? 
                                (project['status'] == 'Completed' ? Colors.green : 
                                 project['status'] == 'Hold' ? Colors.orange : Colors.blue) : 
                                Colors.grey,
                              width: 4,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          project['name'] ?? 'Unknown Project',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isActive ? Colors.black : Colors.grey[600],
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isActive ? 
                                                  (project['status'] == 'Completed' ? Colors.green[100] : 
                                                   project['status'] == 'Hold' ? Colors.orange[100] : Colors.blue[100]) : 
                                                  Colors.grey[200],
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '${project['status']} ${!isActive ? '(Past)' : ''}',
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Role: ${project['role_in_project'] ?? 'N/A'}',
                                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isActive)
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'change_supervisor') {
                                          _showChangeSupervisorDialog(project, supervisors);
                                        } else if (value == 'remove') {
                                          _removeInternFromProject(project['id'], intern['id']);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'change_supervisor',
                                          child: Row(
                                            children: [
                                              Icon(Icons.swap_horiz, size: 16),
                                              SizedBox(width: 8),
                                              Text('Change Supervisor'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'remove',
                                          child: Row(
                                            children: [
                                              Icon(Icons.remove_circle, size: 16, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Remove from Project', style: TextStyle(color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              SizedBox(height: 8),
                              if (project['description'] != null && project['description'].isNotEmpty)
                                Text(
                                  project['description'],
                                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.person, size: 14, color: Colors.grey[600]),
                                  SizedBox(width: 4),
                                  Text(
                                    'Supervisor: ${project['supervisor_name'] ?? 'Unknown'}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                  SizedBox(width: 16),
                                  Icon(Icons.date_range, size: 14, color: Colors.grey[600]),
                                  SizedBox(width: 4),
                                  Text(
                                    'Assigned: ${project['assigned_date'] ?? 'N/A'}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  })
                else
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.folder_open, size: 48, color: Colors.grey[400]),
                          SizedBox(height: 8),
                          Text(
                            'No projects assigned yet',
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showChangeSupervisorDialog(dynamic project, List<dynamic> supervisors) {
    int? selectedSupervisorId = project['supervisor_id'];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.swap_horiz, color: Colors.orange[700]),
              SizedBox(width: 8),
              Text('Change Project Supervisor'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Project: ${project['name']}', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Current Supervisor: ${project['supervisor_name']}'),
              SizedBox(height: 16),
              Text('New Supervisor:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: selectedSupervisorId,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: supervisors.map<DropdownMenuItem<int>>((supervisor) {
                  return DropdownMenuItem<int>(
                    value: supervisor['id'] as int,
                    child: Text('${supervisor['name']} (${supervisor['slt_id']})'),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedSupervisorId = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedSupervisorId == project['supervisor_id'] ? null : () async {
                Navigator.pop(context);
                await _changeSupervisor(project['id'], selectedSupervisorId!);
              },
              child: Text('Change'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeSupervisor(int projectId, int newSupervisorId) async {
    final response = await ApiService.putRequest('/projects/$projectId/supervisor', {
      'supervisor_id': newSupervisorId,
    });
    
    if (response['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Project supervisor changed successfully'), backgroundColor: Colors.green),
      );
      _loadData(); // Refresh the data
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Failed to change supervisor'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700]),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeInternFromProject(int projectId, int internId) async {
    // Show confirmation dialog
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirm Removal'),
          ],
        ),
        content: Text('Are you sure you want to remove this intern from the project?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      final response = await ApiService.deleteRequest('/projects/$projectId/interns/$internId');
      
      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Intern removed from project successfully'), backgroundColor: Colors.green),
        );
        _loadData(); // Refresh the data
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Failed to remove intern'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAssignProjectDialog(dynamic intern) {
    List<int> selectedProjectIds = [];
    String roleInProject = 'Developer';
    
    // Parse currently assigned projects to pre-select them
    if (intern['assigned_projects'] != null && intern['assigned_projects'] != 'Not Assigned') {
      // This is a simplified approach - in a real app you'd want to track project IDs
      // For now, we'll start with empty selection
    }
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Manage Projects for ${intern['name']}'),
          content: Container(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SLT ID: ${intern['slt_id']}', style: TextStyle(fontWeight: FontWeight.w500)),
                Text('Email: ${intern['email']}', style: TextStyle(color: Colors.grey[600])),
                SizedBox(height: 16),
                Text('Current Projects:', style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    intern['assigned_projects'] ?? 'Not Assigned',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                SizedBox(height: 16),
                Text('Assign New Project:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  hint: Text('Select a project to assign'),
                  items: _projects.where((p) => p['status'] == 'Ongoing').map<DropdownMenuItem<int>>((project) {
                    return DropdownMenuItem<int>(
                      value: project['id'] as int,
                      child: Text('${project['name']} (${project['status']})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        if (!selectedProjectIds.contains(value)) {
                          selectedProjectIds = [value]; // For simplicity, one at a time
                        }
                      });
                    }
                  },
                ),
                SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Role in Project',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Developer, Tester, Designer',
                  ),
                  onChanged: (value) => roleInProject = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedProjectIds.isEmpty ? null : () async {
                Navigator.pop(context);
                for (int projectId in selectedProjectIds) {
                  await _assignProject(intern['id'], projectId, roleInProject);
                }
              },
              child: Text('Assign'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignProject(int internId, int projectId, [String? role]) async {
    final response = await ApiService.postRequest('/supervisor/assign-project', {
      'intern_id': internId,
      'project_id': projectId,
      'role_in_project': role ?? 'Developer',
    });
    
    if (response['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Project assigned successfully'), backgroundColor: Colors.green),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Failed to assign project'), backgroundColor: Colors.red),
      );
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
              Text('View Interns', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Spacer(),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search by SLT_ID or Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _searchInterns('');
                            },
                          )
                        : null,
                  ),
                  onChanged: _searchInterns,
                ),
              ),
              SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: Icon(Icons.refresh),
                label: Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator())
              : _filteredInterns.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No interns found', style: TextStyle(fontSize: 18, color: Colors.grey)),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(Colors.orange[100]),
                        columns: [
                          DataColumn(label: Text('SLT_ID', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: _filteredInterns.map((intern) {
                          return DataRow(cells: [
                            DataCell(Text(intern['slt_id'] ?? 'N/A')),
                            DataCell(Text(intern['name'] ?? 'N/A')),
                            DataCell(Text(intern['email'] ?? 'N/A')),
                          ]);
                        }).toList(),
                      ),
                    ),
        ),
      ],
    );
  }
}

// ==================== VIEW PROJECTS WIDGET ====================
class ViewProjectsWidget extends StatefulWidget {
  @override
  _ViewProjectsWidgetState createState() => _ViewProjectsWidgetState();
}

class _ViewProjectsWidgetState extends State<ViewProjectsWidget> {
  List<dynamic> _projects = [];
  List<dynamic> _filteredProjects = [];
  bool _loading = true;
  bool _generatingReport = false;
  final _searchController = TextEditingController();
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  void _loadProjects() async {
    setState(() => _loading = true);
    
    try {
      final response = await ApiService.getRequest('/projects');
      
      print('=== DEBUG: Projects API Response ===');
      print('Response: $response');
      print('Success: ${response['success']}');
      print('Projects: ${response['projects']}');
      
      setState(() {
        _loading = false;
        if (response['success'] == true) {
          _projects = response['projects'] ?? [];
          print('Number of projects loaded: ${_projects.length}');
          if (_projects.isNotEmpty) {
            print('First project: ${_projects[0]}');
          }
          _applyFilters();
        } else {
          print('Failed to load projects: ${response['message']}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to load projects'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    } catch (e) {
      print('ERROR loading projects: $e');
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading projects: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _applyFilters() {
    List<dynamic> filtered = _projects;
    
    print('=== DEBUG: Apply Filters ===');
    print('Total projects: ${_projects.length}');
    print('Status filter: $_statusFilter');
    print('Search query: ${_searchController.text}');
    
    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((project) {
        final name = project['name'].toString().toLowerCase();
        final id = project['id'].toString();
        return name.contains(query) || id.contains(query);
      }).toList();
    }
    
    // Apply status filter
    if (_statusFilter != 'All') {
      filtered = filtered.where((project) {
        return project['status'] == _statusFilter;
      }).toList();
    }
    
    print('Filtered projects: ${filtered.length}');
    
    setState(() {
      _filteredProjects = filtered;
    });
  }

  void _showCreateProjectDialog() {
    final _nameController = TextEditingController();
    final _descriptionController = TextEditingController();
    final _typeController = TextEditingController(text: 'Development');
    final _technologiesController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_box, color: Colors.green[700]),
            SizedBox(width: 8),
            Text('Create New Project'),
          ],
        ),
        content: Container(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Project Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _typeController,
                decoration: InputDecoration(
                  labelText: 'Project Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                  hintText: 'e.g., Development, Research, Testing',
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _technologiesController,
                decoration: InputDecoration(
                  labelText: 'Technologies',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.computer),
                  hintText: 'e.g., Flutter, Python, MySQL',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Project name is required'), backgroundColor: Colors.red),
                );
                return;
              }
              
              Navigator.pop(context);
              
              final response = await ApiService.postRequest('/projects', {
                'name': _nameController.text.trim(),
                'description': _descriptionController.text.trim(),
                'project_type': _typeController.text.trim(),
                'technologies': _technologiesController.text.trim(),
              });
              
              if (response['success']) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Project created successfully!'), backgroundColor: Colors.green),
                );
                _loadProjects();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(response['message'] ?? 'Failed to create project'), backgroundColor: Colors.red),
                );
              }
            },
            child: Text('Create'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _generateReport(int projectId, String projectStatus) async {
    if (projectStatus != 'Ongoing') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reports can only be generated for Ongoing projects'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() => _generatingReport = true);
    
    final response = await ApiService.postRequest('/generate-report/$projectId', {});
    
    setState(() => _generatingReport = false);
    
    if (response['success']) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.analytics, color: Colors.orange[700]),
              SizedBox(width: 8),
              Text('Weekly Report Generated'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildReportSection('Summary', response['summary'] ?? 'No summary available', Colors.blue),
                SizedBox(height: 16),
                _buildReportSection('Warnings', response['warnings'] ?? 'No warnings', Colors.orange),
                SizedBox(height: 16),
                _buildReportSection('Suggestions', response['suggestions'] ?? 'No suggestions', Colors.green),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Failed to generate report'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildReportSection(String title, String content, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 8, color: color),
            SizedBox(width: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          ],
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(content, style: TextStyle(fontSize: 14)),
        ),
      ],
    );
  }

  Widget _buildProjectCard(dynamic project) {
    final status = project['status'] ?? 'Ongoing';
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'Completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'Hold':
        statusColor = Colors.orange;
        statusIcon = Icons.pause_circle;
        break;
      default:
        statusColor = Colors.blue;
        statusIcon = Icons.play_circle;
    }
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: statusColor, width: 5),
            top: BorderSide(color: Colors.grey[300]!, width: 1),
            right: BorderSide(color: Colors.grey[300]!, width: 1),
            bottom: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Project #${project['id']}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                            ),
                            SizedBox(width: 12),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(statusIcon, size: 14, color: statusColor),
                                  SizedBox(width: 4),
                                  Text(
                                    status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          project['name'] ?? 'Unnamed Project',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                project['description'] ?? 'No description',
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 12),
              Divider(),
              // Info Row
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    '${project['supervisor_name'] ?? 'Unknown Supervisor'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  SizedBox(width: 16),
                  Icon(Icons.group, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    '${project['intern_count'] ?? 0} Interns',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              SizedBox(height: 12),
              // Action Buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // View Details Button
                  ElevatedButton.icon(
                    onPressed: () => _showProjectDetails(project['id']),
                    icon: Icon(Icons.info_outline, size: 18),
                    label: Text('View Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  // Status Change Buttons
                  if (status == 'Ongoing')
                    ElevatedButton.icon(
                      onPressed: () => _changeProjectStatus(project['id'], 'Completed', project['name']),
                      icon: Icon(Icons.check_circle, size: 18),
                      label: Text('Mark Completed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  if (status == 'Ongoing')
                    ElevatedButton.icon(
                      onPressed: () => _changeProjectStatus(project['id'], 'Hold', project['name']),
                      icon: Icon(Icons.pause_circle, size: 18),
                      label: Text('Put on Hold'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[600],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  if (status == 'Hold')
                    ElevatedButton.icon(
                      onPressed: () => _changeProjectStatus(project['id'], 'Ongoing', project['name']),
                      icon: Icon(Icons.play_circle, size: 18),
                      label: Text('Resume'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  if (status == 'Completed')
                    ElevatedButton.icon(
                      onPressed: () => _changeProjectStatus(project['id'], 'Ongoing', project['name']),
                      icon: Icon(Icons.replay, size: 18),
                      label: Text('Reopen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  // Generate Report Button (only for Ongoing)
                  if (status == 'Ongoing')
                    ElevatedButton.icon(
                      onPressed: _generatingReport 
                          ? null 
                          : () => _generateReport(project['id'], status),
                      icon: Icon(Icons.analytics, size: 18),
                      label: Text('Generate Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple[600],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
  
  void _changeProjectStatus(int projectId, String newStatus, String projectName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Project Status'),
        content: Text('Are you sure you want to change "$projectName" status to $newStatus?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final response = await ApiService.putRequest(
                '/projects/$projectId/status',
                {'status': newStatus},
              );
              
              if (response['success']) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Project status updated to $newStatus'), backgroundColor: Colors.green),
                );
                _loadProjects(); // Refresh the list
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(response['message'] ?? 'Failed to update status'), backgroundColor: Colors.red),
                );
              }
            },
            child: Text('Confirm'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700]),
          ),
        ],
      ),
    );
  }
  
  void _showProjectDetails(int projectId) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );
    
    final response = await ApiService.getRequest('/projects/$projectId');
    Navigator.pop(context); // Close loading dialog
    
    if (response['success']) {
      final project = response['project'];
      _showEditableProjectDialog(project);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load project details'), backgroundColor: Colors.red),
      );
    }
  }

  void _showEditableProjectDialog(dynamic project) async {
    final _nameController = TextEditingController(text: project['name'] ?? '');
    final _descriptionController = TextEditingController(text: project['description'] ?? '');
    final _typeController = TextEditingController(text: project['project_type'] ?? '');
    final _technologiesController = TextEditingController(text: project['technologies'] ?? '');
    
    // Load supervisors for the dropdown
    final supervisorsResponse = await ApiService.getRequest('/supervisors');
    final supervisors = supervisorsResponse['success'] ? supervisorsResponse['supervisors'] : [];
    int? selectedSupervisorId = project['supervisor_id'];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit, color: Colors.orange[700]),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Edit Project Details',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
          child: Container(
            width: 600,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Project Basic Info
                Card(
                  color: Colors.grey[50],
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Project ID', '#${project['id']}', Icons.tag),
                        _buildDetailRow('Status', project['status'] ?? 'N/A', Icons.info),
                        if (project['start_date'] != null)
                          _buildDetailRow('Start Date', project['start_date'], Icons.calendar_today),
                        if (project['end_date'] != null)
                          _buildDetailRow('End Date', project['end_date'], Icons.event),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                
                // Supervisor Dropdown (Editable)
                Text('Project Supervisor:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: selectedSupervisorId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    prefixIcon: Icon(Icons.person),
                    labelText: 'Select Supervisor',
                  ),
                  items: supervisors.map<DropdownMenuItem<int>>((supervisor) {
                    return DropdownMenuItem<int>(
                      value: supervisor['id'] as int,
                      child: Text('${supervisor['name']} (${supervisor['slt_id']})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedSupervisorId = value;
                    });
                  },
                ),
                SizedBox(height: 16),
                
                // Editable Fields
                Text('Project Information:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Project Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: 12),
                TextField(
                  controller: _typeController,
                  decoration: InputDecoration(
                    labelText: 'Project Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: _technologiesController,
                  decoration: InputDecoration(
                    labelText: 'Technologies',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.computer),
                  ),
                ),
                SizedBox(height: 16),
                
                // Assigned Interns Section
                Divider(),
                Row(
                  children: [
                    Text(
                      'Assigned Interns (${project['assigned_interns']?.length ?? 0})',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Spacer(),
                    TextButton.icon(
                      onPressed: () => _showAssignInternsDialog(project['id']),
                      icon: Icon(Icons.person_add),
                      label: Text('Manage Interns'),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                if (project['assigned_interns'] != null && project['assigned_interns'].length > 0)
                  Container(
                    height: 200,
                    child: ListView.builder(
                      itemCount: project['assigned_interns'].length,
                      itemBuilder: (context, index) {
                        final intern = project['assigned_interns'][index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 4),
                          child: ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 15,
                              child: Text('${index + 1}'),
                              backgroundColor: Colors.blue[100],
                            ),
                            title: Text(intern['name'] ?? 'Unknown', style: TextStyle(fontSize: 14)),
                            subtitle: Text('${intern['slt_id']} • Role: ${intern['role_in_project']}', style: TextStyle(fontSize: 12)),
                            trailing: IconButton(
                              icon: Icon(Icons.remove_circle, color: Colors.red, size: 20),
                              onPressed: () => _removeInternFromProject(project['id'], intern['id']),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('No interns assigned yet', style: TextStyle(color: Colors.grey[600])),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Project name is required'), backgroundColor: Colors.red),
                );
                return;
              }
              
              Navigator.pop(context);
              
              // Update project details
              final updateResponse = await ApiService.putRequest('/projects/${project['id']}', {
                'name': _nameController.text.trim(),
                'description': _descriptionController.text.trim(),
                'project_type': _typeController.text.trim(),
                'technologies': _technologiesController.text.trim(),
              });
              
              bool allSuccessful = updateResponse['success'];
              String message = '';
              
              if (updateResponse['success']) {
                message = 'Project updated successfully!';
              } else {
                message = updateResponse['message'] ?? 'Failed to update project';
              }
              
              // Update supervisor if changed
              if (selectedSupervisorId != project['supervisor_id'] && selectedSupervisorId != null) {
                final supervisorResponse = await ApiService.putRequest('/projects/${project['id']}/supervisor', {
                  'supervisor_id': selectedSupervisorId,
                });
                
                if (supervisorResponse['success']) {
                  message += allSuccessful ? ' Supervisor changed successfully!' : 'Supervisor changed successfully!';
                } else {
                  allSuccessful = false;
                  message += ' Failed to change supervisor.';
                }
              }
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message), 
                  backgroundColor: allSuccessful ? Colors.green : Colors.red
                ),
              );
              
              if (allSuccessful) {
                _loadProjects();
              }
            },
            child: Text('Save Changes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ),
    );
  }

  void _showAssignInternsDialog(int projectId) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );
    
    // Get project details and available interns
    final projectResponse = await ApiService.getRequest('/projects/$projectId');
    final internsResponse = await ApiService.getRequest('/supervisor/interns');
    
    Navigator.pop(context); // Close loading dialog
    
    if (!projectResponse['success'] || !internsResponse['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data'), backgroundColor: Colors.red),
      );
      return;
    }
    
    final project = projectResponse['project'];
    final allInterns = internsResponse['interns'] as List;
    final assignedInterns = project['assigned_interns'] as List? ?? [];
    final assignedInternIds = assignedInterns.map((intern) => intern['id']).toSet();
    final availableInterns = allInterns.where((intern) => !assignedInternIds.contains(intern['id'])).toList();
    
    _showManageInternsDialog(project, assignedInterns, availableInterns);
  }

  void _showManageInternsDialog(dynamic project, List<dynamic> assignedInterns, List<dynamic> availableInterns) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.group, color: Colors.blue[700]),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Manage Interns - ${project['name']}',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Container(
          width: 700,
          height: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Project Info Card
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Project Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        _buildDetailRow('Project Name', project['name'] ?? 'N/A', Icons.work),
                        _buildDetailRow('Status', project['status'] ?? 'N/A', Icons.info),
                        _buildDetailRow('Supervisor', project['supervisor_name'] ?? 'N/A', Icons.person),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                
                // Currently Assigned Interns
                Row(
                  children: [
                    Icon(Icons.people, color: Colors.green[700]),
                    SizedBox(width: 8),
                    Text(
                      'Currently Assigned Interns (${assignedInterns.length})',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                
                if (assignedInterns.isNotEmpty)
                  Container(
                    height: 150,
                    child: ListView.builder(
                      itemCount: assignedInterns.length,
                      itemBuilder: (context, index) {
                        final intern = assignedInterns[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 4),
                          child: ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.green[100],
                              child: Icon(Icons.person, color: Colors.green[700]),
                            ),
                            title: Text(intern['name'] ?? 'Unknown', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            subtitle: Text('${intern['slt_id']} • Role: ${intern['role_in_project'] ?? 'N/A'}', style: TextStyle(fontSize: 12)),
                            trailing: IconButton(
                              icon: Icon(Icons.remove_circle, color: Colors.red, size: 20),
                              onPressed: () => _confirmRemoveInternFromProject(project['id'], intern['id'], intern['name']),
                              tooltip: 'Remove from project',
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.group_off, size: 48, color: Colors.grey[400]),
                          SizedBox(height: 8),
                          Text('No interns assigned yet', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ),
                
                SizedBox(height: 20),
                
                // Available Interns to Assign
                Row(
                  children: [
                    Icon(Icons.person_add, color: Colors.orange[700]),
                    SizedBox(width: 8),
                    Text(
                      'Available Interns to Assign (${availableInterns.length})',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                
                if (availableInterns.isNotEmpty)
                  Container(
                    height: 200,
                    child: ListView.builder(
                      itemCount: availableInterns.length,
                      itemBuilder: (context, index) {
                        final intern = availableInterns[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 4),
                          child: ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.orange[100],
                              child: Icon(Icons.person_add, color: Colors.orange[700]),
                            ),
                            title: Text(intern['name'] ?? 'Unknown', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            subtitle: Text('${intern['slt_id']} • Email: ${intern['email'] ?? 'N/A'}', style: TextStyle(fontSize: 12)),
                            trailing: ElevatedButton.icon(
                              onPressed: () => _showAssignInternToProjectDialog(project['id'], intern),
                              icon: Icon(Icons.add, size: 16),
                              label: Text('Assign'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange[600],
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.check_circle, size: 48, color: Colors.green[400]),
                          SizedBox(height: 8),
                          Text('All available interns are already assigned', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadProjects(); // Refresh the project data
            },
            child: Text('Refresh & Close'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showAssignInternToProjectDialog(int projectId, dynamic intern) {
    String roleInProject = 'Developer';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.assignment_ind, color: Colors.green[700]),
            SizedBox(width: 8),
            Text('Assign Intern to Project'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Intern: ${intern['name']} (${intern['slt_id']})', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text('Select Role in Project:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: roleInProject,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                prefixIcon: Icon(Icons.work),
              ),
              items: [
                'Developer',
                'Tester',
                'Designer',
                'Analyst',
                'Team Lead',
                'Researcher',
                'Documentation',
                'Other'
              ].map<DropdownMenuItem<String>>((String role) {
                return DropdownMenuItem<String>(
                  value: role,
                  child: Text(role),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  roleInProject = value;
                }
              },
            ),
            SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: 'Custom Role (Optional)',
                border: OutlineInputBorder(),
                hintText: 'Enter custom role if "Other" selected',
                prefixIcon: Icon(Icons.edit),
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  roleInProject = value;
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close assign dialog
              Navigator.pop(context); // Close manage interns dialog
              
              await _assignInternToProject(intern['id'], projectId, roleInProject);
              
              // Reopen the manage interns dialog with updated data
              _showAssignInternsDialog(projectId);
            },
            child: Text('Assign'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveInternFromProject(int projectId, int internId, String internName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirm Removal'),
          ],
        ),
        content: Text('Are you sure you want to remove $internName from this project?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close confirmation dialog
              Navigator.pop(context); // Close manage interns dialog
              
              await _removeInternFromProjectAPI(projectId, internId);
              
              // Reopen the manage interns dialog with updated data
              _showAssignInternsDialog(projectId);
            },
            child: Text('Remove'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _removeInternFromProject(int projectId, int internId) async {
    final response = await ApiService.postRequest('/supervisor/remove-from-project', {
      'project_id': projectId,
      'intern_id': internId,
    });
    
    if (response['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Intern removed from project'), backgroundColor: Colors.green),
      );
      // Refresh the current dialog by closing and reopening it
      Navigator.pop(context);
      _showProjectDetails(projectId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Failed to remove intern'), backgroundColor: Colors.red),
      );
    }
  }
  
  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ongoingProjects = _filteredProjects.where((p) => (p['status'] ?? 'Ongoing') == 'Ongoing').toList();
    final completedProjects = _filteredProjects.where((p) => p['status'] == 'Completed').toList();
    final holdProjects = _filteredProjects.where((p) => p['status'] == 'Hold').toList();
    
    print('=== DEBUG: Build ViewProjectsWidget ===');
    print('Loading: $_loading');
    print('Filtered Projects: ${_filteredProjects.length}');
    print('Ongoing: ${ongoingProjects.length}, Completed: ${completedProjects.length}, Hold: ${holdProjects.length}');
    
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('View Projects', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Spacer(),
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Search by ID or Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _applyFilters();
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) => _applyFilters(),
                    ),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _showCreateProjectDialog,
                    icon: Icon(Icons.add),
                    label: Text('Create Project'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _loadProjects,
                    icon: Icon(Icons.refresh),
                    label: Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Text('Filter by Status: ', style: TextStyle(fontWeight: FontWeight.w500)),
                  SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('All (${_projects.length})'),
                    selected: _statusFilter == 'All',
                    onSelected: (selected) {
                      setState(() {
                        _statusFilter = 'All';
                        _applyFilters();
                      });
                    },
                  ),
                  SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Ongoing (${_projects.where((p) => (p['status'] ?? 'Ongoing') == 'Ongoing').length})'),
                    selected: _statusFilter == 'Ongoing',
                    selectedColor: Colors.blue[100],
                    onSelected: (selected) {
                      setState(() {
                        _statusFilter = 'Ongoing';
                        _applyFilters();
                      });
                    },
                  ),
                  SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Completed (${_projects.where((p) => p['status'] == 'Completed').length})'),
                    selected: _statusFilter == 'Completed',
                    selectedColor: Colors.green[100],
                    onSelected: (selected) {
                      setState(() {
                        _statusFilter = 'Completed';
                        _applyFilters();
                      });
                    },
                  ),
                  SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Hold (${_projects.where((p) => p['status'] == 'Hold').length})'),
                    selected: _statusFilter == 'Hold',
                    selectedColor: Colors.orange[100],
                    onSelected: (selected) {
                      setState(() {
                        _statusFilter = 'Hold';
                        _applyFilters();
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_generatingReport)
          LinearProgressIndicator(),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator())
              : _filteredProjects.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No projects found', style: TextStyle(fontSize: 18, color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        if (_statusFilter == 'All' || _statusFilter == 'Ongoing') ...[
                          if (ongoingProjects.isNotEmpty) ...[
                            _buildSectionHeader('Ongoing Projects', Icons.play_circle, Colors.blue, ongoingProjects.length),
                            ...ongoingProjects.map((p) => _buildProjectCard(p)).toList(),
                          ],
                        ],
                        if (_statusFilter == 'All' || _statusFilter == 'Completed') ...[
                          if (completedProjects.isNotEmpty) ...[
                            _buildSectionHeader('Completed Projects', Icons.check_circle, Colors.green, completedProjects.length),
                            ...completedProjects.map((p) => _buildProjectCard(p)).toList(),
                          ],
                        ],
                        if (_statusFilter == 'All' || _statusFilter == 'Hold') ...[
                          if (holdProjects.isNotEmpty) ...[
                            _buildSectionHeader('On Hold Projects', Icons.pause_circle, Colors.orange, holdProjects.length),
                            ...holdProjects.map((p) => _buildProjectCard(p)).toList(),
                          ],
                        ],
                        SizedBox(height: 16),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, int count) {
    return Padding(
      padding: EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _assignInternToProject(int internId, int projectId, String role) async {
    final response = await ApiService.postRequest('/supervisor/assign-project', {
      'intern_id': internId,
      'project_id': projectId,
      'role_in_project': role,
    });
    
    if (response['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Intern assigned to project successfully'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Failed to assign intern'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _removeInternFromProjectAPI(int projectId, int internId) async {
    final response = await ApiService.deleteRequest('/projects/$projectId/interns/$internId');
    
    if (response['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Intern removed from project successfully'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Failed to remove intern'), backgroundColor: Colors.red),
      );
    }
  }
}

// ==================== AI REPORTS WIDGET ====================
class AIReportsWidget extends StatefulWidget {
  @override
  _AIReportsWidgetState createState() => _AIReportsWidgetState();
}

class _AIReportsWidgetState extends State<AIReportsWidget> {
  final AIService _aiService = AIService();
  List<AIProvider> _providers = [];
  List<Map<String, dynamic>> _interns = [];
  bool _isLoading = false;
  String? _selectedProvider;
  int? _selectedInternId;
  String _selectedReportType = 'weekly';
  AIReport? _lastGeneratedReport;

  @override
  void initState() {
    super.initState();
    _loadProviders();
    _loadInterns();
  }

  Future<void> _loadProviders() async {
    try {
      setState(() => _isLoading = true);
      
      // Set auth token
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token != null) {
        _aiService.setAuthToken(token);
      }
      
      final providers = await _aiService.getAvailableProviders();
      setState(() {
        _providers = providers;
        if (providers.isNotEmpty && providers.any((p) => p.available)) {
          _selectedProvider = providers.firstWhere((p) => p.available).name;
        }
      });
    } catch (e) {
      _showSnackBar('Failed to load AI providers: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadInterns() async {
    try {
      final response = await ApiService.getRequest('/supervisor/interns');
      if (response['success']) {
        setState(() {
          _interns = List<Map<String, dynamic>>.from(response['interns'] ?? []);
        });
      }
    } catch (e) {
      _showSnackBar('Failed to load interns: $e', Colors.red);
    }
  }

  Future<void> _generateReport() async {
    if (_selectedProvider == null || _selectedInternId == null) {
      _showSnackBar('Please select both a provider and an intern', Colors.orange);
      return;
    }

    try {
      setState(() => _isLoading = true);

      final request = ReportRequest(
        provider: _selectedProvider!,
        internId: _selectedInternId!,
        reportType: _selectedReportType,
        useFallback: true,
      );

      final report = await _aiService.generateReport(request);
      
      setState(() => _lastGeneratedReport = report);

      if (report.success) {
        _showSnackBar('AI Report generated successfully!', Colors.green);
      } else {
        _showSnackBar('Failed to generate report: ${report.error}', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error generating report: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.smart_toy, size: 32, color: Colors.orange[700]),
              SizedBox(width: 12),
              Text(
                'AI-Powered Report Generation',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Generate comprehensive intern progress reports using AI analysis',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          SizedBox(height: 32),

          // Controls Section
          Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report Configuration',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),

                  // Provider Selection
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AI Provider', style: TextStyle(fontWeight: FontWeight.w600)),
                            SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedProvider,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Select AI Provider',
                              ),
                              items: _providers.map((provider) {
                                return DropdownMenuItem<String>(
                                  value: provider.name,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: provider.available ? Colors.green : Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(provider.displayName, style: TextStyle(fontWeight: FontWeight.w600)),
                                            Text('${provider.cost} • ${provider.speed}', 
                                                 style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) => setState(() => _selectedProvider = value),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),

                      // Intern Selection
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Select Intern', style: TextStyle(fontWeight: FontWeight.w600)),
                            SizedBox(height: 8),
                            DropdownButtonFormField<int>(
                              value: _selectedInternId,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Choose intern',
                              ),
                              items: _interns.map((intern) {
                                return DropdownMenuItem<int>(
                                  value: intern['id'],
                                  child: Text(intern['name'] ?? 'Unknown Intern'),
                                );
                              }).toList(),
                              onChanged: (value) => setState(() => _selectedInternId = value),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),

                      // Report Type Selection
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Report Type', style: TextStyle(fontWeight: FontWeight.w600)),
                            SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedReportType,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                DropdownMenuItem(value: 'weekly', child: Text('Weekly Report')),
                                DropdownMenuItem(value: 'monthly', child: Text('Monthly Report')),
                                DropdownMenuItem(value: 'project_summary', child: Text('Project Summary')),
                              ],
                              onChanged: (value) => setState(() => _selectedReportType = value!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // Generate Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _generateReport,
                      icon: _isLoading 
                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(Icons.auto_awesome),
                      label: Text(_isLoading ? 'Generating Report...' : 'Generate AI Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[700],
                        foregroundColor: Colors.white,
                        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 24),

          // Report Display
          if (_lastGeneratedReport != null) ...[
            Expanded(
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.article, color: Colors.orange[700]),
                          SizedBox(width: 8),
                          Text(
                            'Generated Report',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Spacer(),
                          Chip(
                            label: Text(_lastGeneratedReport!.providerUsed.toUpperCase()),
                            backgroundColor: Colors.orange[100],
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      if (_lastGeneratedReport!.success) ...[
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Summary
                                _buildReportSection('Summary', _lastGeneratedReport!.summary),
                                SizedBox(height: 16),

                                // Strengths
                                _buildReportSection('Strengths', 
                                    _lastGeneratedReport!.strengths.join('\n• ')),
                                SizedBox(height: 16),

                                // Areas for Improvement
                                _buildReportSection('Areas for Improvement', 
                                    _lastGeneratedReport!.weaknesses.join('\n• ')),
                                SizedBox(height: 16),

                                // Recommendations
                                _buildReportSection('Recommendations', 
                                    _lastGeneratedReport!.recommendations.join('\n• ')),
                                SizedBox(height: 16),

                                // Performance Score
                                Row(
                                  children: [
                                    Text('Performance Score: ', 
                                         style: TextStyle(fontWeight: FontWeight.bold)),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _getScoreColor(_lastGeneratedReport!.performanceScore),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        '${_lastGeneratedReport!.performanceScore}/100',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error, color: Colors.red),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Report generation failed: ${_lastGeneratedReport!.error}',
                                  style: TextStyle(color: Colors.red[700]),
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
            ),
          ] else ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
                    SizedBox(height: 16),
                    Text(
                      'No report generated yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Select a provider and intern, then click "Generate AI Report"',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReportSection(String title, String content) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange[700]),
          ),
          SizedBox(height: 8),
          Text(
            content.isNotEmpty ? content : 'No information available',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }
}
