import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'login.dart';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int selectedTab = 0;
  String _userName = '';
  String _userRole = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  void _loadUserInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'Admin';
      _userRole = prefs.getString('user_role') ?? 'admin';
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
            Text('Welcome, $_userName ($_userRole)', 
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
                icon: Icon(Icons.supervisor_account),
                label: Text('Create Supervisor'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_add),
                label: Text('Add Intern'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text('View Interns'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.group),
                label: Text('All Users'),
              ),
            ],
          ),
          VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: selectedTab == 0
                ? CreateSupervisorWidget()
                : selectedTab == 1
                    ? AddInternWidget()
                    : selectedTab == 2
                        ? ViewInternsWidget()
                        : AllUsersWidget(),
          ),
        ],
      ),
    );
  }
}

// ==================== CREATE SUPERVISOR WIDGET ====================
class CreateSupervisorWidget extends StatefulWidget {
  @override
  _CreateSupervisorWidgetState createState() => _CreateSupervisorWidgetState();
}

class _CreateSupervisorWidgetState extends State<CreateSupervisorWidget> {
  final _sltIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  void _createSupervisor() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    setState(() => _loading = true);

    final response = await ApiService.postRequest('/admin/create-supervisor', {
      'slt_id': _sltIdController.text.trim(),
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text,
    });

    setState(() => _loading = false);

    if (response['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Supervisor created successfully!'), backgroundColor: Colors.green),
      );
      _sltIdController.clear();
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Failed to create supervisor')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 600),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.supervisor_account, size: 32, color: Colors.orange[700]),
                      SizedBox(width: 12),
                      Text(
                        'Create Supervisor Account',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Supervisors can manage interns and projects',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  Divider(height: 32),

                  TextField(
                    controller: _sltIdController,
                    decoration: InputDecoration(
                      labelText: 'SLT ID',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                      hintText: 'e.g., S001000',
                    ),
                  ),
                  SizedBox(height: 16),

                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  SizedBox(height: 16),

                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                      hintText: 'supervisor@company.com',
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 16),

                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                      hintText: 'Minimum 6 characters',
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                  ),
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
                            'Supervisors will login with email and password',
                            style: TextStyle(color: Colors.blue[900], fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _createSupervisor,
                      icon: _loading ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ) : Icon(Icons.add),
                      label: Text(_loading ? 'Creating...' : 'Create Supervisor', 
                                   style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.orange[700],
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

// ==================== ADD INTERN WIDGET ====================
class AddInternWidget extends StatefulWidget {
  @override
  _AddInternWidgetState createState() => _AddInternWidgetState();
}

class _AddInternWidgetState extends State<AddInternWidget> {
  final _sltIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _loading = false;

  void _addIntern() async {
    if (_nameController.text.trim().isEmpty || _emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _loading = true);

    final response = await ApiService.postRequest('/admin/add-user', {
      'slt_id': _sltIdController.text.trim(),
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'role': 'intern',
    });

    setState(() => _loading = false);

    if (response['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Intern added successfully!'), backgroundColor: Colors.green),
      );
      _sltIdController.clear();
      _nameController.clear();
      _emailController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Failed to add intern')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 600),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_add, size: 32, color: Colors.blue[700]),
                      SizedBox(width: 12),
                      Text(
                        'Add New Intern',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Register a new intern (login with email only)',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  Divider(height: 32),

                  TextField(
                    controller: _sltIdController,
                    decoration: InputDecoration(
                      labelText: 'SLT ID',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                      hintText: 'e.g., T001000',
                    ),
                  ),
                  SizedBox(height: 16),

                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  SizedBox(height: 16),

                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                      hintText: 'intern@company.com',
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 24),

                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700]),
                            SizedBox(width: 8),
                            Text('Important Notes:', 
                                 style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900])),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text('• Interns login with email only (no password)', 
                             style: TextStyle(color: Colors.blue[900], fontSize: 13)),
                        Text('• Project assignment is done by supervisors', 
                             style: TextStyle(color: Colors.blue[900], fontSize: 13)),
                      ],
                    ),
                  ),
                  SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _addIntern,
                      icon: _loading ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ) : Icon(Icons.add),
                      label: Text(_loading ? 'Adding...' : 'Add Intern', 
                                   style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue[700],
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

// ==================== VIEW INTERNS WIDGET ====================
class ViewInternsWidget extends StatefulWidget {
  @override
  _ViewInternsWidgetState createState() => _ViewInternsWidgetState();
}

class _ViewInternsWidgetState extends State<ViewInternsWidget> {
  List<dynamic> _interns = [];
  List<dynamic> _filteredInterns = [];
  bool _loading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInterns();
  }

  void _loadInterns() async {
    setState(() => _loading = true);
    
    final response = await ApiService.getRequest('/supervisor/interns');
    
    setState(() {
      _loading = false;
      if (response['success']) {
        _interns = response['interns'] ?? [];
        _filteredInterns = _interns;
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.people, size: 28, color: Colors.blue[700]),
              SizedBox(width: 12),
              Text('All Registered Interns', 
                   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Spacer(),
              SizedBox(
                width: 400,
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
                onPressed: _loadInterns,
                icon: Icon(Icons.refresh),
                label: Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
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
                          Text('No interns found', 
                               style: TextStyle(fontSize: 18, color: Colors.grey)),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(Colors.blue[100]),
                        columns: [
                          DataColumn(label: Text('SLT_ID', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Project ID', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: _filteredInterns.map((intern) {
                          return DataRow(cells: [
                            DataCell(Text(intern['slt_id'] ?? 'N/A')),
                            DataCell(Text(intern['name'] ?? 'N/A')),
                            DataCell(Text(intern['email'] ?? 'N/A')),
                            DataCell(Text(intern['project_id']?.toString() ?? 'Not Assigned')),
                          ]);
                        }).toList(),
                      ),
                    ),
        ),
      ],
    );
  }
}

// ==================== ALL USERS WIDGET ====================
class AllUsersWidget extends StatefulWidget {
  @override
  _AllUsersWidgetState createState() => _AllUsersWidgetState();
}

class _AllUsersWidgetState extends State<AllUsersWidget> {
  List<dynamic> _users = [];
  List<dynamic> _filteredUsers = [];
  bool _loading = true;
  final _searchController = TextEditingController();
  String _roleFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _loadUsers() async {
    setState(() => _loading = true);
    
    final response = await ApiService.getRequest('/admin/users');
    
    setState(() {
      _loading = false;
      if (response['success']) {
        _users = response['users'] ?? [];
        _applyFilters();
      }
    });
  }

  void _applyFilters() {
    List<dynamic> filtered = _users;
    
    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((user) {
        final name = user['name'].toString().toLowerCase();
        final sltId = (user['slt_id'] ?? '').toString().toLowerCase();
        return name.contains(query) || sltId.contains(query);
      }).toList();
    }
    
    // Apply role filter
    if (_roleFilter != 'All') {
      filtered = filtered.where((user) => user['role'] == _roleFilter.toLowerCase()).toList();
    }
    
    setState(() {
      _filteredUsers = filtered;
    });
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'supervisor':
        return Colors.orange;
      case 'intern':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminCount = _users.where((u) => u['role'] == 'admin').length;
    final supervisorCount = _users.where((u) => u['role'] == 'supervisor').length;
    final internCount = _users.where((u) => u['role'] == 'intern').length;
    
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.group, size: 28, color: Colors.purple[700]),
                  SizedBox(width: 12),
                  Text('All Users in System', 
                       style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Spacer(),
                  SizedBox(
                    width: 400,
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
                    onPressed: _loadUsers,
                    icon: Icon(Icons.refresh),
                    label: Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Text('Filter by Role: ', style: TextStyle(fontWeight: FontWeight.w500)),
                  SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('All (${_users.length})'),
                    selected: _roleFilter == 'All',
                    onSelected: (selected) {
                      setState(() {
                        _roleFilter = 'All';
                        _applyFilters();
                      });
                    },
                  ),
                  SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Admin ($adminCount)'),
                    selected: _roleFilter == 'Admin',
                    selectedColor: Colors.red[100],
                    onSelected: (selected) {
                      setState(() {
                        _roleFilter = 'Admin';
                        _applyFilters();
                      });
                    },
                  ),
                  SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Supervisor ($supervisorCount)'),
                    selected: _roleFilter == 'Supervisor',
                    selectedColor: Colors.orange[100],
                    onSelected: (selected) {
                      setState(() {
                        _roleFilter = 'Supervisor';
                        _applyFilters();
                      });
                    },
                  ),
                  SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Intern ($internCount)'),
                    selected: _roleFilter == 'Intern',
                    selectedColor: Colors.blue[100],
                    onSelected: (selected) {
                      setState(() {
                        _roleFilter = 'Intern';
                        _applyFilters();
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator())
              : _filteredUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No users found', 
                               style: TextStyle(fontSize: 18, color: Colors.grey)),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(Colors.purple[100]),
                        columns: [
                          DataColumn(label: Text('SLT_ID', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Project ID', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: _filteredUsers.map((user) {
                          final role = user['role']?.toString() ?? 'Unknown';
                          final roleColor = _getRoleColor(role);
                          
                          return DataRow(cells: [
                            DataCell(Text(user['slt_id'] ?? 'N/A')),
                            DataCell(Text(user['name'] ?? 'N/A')),
                            DataCell(Text(user['email'] ?? 'N/A')),
                            DataCell(
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: roleColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  role.toUpperCase(),
                                  style: TextStyle(
                                    color: roleColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(user['project_id']?.toString() ?? '-')),
                          ]);
                        }).toList(),
                      ),
                    ),
        ),
      ],
    );
  }
}
