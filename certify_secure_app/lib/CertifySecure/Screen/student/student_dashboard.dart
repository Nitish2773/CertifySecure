import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Constants and Utility Imports
import 'package:certify_secure_app/CertifySecure/Screen/utils/constants.dart';
import 'package:certify_secure_app/CertifySecure/Screen/utils/helpers.dart';

// Screen Imports
import 'package:certify_secure_app/CertifySecure/Screen/main/role_selection_screen.dart';
import 'package:certify_secure_app/CertifySecure/Screen/student/home_screen.dart';
import 'package:certify_secure_app/CertifySecure/Screen/student/profile_screen.dart';
import 'package:certify_secure_app/CertifySecure/Screen/student/upload_certificate_screen.dart';
import 'package:certify_secure_app/CertifySecure/Screen/student/view_certificates_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard(
      {super.key,
      required studentId,
      required studentName,
      required studentClass,
      required studentSection});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final User? user = FirebaseAuth.instance.currentUser;
  late AnimationController _animationController;
  late final List<Widget> _screens;
  bool _hasUnreadNotifications = false;
  int _notificationCount = 0;
  static const int HOME_INDEX = 0;
  static const int PROFILE_INDEX = 1;
  static const int UPLOAD_INDEX = 2;
  static const int CERTIFICATES_INDEX = 3;
  static const int MAX_INDEX = 3;
  String? _photoURL;
  StreamSubscription? _profileSubscription;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Page Controller for smooth transitions
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _initializeScreens();
    _checkNotifications();
    _setupProfileListener();
  }

void _setupProfileListener() {
  if (user != null) {
    _profileSubscription = _firestore
        .collection('users')
        .doc(user!.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        setState(() {
          _photoURL = snapshot.data()?['imageUrl'] ?? 
                     snapshot.data()?['photoURL'] ?? 
                     user?.photoURL;
        });
      }
    });
  }
}

  void _initializeScreens() {
    _screens = [
      HomeScreen(onNavigate: _onItemTapped),
      const ProfileScreen(),
      const UploadCertificateScreen(),
      const ViewCertificatesScreen(),
    ];
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: AppConstants.defaultAnimationDuration,
      vsync: this,
    );

    _animationController.forward();
  }

  Future<void> _checkNotifications() async {
    try {
      final notificationsSnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user?.uid)
          .where('read', isEqualTo: false)
          .get();

      setState(() {
        _notificationCount = notificationsSnapshot.docs.length;
        _hasUnreadNotifications = _notificationCount > 0;
      });
    } catch (e) {
      debugPrint('Error checking notifications: $e');
    }
  }

  void _onItemTapped(int index) {
    // Ensure index is within valid range
    if (index >= 0 && index <= MAX_INDEX) {
      setState(() {
        _selectedIndex = index;
      });
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _showLogoutDialog() async {
    final bool shouldLogout = await Helpers.showConfirmationDialog(
      context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmText: 'Logout',
      cancelText: 'Cancel',
      isDestructive: true,
    );

    if (shouldLogout && mounted) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const RoleSelectionScreen(),
        ),
      );
    }
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildNotificationsSheet(),
    );
  }

  Widget _buildNotificationsSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Mark all as read
                    },
                    child: const Text('Mark all as read'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('userId', isEqualTo: user?.uid)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Something went wrong'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final notifications = snapshot.data?.docs ?? [];

                  if (notifications.isEmpty) {
                    return const Center(
                      child: Text('No notifications'),
                    );
                  }

                  return ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _buildNotificationItem(notification);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(DocumentSnapshot notification) {
    final data = notification.data() as Map<String, dynamic>;
    final bool isRead = data['read'] ?? false;
    final timestamp = (data['timestamp'] as Timestamp).toDate();

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _getNotificationColor(data['type']).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          _getNotificationIcon(data['type']),
          color: _getNotificationColor(data['type']),
        ),
      ),
      title: Text(
        data['title'] ?? '',
        style: TextStyle(
          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data['message'] ?? ''),
          const SizedBox(height: 4),
          Text(
            Helpers.getTimeAgo(timestamp),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
      trailing: !isRead
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onTap: () => _handleNotificationTap(notification),
    );
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'success':
        return AppColors.success;
      case 'warning':
        return AppColors.warning;
      case 'error':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'success':
        return Icons.check_circle;
      case 'warning':
        return Icons.warning;
      case 'error':
        return Icons.error;
      default:
        return Icons.notifications;
    }
  }

  Future<void> _handleNotificationTap(DocumentSnapshot notification) async {
    await notification.reference.update({'read': true});

    final data = notification.data() as Map<String, dynamic>;

    switch (data['action']) {
      case 'view_certificate':
        _onItemTapped(CERTIFICATES_INDEX);
        break;
      case 'profile_update':
        _onItemTapped(PROFILE_INDEX);
        break;
      case 'upload_certificate':
        _onItemTapped(UPLOAD_INDEX);
        break;
      default:
        _onItemTapped(HOME_INDEX);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) {
                          if (index >= 0 && index <= MAX_INDEX) {
                            setState(() {
                              _selectedIndex = index;
                            });
                          }
                        },
                        physics: const NeverScrollableScrollPhysics(),
                        children: _screens,
                      )),
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
  return Container(
    padding: const EdgeInsets.all(16.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => _onItemTapped(PROFILE_INDEX),
              child: Hero(
                tag: 'profileImage',
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        backgroundImage: _photoURL != null && _photoURL!.isNotEmpty
                            ? NetworkImage(_photoURL!)
                            : null,
                        child: (_photoURL == null || _photoURL!.isEmpty)
                            ? Icon(
                                Icons.person,
                                size: 24,
                                color: Colors.white.withOpacity(0.9),
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 8,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome back,",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  user?.displayName ?? "Student",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            _buildNotificationBadge(),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
              ),
              child: IconButton(
                icon: const Icon(Icons.logout_rounded),
                color: Colors.white,
                iconSize: 22,
                splashRadius: 24,
                tooltip: 'Logout',
                onPressed: _showLogoutDialog,
              ),
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
        if (_hasUnreadNotifications)
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
                _notificationCount.toString(),
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
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.upload_file_outlined),
              activeIcon: Icon(Icons.upload_file),
              label: 'Upload',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_outlined),
              activeIcon: Icon(Icons.folder),
              label: 'Certificates',
            ),
          ],
          currentIndex: _selectedIndex.clamp(0, MAX_INDEX),
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          onTap: _onItemTapped,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _biometricEnabled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _notificationsEnabled = userData?['notificationsEnabled'] ?? true;
          _darkModeEnabled = userData?['darkModeEnabled'] ?? false;
          _biometricEnabled = userData?['biometricEnabled'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String setting, bool value) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .update({setting: value});
    } catch (e) {
      debugPrint('Error updating setting: $e');
      Helpers.showSnackBar(
        context,
        'Failed to update setting',
        isError: true,
      );
    }
  }

  Future<void> _changePassword() async {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              decoration: const InputDecoration(
                labelText: 'Current Password',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              decoration: const InputDecoration(
                labelText: 'New Password',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text !=
                  confirmPasswordController.text) {
                Helpers.showSnackBar(
                  context,
                  'Passwords do not match',
                  isError: true,
                );
                return;
              }

              try {
                final credential = EmailAuthProvider.credential(
                  email: user?.email ?? '',
                  password: currentPasswordController.text,
                );

                await user?.reauthenticateWithCredential(credential);
                await user?.updatePassword(newPasswordController.text);

                if (mounted) {
                  Navigator.pop(context);
                  Helpers.showSnackBar(
                    context,
                    'Password updated successfully',
                  );
                }
              } catch (e) {
                Helpers.showSnackBar(
                  context,
                  'Failed to update password',
                  isError: true,
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      children: [
        _buildProfileSection(),
        const Divider(),
        _buildPreferencesSection(),
        const Divider(),
        _buildSecuritySection(),
        const Divider(),
        _buildSupportSection(),
        const Divider(),
        _buildAboutSection(),
        const SizedBox(height: 20),
        _buildLogoutButton(),
      ],
    );
  }

  Widget _buildProfileSection() {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
        child: user?.photoURL == null ? const Icon(Icons.person) : null,
      ),
      title: Text(user?.displayName ?? 'User'),
      subtitle: Text(user?.email ?? ''),
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () {
          // Navigate to profile edit screen
        },
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Preferences',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SwitchListTile(
          title: const Text('Notifications'),
          subtitle: const Text('Receive app notifications'),
          value: _notificationsEnabled,
          onChanged: (value) {
            setState(() => _notificationsEnabled = value);
            _updateSetting('notificationsEnabled', value);
          },
        ),
        SwitchListTile(
          title: const Text('Dark Mode'),
          subtitle: const Text('Switch between light and dark themes'),
          value: _darkModeEnabled,
          onChanged: (value) {
            setState(() => _darkModeEnabled = value);
            _updateSetting('darkModeEnabled', value);
          },
        ),
      ],
    );
  }

  Widget _buildSecuritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Security',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SwitchListTile(
          title: const Text('Biometric Authentication'),
          subtitle: const Text('Use fingerprint or face ID'),
          value: _biometricEnabled,
          onChanged: (value) {
            setState(() => _biometricEnabled = value);
            _updateSetting('biometricEnabled', value);
          },
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Change Password'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _changePassword,
        ),
      ],
    );
  }

  Widget _buildSupportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Support',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: const Text('Help Center'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // Navigate to help center
          },
        ),
        ListTile(
          leading: const Icon(Icons.chat_bubble_outline),
          title: const Text('Contact Support'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // Open support chat
          },
        ),
        ListTile(
          leading: const Icon(Icons.bug_report_outlined),
          title: const Text('Report a Bug'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // Show bug report form
          },
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'About',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About CertifySecure'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // Show about dialog
          },
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy Policy'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // Show privacy policy
          },
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('Terms of Service'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // Show terms of service
          },
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton(
        onPressed: () async {
          final shouldLogout = await Helpers.showConfirmationDialog(
            context,
            title: 'Logout',
            message: 'Are you sure you want to logout?',
            confirmText: 'Logout',
            cancelText: 'Cancel',
            isDestructive: true,
          );

          if (shouldLogout && mounted) {
            await FirebaseAuth.instance.signOut();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const RoleSelectionScreen(),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text('Logout'),
      ),
    );
  }
}
