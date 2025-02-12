import 'dart:async';

import 'package:certify_secure_app/CertifySecure/Screen/company/company_home_screen.dart';
import 'package:certify_secure_app/CertifySecure/Screen/company/verify_certificates_screen.dart';
import 'package:certify_secure_app/CertifySecure/Screen/company/company_profile_screen.dart';
import 'package:certify_secure_app/CertifySecure/Screen/company/company_settings_screen.dart';
import 'package:certify_secure_app/CertifySecure/Screen/main/role_selection_screen.dart';
import 'package:certify_secure_app/CertifySecure/Screen/utils/constants.dart';
import 'package:certify_secure_app/CertifySecure/Screen/utils/helpers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Navigation Enum
enum DashboardTab {
  home,
  verify,
}

class CompanyData {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? industry;
  final String? location;
  final String? description;
  final String? website;
  final String? profileImage;
  final bool isVerified;
  final DateTime joinedDate;

  CompanyData({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.industry,
    this.location,
    this.description,
    this.website,
    this.profileImage,
    this.isVerified = false,
    required this.joinedDate,
  });

  // Custom Exceptions
  static void validateData(Map<String, dynamic> data) {
    if (data['name'] == null || data['name'].toString().trim().isEmpty) {
      throw ValidationException('Company name is required');
    }

    if (data['email'] == null || !data['email'].toString().contains('@')) {
      throw ValidationException('Valid email is required');
    }
  }

  factory CompanyData.fromFirestore(Map<String, dynamic> data, String id) {
    try {
      // Validate data before creating the object
      validateData(data);

      return CompanyData(
        id: id,
        name: (data['name'] as String? ?? '').trim().isEmpty
            ? 'Unnamed Company'
            : (data['name'] as String).trim(),
        email: (data['email'] as String? ?? '').trim().isEmpty
            ? 'unknown@example.com'
            : (data['email'] as String).trim(),
        phone: data['phone'],
        industry: data['industry'],
        location: data['location'],
        description: data['description'],
        website: data['website'],
        profileImage: data['profileImage'],
        isVerified: data['isVerified'] ?? false,
        joinedDate: data['joinedDate'] is Timestamp
            ? (data['joinedDate'] as Timestamp).toDate()
            : DateTime.now(),
      );
    } catch (e) {
      // Fallback to a default object if validation fails
      return CompanyData(
        id: id,
        name: 'Unnamed Company',
        email: 'unknown@example.com',
        joinedDate: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'industry': industry,
      'location': location,
      'description': description,
      'website': website,
      'profileImage': profileImage,
      'isVerified': isVerified,
      'joinedDate': Timestamp.fromDate(joinedDate)
    };
  }
}

// Custom Exceptions
class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);

  @override
  String toString() => message;
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}


class CompanyDashboard extends StatefulWidget {
  const CompanyDashboard({super.key});

  @override
  State<CompanyDashboard> createState() => _CompanyDashboardState();
}

class _CompanyDashboardState extends State<CompanyDashboard>
    with TickerProviderStateMixin {
  // Firebase and Controller Instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Animation Controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // State Variables
  DashboardTab _currentTab = DashboardTab.home;
  CompanyData? _companyData;
  bool _isLoading = true;
  bool _isInitialized = false;
  int _unreadNotifications = 0;
  String _errorMessage = '';

  // Screen Instances
  late final Map<DashboardTab, Widget> _screens;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Check internet connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('No internet connection');
      }

      // Validate user authentication
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthException('No authenticated user found');
      }

      // Parallel initialization
      await Future.wait<void>([
        _initializeAnimation(),
        _fetchCompanyData(user),
        _setupNotificationListener(),
      ], eagerError: true);

      // Initialize screens
      _initializeScreens();

      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      _handleInitializationError(e);
    }
  }

  Future<void> _initializeAnimation() async {
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

    await _animationController.forward();
  }

  Future<void> _fetchCompanyData(User user) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Connection timeout'),
          );

      if (!doc.exists) {
        throw Exception('Company profile not found');
      }

      final data = doc.data();
      if (data == null) {
        throw Exception('Empty company profile');
      }

      final companyData = CompanyData.fromFirestore(data, user.uid);

      setState(() {
        _companyData = companyData;
      });
    } catch (e) {
      print('Error fetching company data: $e');
      rethrow;
    }
  }

  void _initializeScreens() {
    if (_companyData == null) return;

    _screens = {
      DashboardTab.home: CompanyHomeScreen(companyData: _companyData!.toMap()),
      DashboardTab.verify: const VerifyCertificatesScreen(),
    };
  }

  void _handleInitializationError(dynamic error) {
    print('Dashboard initialization failed: $error');
    
    setState(() {
      _isLoading = false;
      _isInitialized = false;
      _errorMessage = _getErrorMessage(error);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is AuthException) {
      return 'Authentication failed. Please log in again.';
    }

    if (error is TimeoutException) {
      return 'Connection timeout. Please check your network.';
    }

    return error?.toString() ?? 'An unknown error occurred';
  }

  // Rest of the methods will be in the next parts...
   @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_errorMessage.isNotEmpty) {
      return _buildErrorScreen();
    }

    if (!_isInitialized || _companyData == null) {
      return _buildUninitializedScreen();
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
                      child: _screens[_currentTab],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Initializing Dashboard...',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'Dashboard Initialization Failed',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeDashboard,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUninitializedScreen() {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Preparing Dashboard...',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
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
                  const SizedBox(height: 4),
                  Text(
                    _companyData?.name ?? "Company",
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
          if (_companyData?.isVerified ?? false) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Verified Company',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
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
          currentIndex: _currentTab.index,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          onTap: (index) => _onTabChanged(DashboardTab.values[index]),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return _currentTab == DashboardTab.verify
        ? FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VerifyCertificatesScreen(),
                ),
              );
            },
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add),
            label: const Text('New Verification'),
          )
        : const SizedBox.shrink();
  }

  

  void _onTabChanged(DashboardTab tab) {
    setState(() {
      _currentTab = tab;
      _animationController.reset();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Notification Related Methods
  Future<void> _setupNotificationListener() async {
    _firestore
        .collection('notifications')
        .where('userId', isEqualTo: _auth.currentUser?.uid)
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

  Widget _buildNotificationBadge() {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          color: Colors.white,
          onPressed: _showNotificationsPanel,
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

  void _showNotificationsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NotificationsPanel(
        userId: _auth.currentUser?.uid ?? '',
        onMarkAllRead: _markNotificationsAsRead,
      ),
    );
  }

  Future<void> _markNotificationsAsRead() async {
    try {
      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .where('read', isEqualTo: false)
          .get();

      for (var doc in notifications.docs) {
        batch.update(doc.reference, {'read': true});
      }

      await batch.commit();
    } catch (e) {
      print('Error marking notifications as read: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to mark notifications as read')),
      );
    }
  }

  // Profile Related Methods
  Widget _buildProfileButton() {
    return GestureDetector(
      onTap: _showProfileOptions,
      child: Container(
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
          backgroundImage: _companyData?.profileImage != null
              ? NetworkImage(_companyData!.profileImage!)
              : null,
          child: _companyData?.profileImage == null
              ? _buildInitials()
              : null,
        ),
      ),
    );
  }

  Widget _buildInitials() {
    if (_companyData?.name == null || _companyData!.name.isEmpty) {
      return const Text(
        'C',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Text(
      _companyData!.name.substring(0, 1).toUpperCase(),
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  void _showProfileOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ProfileOptionsSheet(
        companyData: _companyData!,
        onLogout: _handleLogout,
        onEditProfile: _navigateToProfile,
        onSettings: _navigateToSettings,
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await _performLogout();
    }
  }

  Future<void> _performLogout() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      print('Error during logout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to logout')),
        );
      }
    }
  }

  void _navigateToProfile() {
    Navigator.pop(context); // Close bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompanyProfileScreen(
          companyData: _companyData!,
          onProfileUpdated: _handleProfileUpdate,
        ),
      ),
    );
  }

  void _navigateToSettings() {
    Navigator.pop(context); // Close bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompanySettingsScreen(
          companyData: _companyData!,
          onSettingsUpdated: _handleSettingsUpdate,
        ),
      ),
    );
  }

  Future<void> _handleProfileUpdate(CompanyData updatedData) async {
    setState(() {
      _companyData = updatedData;
    });
    await _refreshDashboard();
  }

  Future<void> _handleSettingsUpdate(Map<String, dynamic> settings) async {
    // Handle settings update
    await _refreshDashboard();
  }

  Future<void> _refreshDashboard() async {
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _fetchCompanyData(user);
        _initializeScreens();
      }
    } catch (e) {
      print('Error refreshing dashboard: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to refresh dashboard')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }


}

// Notifications Panel
class _NotificationsPanel extends StatelessWidget {
  final String userId;
  final VoidCallback onMarkAllRead;

  const _NotificationsPanel({
    required this.userId,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildNotificationHeader(context),
              Expanded(
                child: _buildNotificationsList(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
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
                onPressed: onMarkAllRead,
                child: const Text('Mark all as read'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(ScrollController scrollController) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final notifications = snapshot.data?.docs ?? [];

        if (notifications.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            return _buildNotificationItem(
              notifications[index].data() as Map<String, dynamic>,
              notifications[index].id,
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationItem(
      Map<String, dynamic> notification, String notificationId) {
    final bool isRead = notification['read'] ?? false;
    final timestamp = (notification['timestamp'] as Timestamp).toDate();

    return Dismissible(
      key: Key(notificationId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
        ),
      ),
      onDismissed: (direction) {
        _deleteNotification(notificationId);
      },
      child: Card(
        elevation: isRead ? 0 : 2,
        color: isRead ? Colors.white : Colors.blue[50],
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getNotificationColor(notification['type']),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getNotificationIcon(notification['type']),
              color: Colors.white,
              size: 20,
            ),
          ),
          title: Text(
            notification['title'] ?? '',
            style: TextStyle(
              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notification['message'] ?? ''),
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
          onTap: () => _handleNotificationTap(notification, notificationId),
        ),
      ),
    );
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'verification':
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
      case 'verification':
        return Icons.verified_user;
      case 'warning':
        return Icons.warning;
      case 'error':
        return Icons.error;
      default:
        return Icons.notifications;
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  void _handleNotificationTap(
      Map<String, dynamic> notification, String notificationId) {
    // Mark as read
    FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});

    // Handle navigation based on notification type
    if (notification['metadata'] != null) {
      _handleNotificationNavigation(
          notification['type'], notification['metadata']);
    }
  }

  void _handleNotificationNavigation(
      String? type, Map<String, dynamic> metadata) {
    // Implement navigation logic based on notification type
    // For example:
    // if (type == 'verification') {
    //   Navigator.push(context, MaterialPageRoute(
    //     builder: (context) => CertificateDetailsScreen(
    //       certificateId: metadata['certificateId']
    //     )
    //   ));
    // }
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load notifications',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// Profile Options Sheet
class _ProfileOptionsSheet extends StatelessWidget {
  final CompanyData companyData;
  final VoidCallback onLogout;
  final VoidCallback onEditProfile;
  final VoidCallback onSettings;

  const _ProfileOptionsSheet({
    required this.companyData,
    required this.onLogout,
    required this.onEditProfile,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          _buildProfileHeader(),
          const SizedBox(height: 20),
          _buildOptionsList(context),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: AppColors.primary.withOpacity(0.1),
          backgroundImage: companyData.profileImage != null
              ? NetworkImage(companyData.profileImage!)
              : null,
          child: companyData.profileImage == null
              ? Text(
                  companyData.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                companyData.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                companyData.email,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              if (companyData.industry != null) ...[
                const SizedBox(height: 4),
                Text(
                  companyData.industry!,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsList(BuildContext context) {
    return Column(
      children: [
        _buildOptionTile(
          icon: Icons.person_outline,
          title: 'Edit Profile',
          onTap: onEditProfile,
        ),
        _buildOptionTile(
          icon: Icons.settings_outlined,
          title: 'Settings',
          onTap: onSettings,
        ),
        _buildOptionTile(
          icon: Icons.help_outline,
          title: 'Help & Support',
          onTap: () => _showHelpSupport(context),
        ),
        _buildOptionTile(
          icon: Icons.info_outline,
          title: 'About',
          onTap: () => _showAboutDialog(context),
        ),
        const Divider(),
        _buildOptionTile(
          icon: Icons.logout,
          title: 'Logout',
          onTap: onLogout,
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? AppColors.error : Colors.grey[600],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? AppColors.error : Colors.black,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 20,
      ),
      onTap: onTap,
    );
  }

  void _showHelpSupport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _HelpSupportSheet(),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AboutDialog(
        applicationName: 'CertifySecure',
        applicationVersion: '1.0.0',
        applicationIcon: Image.asset(
          'assets/images/logo.png',
          width: 50,
          height: 50,
        ),
        children: const [
          Text(
            'CertifySecure is a certificate verification platform that helps '
            'companies verify educational certificates securely and efficiently.',
          ),
        ],
      ),
    );
  }
}

class _HelpSupportSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSupportSection(
                      'FAQs',
                      Icons.question_answer_outlined,
                      _buildFAQList(),
                    ),
                    const SizedBox(height: 20),
                    _buildSupportSection(
                      'Contact Us',
                      Icons.contact_support_outlined,
                      _buildContactOptions(),
                    ),
                    const SizedBox(height: 20),
                    _buildSupportSection(
                      'Resources',
                      Icons.library_books_outlined,
                      _buildResourcesList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Help & Support',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection(
    String title,
    IconData icon,
    Widget content,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        content,
      ],
    );
  }

  Widget _buildFAQList() {
    return Column(
      children: [
        _buildFAQItem(
          'How do I verify a certificate?',
          'To verify a certificate, go to the Verify tab and enter the certificate details. '
          'You can scan the QR code or manually input the certificate number.',
        ),
        _buildFAQItem(
          'What types of certificates can be verified?',
          'Our platform supports verification of educational certificates, '
          'professional certifications, and training completion certificates '
          'from various institutions and organizations.',
        ),
        _buildFAQItem(
          'How secure is the verification process?',
          'We use advanced blockchain technology and encryption to ensure '
          'the authenticity and integrity of every certificate. Each '
          'verification is securely logged and cannot be tampered with.',
        ),
        _buildFAQItem(
          'What happens if a certificate is found to be fraudulent?',
          'If a certificate is identified as fraudulent, our system will '
          'flag it immediately. The issuing institution will be notified, '
          'and appropriate actions will be taken.',
        ),
      ],
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            answer,
            style: TextStyle(
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactOptions() {
    return Column(
      children: [
        _buildContactOption(
          'Email Support',
          'support@certifysecure.com',
          Icons.email_outlined,
          () => _launchEmail(),
        ),
        _buildContactOption(
          'Phone Support',
          '+1 (555) 123-4567',
          Icons.phone_outlined,
          () => _launchPhone(),
        ),
        _buildContactOption(
          'Live Chat',
          'Start a conversation',
          Icons.chat_outlined,
          () => _startLiveChat(),
        ),
      ],
    );
  }

  Widget _buildContactOption(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  // Placeholder methods for contact actions
  void _launchEmail() {
    // Implement email launch logic
    // Example: launch('mailto:support@certifysecure.com');
  }

  void _launchPhone() {
    // Implement phone call logic
    // Example: launch('tel:+15551234567');
  }

  void _startLiveChat() {
    // Implement live chat logic
    // Could open a chat interface or external chat service
  }

  Widget _buildResourcesList() {
    return Column(
      children: [
        _buildResourceItem(
          'User Guide',
          'Comprehensive guide to using CertifySecure',
          Icons.book_outlined,
          () {
            // Open user guide
          },
        ),
        _buildResourceItem(
          'Video Tutorials',
          'Step-by-step video guides',
          Icons.play_circle_outline,
          () {
            // Open video tutorials
          },
        ),
        _buildResourceItem(
          'API Documentation',
          'Technical documentation for developers',
          Icons.code,
          () {
            // Open API docs
          },
        ),
      ],
    );
  }

  Widget _buildResourceItem(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}