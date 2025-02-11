// lib/screens/company/company_dashboard.dart

import 'package:certify_secure_app/CertifySecure/Screen/company/company_home_screen.dart';
import 'package:certify_secure_app/CertifySecure/Screen/company/verify_certificates_screen.dart';
import 'package:certify_secure_app/CertifySecure/Screen/main/role_selection_screen.dart';
import 'package:certify_secure_app/CertifySecure/Screen/utils/constants.dart';
import 'package:certify_secure_app/CertifySecure/Screen/utils/helpers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CompanyDashboard extends StatefulWidget {
  const CompanyDashboard({super.key});

  @override
  State<CompanyDashboard> createState() => _CompanyDashboardState();
}

class _CompanyDashboardState extends State<CompanyDashboard>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final User? user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Map<String, dynamic> _companyData = {};
  bool _isLoading = true;
  int _unreadNotifications = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _fetchCompanyData();
    _setupNotificationListener();
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

  Future<void> _fetchCompanyData() async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(user?.uid)
          .get();

      if (doc.exists) {
        setState(() {
          _companyData = doc.data() ?? {};
          _isLoading = false;
          _screens = [
            CompanyHomeScreen(companyData: _companyData),
            const VerifyCertificatesScreen(),
          ];
        });
      }
    } catch (e) {
      print('Error fetching company data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _setupNotificationListener() {
    _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user?.uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen(
      (snapshot) {
        setState(() {
          _unreadNotifications = snapshot.docs.length;
        });
      },
      onError: (error) {
        print('Error listening to notifications: $error');
      },
    );
  }

  Future<void> _markNotificationsAsRead() async {
    try {
      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user?.uid)
          .where('read', isEqualTo: false)
          .get();

      for (var doc in notifications.docs) {
        batch.update(doc.reference, {'read': true});
      }

      await batch.commit();
    } catch (e) {
      print('Error marking notifications as read: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _animationController.reset();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.secondary,
              AppColors.accent.withOpacity(0.9),
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
                      child: _screens[_selectedIndex],
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
    return Container(
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
                _companyData['name'] ?? "Company",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildNotificationBadge(),
              const SizedBox(width: 8),
              _buildProfileButton(),
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
          onPressed: () async {
            // Show notifications dialog
            await _showNotificationsDialog();
          },
        ),
        if (_unreadNotifications > 0)
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
                _unreadNotifications.toString(),
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

  Widget _buildProfileButton() {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.account_circle_outlined,
        color: Colors.white,
      ),
      onSelected: (value) async {
        switch (value) {
          case 'profile':
            // Navigate to profile screen
            break;
          case 'settings':
            // Navigate to settings screen
            break;
          case 'logout':
            await _showLogoutDialog();
            break;
        }
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person_outline),
              SizedBox(width: 8),
              Text('Profile'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings_outlined),
              SizedBox(width: 8),
              Text('Settings'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_outlined),
              SizedBox(width: 8),
              Text('Logout'),
            ],
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
              icon: Icon(Icons.verified_outlined),
              activeIcon: Icon(Icons.verified),
              label: 'Verify',
            ),
          ],
          currentIndex: _selectedIndex,
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

  Future<void> _showNotificationsDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('notifications')
                .where('userId', isEqualTo: user?.uid)
                .orderBy('timestamp', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Error loading notifications');
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final notifications = snapshot.data!.docs;

              if (notifications.isEmpty) {
                return const Text('No notifications');
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index].data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(notification['title'] ?? ''),
                    subtitle: Text(notification['message'] ?? ''),
                    leading: Icon(
                      notification['read'] ? Icons.mark_email_read : Icons.mark_email_unread,
                      color: notification['read'] ? Colors.grey : AppColors.primary,
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _markNotificationsAsRead();
              Navigator.pop(context);
            },
            child: const Text('Mark all as read'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutDialog() async {
    final bool shouldLogout = await Helpers.showConfirmationDialog(
      context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmText: 'Logout',
      cancelText: 'Cancel',
    );

    if (shouldLogout && mounted) {
      await FirebaseAuth.instance.signOut();
       Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
        );
    }
  }
}