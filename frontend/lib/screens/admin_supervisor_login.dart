import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'admin_dashboard.dart';
import 'supervisor_dashboard.dart';
import 'forgot_password.dart';

class AdminSupervisorLogin extends StatefulWidget {
  @override
  _AdminSupervisorLoginState createState() => _AdminSupervisorLoginState();
}

class _AdminSupervisorLoginState extends State<AdminSupervisorLogin> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  void _login() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter both email and password')),
      );
      return;
    }

    setState(() => _loading = true);

    final response = await ApiService.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    setState(() => _loading = false);

    if (response['success']) {
      // Save token and user info
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', response['token']);
      
      final user = response['user'];
      final role = user['role'];
      
      await prefs.setString('role', role);
      await prefs.setInt('user_id', user['id'] ?? 0);
      await prefs.setString('user_name', user['name'] ?? '');
      await prefs.setString('user_email', user['email'] ?? '');

      // Redirect based on role
      if (role == 'admin') {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => AdminDashboard())
        );
      } else if (role == 'supervisor') {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => SupervisorDashboard())
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Access denied. This page is for admin/supervisor only.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Login failed')),
      );
    }
  }

  void _forgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ForgotPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin / Supervisor Login'),
        backgroundColor: Colors.orange[700],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Container(
                constraints: BoxConstraints(maxWidth: 450),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.admin_panel_settings,
                      size: 64,
                      color: Colors.orange[700],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Admin / Supervisor Login',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Enter your credentials to continue',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 32),
                    
                    // Email Field
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                        hintText: 'admin@company.com',
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 20),
                    
                    // Password Field
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                        hintText: 'Enter your password',
                      ),
                    ),
                    SizedBox(height: 12),
                    
                    // Forgot Password Link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgotPassword,
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(color: Colors.orange[700]),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    
                    // Login Button
                    _loading
                      ? Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          onPressed: _login,
                          icon: Icon(Icons.login),
                          label: Text('Login', style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.orange[700],
                            foregroundColor: Colors.white,
                          ),
                        ),
                    
                    SizedBox(height: 16),
                    
                    // Info Card
                    Container(
                      padding: EdgeInsets.all(16),
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
                              'Contact the admin if you need access or have trouble logging in.',
                              style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
