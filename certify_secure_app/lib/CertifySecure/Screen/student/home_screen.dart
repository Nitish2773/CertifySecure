// lib/screens/student/home_screen.dart
import 'dart:async';
import 'package:certify_secure_app/CertifySecure/Screen/utils/constants.dart';
import 'package:certify_secure_app/CertifySecure/Screen/utils/helpers.dart';
import 'package:certify_secure_app/CertifySecure/Widgets/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
class StatusDetails {
  final IconData icon;
  final Color color;
  final String message;
  final String description;

  const StatusDetails({
    required this.icon,
    required this.color,
    required this.message,
    this.description = '',
  });

  static StatusDetails fromStatus(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return const StatusDetails(
          icon: Icons.verified,
          color: AppColors.success,
          message: 'Verified',
          description: 'Certificate verified on blockchain',
        );
      case 'pending':
        return const StatusDetails(
          icon: Icons.pending_actions,
          color: AppColors.warning,
          message: 'Pending',
          description: 'Verification in progress',
        );
      case 'rejected':
        return const StatusDetails(
          icon: Icons.cancel,
          color: AppColors.error,
          message: 'Rejected',
          description: 'Verification failed',
        );
      default:
        return const StatusDetails(
          icon: Icons.help_outline,
          color: Colors.grey,
          message: 'Unknown',
          description: 'Unknown status',
        );
    }
  }
}

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigate;

  const HomeScreen({
    super.key,
    this.onNavigate,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
 final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _profileSubscription;
   // Profile information
  String _displayName = '';
  String? _photoURL;
  String? _userCourse;
  String? _userBranch;
  
  // Statistics
  Map<String, dynamic> _stats = {
    'total': 0,
    'verified': 0,
    'pending': 0,
    'rejected': 0,
    'recentlyVerified': 0,
  };

  // Activity Filters
  String _selectedActivityFilter = 'all';
  final List<String> _activityFilters = ['all', 'verified', 'pending', 'rejected'];

  @override
  void initState() {
    super.initState();
    _loadUserStatistics();
    _setupProfileListener();
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }

  void _setupProfileListener() {
    if (_currentUser != null) {
      _profileSubscription = _firestore
          .collection('users')
          .doc(_currentUser.uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && mounted) {
          setState(() {
            _displayName = snapshot.data()?['name'] ?? _currentUser.displayName ?? 'Student';
            _photoURL = snapshot.data()?['imageUrl'] ?? _currentUser.photoURL;
          });
        }
      });
    }
  }

 Future<void> _loadUserStatistics() async {
    try {
      final QuerySnapshot certificatesSnapshot = await _firestore
          .collection(AppConstants.certificatesCollection)
          .where('userId', isEqualTo: _currentUser?.uid)
          .get();

      final docs = certificatesSnapshot.docs;
      
      if (mounted) {
        setState(() {
          _stats = {
            'total': docs.length,
            'verified': docs.where((doc) => doc['verificationStatus'] == 'verified').length,
            'pending': docs.where((doc) => doc['verificationStatus'] == 'pending').length,
            'rejected': docs.where((doc) => doc['verificationStatus'] == 'rejected').length,
            'recentlyVerified': docs.where((doc) {
              if (doc['verificationStatus'] != 'verified') return false;
              final verificationDate = (doc['verificationDate'] as Timestamp?)?.toDate();
              if (verificationDate == null) return false;
              return verificationDate.isAfter(DateTime.now().subtract(const Duration(days: 7)));
            }).length,
          };
        });
      }
    } catch (e) {
      debugPrint('Error loading statistics: $e');
    }
  }

  
  
  
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadUserStatistics();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 25),
            _buildStatisticsCards(),
            const SizedBox(height: 25),
            _buildQuickActions(),
            const SizedBox(height: 25),
            _buildRecentActivities(),
          ],
        ),
      ),
    );
  }


 Widget _buildWelcomeCard() {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.primary,
          AppColors.secondary,
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.3),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_userCourse != null && _userBranch != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      '$_userCourse - $_userBranch',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: () => widget.onNavigate?.call(4), // Navigate to profile
              child: Hero(
                tag: 'profileImage',
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  backgroundImage: _photoURL != null
                      ? NetworkImage(_photoURL!)
                      : null,
                  child: _photoURL == null
                      ? Icon(
                          Icons.person,
                          size: 35,
                          color: Colors.white.withOpacity(0.9),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_stats['recentlyVerified'] > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_stats['recentlyVerified']} certificates verified this week',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

  Widget _buildStatisticsCards() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Certificate Statistics",
                style: AppTextStyles.heading2,
              ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showStatisticsInfo(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Total",
                  _stats['total'].toString(),
                  Icons.folder,
                  AppColors.primary,
                  "All your certificates",
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildStatCard(
                  "Verified",
                  _stats['verified'].toString(),
                  Icons.verified,
                  AppColors.success,
                  "Blockchain verified",
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Pending",
                  _stats['pending'].toString(),
                  Icons.pending,
                  AppColors.warning,
                  "Awaiting verification",
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildStatCard(
                  "Rejected",
                  _stats['rejected'].toString(),
                  Icons.cancel,
                  AppColors.error,
                  "Failed verification",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStatisticsInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Certificate Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatInfo(
              'Total Certificates',
              'Total number of certificates you have uploaded',
              Icons.folder,
              AppColors.primary,
            ),
            const SizedBox(height: 10),
            _buildStatInfo(
              'Verified Certificates',
              'Certificates that have been verified on the blockchain',
              Icons.verified,
              AppColors.success,
            ),
            const SizedBox(height: 10),
            _buildStatInfo(
              'Pending Certificates',
              'Certificates waiting for verification',
              Icons.pending,
              AppColors.warning,
            ),
            const SizedBox(height: 10),
            _buildStatInfo(
              'Rejected Certificates',
              'Certificates that failed verification',
              Icons.cancel,
              AppColors.error,
            ),
          ],
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

  Widget _buildStatInfo(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }  
  
 Widget _buildQuickActions() {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 55) / 2;
    final aspectRatio = itemWidth / 155;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Actions",
          style: AppTextStyles.heading2,
        ),
        const SizedBox(height: 15),
        LayoutBuilder(
          builder: (context, constraints) {
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: aspectRatio,
              children: [
                _buildActionCard(
                  title: "Upload Certificate",
                  subtitle: "Add new certificates",
                  icon: Icons.upload_file,
                  color: AppColors.primary,
                  onTap: () => widget.onNavigate?.call(2),
                ),
                _buildActionCard(
                  title: "View Certificates",
                  subtitle: "Manage your certificates",
                  icon: Icons.folder,
                  color: AppColors.success,
                  onTap: () => widget.onNavigate?.call(3),
                ),
                _buildActionCard(
                  title: "Verify Certificate",
                  subtitle: "Check authenticity",
                  icon: Icons.verified_user,
                  color: AppColors.info,
                  onTap: () => _showVerificationDialog(context),
                ),
                _buildActionCard(
                  title: "Share Certificate",
                  subtitle: "Share with others",
                  icon: Icons.share,
                  color: AppColors.secondary,
                  onTap: () => _showShareOptions(context),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: color.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Recent Activities",
              style: AppTextStyles.heading2,
            ),
            TextButton(
              onPressed: () => widget.onNavigate?.call(3),
              child: const Text("View All"),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildActivityFilters(),
        const SizedBox(height: 15),
        StreamBuilder<QuerySnapshot>(
          stream: _getFilteredActivitiesStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorCard('Error loading activities');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingIndicator();
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _buildActivityCard(docs[index]),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActivityFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _activityFilters.map((filter) {
          final isSelected = _selectedActivityFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilterChip(
              label: Text(
                filter.capitalize(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedActivityFilter = filter);
              },
              backgroundColor: Colors.grey[200],
              selectedColor: AppColors.primary,
              checkmarkColor: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }

  Stream<QuerySnapshot> _getFilteredActivitiesStream() {
    Query query = _firestore
        .collection(AppConstants.certificatesCollection)
        .where('userId', isEqualTo: _currentUser?.uid);

    if (_selectedActivityFilter != 'all') {
      query = query.where('verificationStatus', isEqualTo: _selectedActivityFilter);
    }

    return query
        .orderBy('uploadedAt', descending: true)
        .limit(5)
        .snapshots();
  }

  Widget _buildActivityCard(DocumentSnapshot doc) {
    final status = doc['verificationStatus'] as String;
    final statusDetails = _getStatusDetails(status);
    final date = (doc['uploadedAt'] as Timestamp).toDate();
    final certificateType = doc['certificateType'] as String? ?? 'Certificate';

    return InkWell(
      onTap: () => _showCertificateDetails(doc),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusDetails.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                statusDetails.icon,
                color: statusDetails.color,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc['name'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusDetails.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: statusDetails.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        certificateType,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateFormat('MMM d').format(date),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  DateFormat('h:mm a').format(date),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }  // Helper Classes
 

  // Helper Methods
  StatusDetails _getStatusDetails(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return const StatusDetails(
          icon: Icons.verified,
          color: AppColors.success,
          message: 'Certificate verified on blockchain',
        );
      case 'pending':
        return const StatusDetails(
          icon: Icons.pending_actions,
          color: AppColors.warning,
          message: 'Verification in progress',
        );
      case 'rejected':
        return const StatusDetails(
          icon: Icons.cancel,
          color: AppColors.error,
          message: 'Verification failed',
        );
      default:
        return const StatusDetails(
          icon: Icons.help_outline,
          color: Colors.grey,
          message: 'Unknown status',
        );
    }
  }

  void _showCertificateDetails(DocumentSnapshot doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildCertificateDetailsSheet(doc),
    );
  }

  Widget _buildCertificateDetailsSheet(DocumentSnapshot doc) {
    final status = doc['verificationStatus'] as String;
    final statusDetails = _getStatusDetails(status);
    final uploadDate = (doc['uploadedAt'] as Timestamp).toDate();
    final verificationDate = (doc['verificationDate'] as Timestamp?)?.toDate();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Certificate Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          _buildDetailItem('Name', doc['name'] as String),
          _buildDetailItem('Type', doc['certificateType'] as String),
          _buildDetailItem('Issued By', doc['issuedBy'] as String),
          _buildDetailItem(
            'Upload Date',
            DateFormat('MMM d, yyyy h:mm a').format(uploadDate),
          ),
          if (verificationDate != null)
            _buildDetailItem(
              'Verification Date',
              DateFormat('MMM d, yyyy h:mm a').format(verificationDate),
            ),
          _buildDetailItem(
            'Status',
            status.toUpperCase(),
            color: statusDetails.color,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  label: 'View Certificate',
                  icon: Icons.remove_red_eye,
                  color: AppColors.primary,
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onNavigate?.call(3);
                  },
                ),
              ),
              if (status == 'verified') ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionButton(
                    label: 'Share',
                    icon: Icons.share,
                    color: AppColors.secondary,
                    onPressed: () {
                      Navigator.pop(context);
                      _showShareOptions(context, doc);
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showVerificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Certificate'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter certificate ID or upload certificate to verify'),
            SizedBox(height: 15),
            TextField(
              decoration: InputDecoration(
                labelText: 'Certificate ID',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement verification logic
              Navigator.pop(context);
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _showShareOptions(BuildContext context, [DocumentSnapshot? doc]) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share Certificate',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildShareOption(
                  icon: Icons.link,
                  label: 'Copy Link',
                  onTap: () {
                    // Implement copy link
                    Navigator.pop(context);
                    Helpers.showSnackBar(
                      context,
                      'Link copied to clipboard',
                    );
                  },
                ),
                _buildShareOption(
                  icon: Icons.qr_code,
                  label: 'QR Code',
                  onTap: () {
                    // Implement QR code sharing
                    Navigator.pop(context);
                  },
                ),
                _buildShareOption(
                  icon: Icons.share,
                  label: 'Share',
                  onTap: () {
                    // Implement general sharing
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open,
            size: 60,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 15),
          Text(
            'No Certificates Yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Start by uploading your first certificate',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => widget.onNavigate?.call(2),
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload Certificate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.error.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 40,
            color: AppColors.error,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.error,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// In HomeScreen class



extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}


  Widget _buildStatCard(
    String title,
    String count,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

    Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isFullWidth = false,
  }) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton.icon(
        icon: Icon(
          icon,
          color: Colors.white,
        ),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
        ),
      ),
    );
  }


