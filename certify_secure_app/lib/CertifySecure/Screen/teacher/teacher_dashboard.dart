// lib/screens/teacher/teacher_dashboard.dart

import 'package:certify_secure_app/CertifySecure/Screen/main/role_selection_screen.dart';
import 'package:certify_secure_app/CertifySecure/Screen/teacher/pending_certificates_screen.dart';
import 'package:certify_secure_app/CertifySecure/Screen/teacher/teacher_home_screen.dart';
import 'package:certify_secure_app/CertifySecure/Screen/teacher/teacher_profile_screen.dart';
import 'package:certify_secure_app/CertifySecure/Screen/teacher/verified_certificates_screen.dart';
import 'package:certify_secure_app/CertifySecure/Screen/utils/constants.dart';
import 'package:certify_secure_app/CertifySecure/Screen/utils/helpers.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  _TeacherDashboardState createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard>
    with SingleTickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _currentIndex = 0;
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Teacher Data
  Map<String, dynamic> _teacherData = {};
  String _department = '';
  List<String> _sections = [];
  int _pendingCount = 0;
  int _verifiedCount = 0;

  // Settings
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  String _selectedLanguage = 'English';

  // Screens
  List<Widget> _screens = []; // Changed from late List<Widget>

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _loadTeacherData();
    _loadSettings();
    _initializeScreens(); // Added this call
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: AppConstants.defaultAnimationDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();
  }

  Future<void> _loadTeacherData() async {
    try {
      final teacherDoc =
          await _firestore.collection('users').doc(user?.uid).get();

      if (teacherDoc.exists) {
        setState(() {
          _teacherData = teacherDoc.data() ?? {};
          _department = _teacherData['department'] ?? '';
          _sections = List<String>.from(_teacherData['sections'] ?? []);
        });

        await _loadCertificateCounts();
        setState(() {
          _initializeScreens(); // Reinitialize screens with new data
        });
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading teacher data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCertificateCounts() async {
    try {
      // Get pending certificates count
      final pendingQuery = await _firestore
          .collection('certificates')
          .where('studentDetails.department', isEqualTo: _department)
          .where('studentDetails.section', whereIn: _sections)
          .where('verificationDetails.status', isEqualTo: 'pending')
          .count()
          .get();

      // Get verified certificates count
      final verifiedQuery = await _firestore
          .collection('certificates')
          .where('studentDetails.department', isEqualTo: _department)
          .where('studentDetails.section', whereIn: _sections)
          .where('verificationDetails.status', isEqualTo: 'verified')
          .where('verificationDetails.verifiedBy', isEqualTo: user?.uid)
          .count()
          .get();

      setState(() {
        _pendingCount = pendingQuery.count!;
        _verifiedCount = verifiedQuery.count!;
      });
    } catch (e) {
      debugPrint('Error loading certificate counts: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications') ?? true;
        _darkModeEnabled = prefs.getBool('darkMode') ?? false;
        _selectedLanguage = prefs.getString('language') ?? 'English';
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  void _initializeScreens() {
    _screens = [
      TeacherHomeScreen(
        onNavigate: (index) => setState(() => _currentIndex = index),
        teacherData: _teacherData,
        pendingCount: _pendingCount,
        verifiedCount: _verifiedCount,
      ),
      PendingCertificatesScreen(
        department: _department,
        sections: _sections,
      ),
      VerifiedCertificatesScreen(
        department: _department,
        sections: _sections,
      ),
      TeacherProfileScreen(
        teacherData: _teacherData,
        onDataUpdate: _loadTeacherData,
      ),
    ];
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }

      // Update settings in Firestore
      await _firestore.collection('users').doc(user?.uid).update({
        'settings.$key': value,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving setting: $e');
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Failed to save settings',
          isError: true,
        );
      }
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await Helpers.showConfirmationDialog(
      context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmText: 'Logout',
      cancelText: 'Cancel',
      isDestructive: true,
    );

    if (shouldLogout && mounted) {
      try {
        await FirebaseAuth.instance.signOut();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
        );
      } catch (e) {
        if (mounted) {
          Helpers.showSnackBar(
            context,
            'Logout failed: $e',
            isError: true,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.secondary,
              AppColors.accent,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildCustomAppBar(),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _screens[_currentIndex],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildCustomAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome back,",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
              Text(
                _teacherData['name'] ?? user?.displayName ?? "Teacher",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${_teacherData['department'] ?? 'Department'} - ${_teacherData['designation'] ?? 'Teacher'}",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildNotificationBadge(),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.white,
                ),
                onSelected: _handleMenuSelection,
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings),
                        SizedBox(width: 8),
                        Text('Settings'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: 8),
                        Text('Logout'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBadge() {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          color: Colors.white,
          onPressed: _showNotifications,
        ),
        if (_pendingCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(6),
              ),
              constraints: const BoxConstraints(
                minWidth: 14,
                minHeight: 14,
              ),
              child: Text(
                _pendingCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.pending_actions_outlined),
                  if (_pendingCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: Text(
                          _pendingCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              activeIcon: const Icon(Icons.pending_actions),
              label: 'Pending',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.verified_outlined),
              activeIcon: Icon(Icons.verified),
              label: 'Verified',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuSelection(String value) async {
    switch (value) {
      case 'settings':
        _showSettingsDialog();
        break;
      case 'logout':
        await _logout();
        break;
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Department Info
                  ListTile(
                    title: Text('Department: $_department'),
                    subtitle: Text('Sections: ${_sections.join(", ")}'),
                    leading: const Icon(Icons.business),
                  ),
                  const Divider(),

                  // Notifications Setting
                  SwitchListTile(
                    title: const Text('Notifications'),
                    subtitle:
                        const Text('Receive certificate verification alerts'),
                    value: _notificationsEnabled,
                    onChanged: (bool value) {
                      setState(() => _notificationsEnabled = value);
                      _saveSetting('notifications', value);
                    },
                  ),
                  const Divider(),

                  // Dark Mode Setting
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    subtitle: const Text('Enable dark theme'),
                    value: _darkModeEnabled,
                    onChanged: (bool value) {
                      setState(() => _darkModeEnabled = value);
                      _saveSetting('darkMode', value);
                    },
                  ),
                  const Divider(),

                  // Language Setting
                  ListTile(
                    title: const Text('Language'),
                    subtitle: Text(_selectedLanguage),
                    leading: const Icon(Icons.language),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showLanguageSelector(context),
                  ),
                  const Divider(),

                  // Account Settings
                  ListTile(
                    title: const Text('Change Password'),
                    leading: const Icon(Icons.lock_outline),
                    onTap: () {
                      Navigator.pop(context);
                      _showChangePasswordDialog();
                    },
                  ),

                  // Help & Support
                  ListTile(
                    title: const Text('Help & Support'),
                    leading: const Icon(Icons.help_outline),
                    onTap: () => _showHelpAndSupport(),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLanguageSelector(BuildContext context) {
    final List<String> languages = [
      'English',
      'Hindi',
      'Telugu',
      'Tamil',
      'Kannada',
      'Malayalam',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: languages.map((language) {
              final isSelected = _selectedLanguage == language;
              return ListTile(
                leading: isSelected
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : const Icon(Icons.circle_outlined),
                title: Text(language),
                onTap: () {
                  setState(() => _selectedLanguage = language);
                  _saveSetting('language', language);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showHelpAndSupport() {
    // Implement help and support functionality
  }

  // ignore: unused_element
  Stream<QuerySnapshot> _getNotificationsStream() {
    return _firestore
        .collection('notifications')
        .where('teacherId', isEqualTo: user?.uid)
        .where('department', isEqualTo: _department)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  void _showNotifications() {
    // Implementation of notifications dialog
    // (Previous implementation remains the same)
  }
  void _showChangePasswordDialog() {
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Change Password'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: currentPasswordController,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter current password';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: newPasswordController,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter new password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm new password';
                }
                if (value != newPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            currentPasswordController.clear();
            newPasswordController.clear();
            confirmPasswordController.clear();
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (formKey.currentState!.validate()) {
              try {
                // Show loading indicator
                Navigator.pop(context);
                Helpers.showLoadingDialog(context);

                final user = FirebaseAuth.instance.currentUser;
                if (user == null) throw Exception('User not logged in');

                // Create credentials
                final credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: currentPasswordController.text,
                );

                // Reauthenticate user
                await user.reauthenticateWithCredential(credential);

                // Change password
                await user.updatePassword(newPasswordController.text);

                // Update password change timestamp in Firestore
                await _firestore.collection('users').doc(user.uid).update({
                  'lastPasswordChange': FieldValue.serverTimestamp(),
                });

                // Clear controllers
                currentPasswordController.clear();
                newPasswordController.clear();
                confirmPasswordController.clear();

                // Dismiss loading dialog
                if (mounted) Navigator.pop(context);

                // Show success message
                if (mounted) {
                  Helpers.showSnackBar(
                    context,
                    'Password changed successfully',
                  );
                }
              } catch (e) {
                // Dismiss loading dialog if showing
                if (mounted) Navigator.pop(context);

                String errorMessage = 'Failed to change password';

                if (e is FirebaseAuthException) {
                  switch (e.code) {
                    case 'wrong-password':
                      errorMessage = 'Current password is incorrect';
                      break;
                    case 'requires-recent-login':
                      errorMessage = 'Please log in again and retry';
                      break;
                    default:
                      errorMessage = e.message ?? errorMessage;
                  }
                }

                // Show error message
                if (mounted) {
                  Helpers.showSnackBar(
                    context,
                    errorMessage,
                    isError: true,
                  );
                }

                // If error is due to requiring recent login, show login dialog
                if (e is FirebaseAuthException &&
                    e.code == 'requires-recent-login') {
                  await _showReauthenticationDialog();
                }
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: const Text('Change Password'),
        ),
      ],
    ),
  );
}

// Also add this helper method for reauthentication
Future<void> _showReauthenticationDialog() async {
  final emailController =
      TextEditingController(text: FirebaseAuth.instance.currentUser?.email);
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Re-authenticate'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'For security reasons, please re-enter your credentials',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              readOnly: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            passwordController.clear();
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (formKey.currentState!.validate()) {
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) throw Exception('User not logged in');

                final credential = EmailAuthProvider.credential(
                  email: emailController.text,
                  password: passwordController.text,
                );

                await user.reauthenticateWithCredential(credential);

                passwordController.clear();
                Navigator.pop(context);

                // Show password change dialog again
                _showChangePasswordDialog();
              } catch (e) {
                String errorMessage = 'Authentication failed';
                if (e is FirebaseAuthException) {
                  errorMessage = e.message ?? errorMessage;
                }

                if (mounted) {
                  Helpers.showSnackBar(
                    context,
                    errorMessage,
                    isError: true,
                  );
                }
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: const Text('Authenticate'),
        ),
      ],
    ),
  );
}

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
