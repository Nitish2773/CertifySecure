import 'dart:async';
import 'package:certify_secure_app/CertifySecure/Screen/utils/constants.dart';
import 'package:certify_secure_app/CertifySecure/Screen/utils/helpers.dart';
import 'package:certify_secure_app/CertifySecure/Widgets/loading_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';



class StatusDetails {
  final IconData icon;
  final Color color;
  final String message;

  const StatusDetails({
    required this.icon,
    required this.color,
    required this.message,
  });
}
class TeacherHomeScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  final Map<String, dynamic> teacherData;
  final int pendingCount;
  final int verifiedCount;

  const TeacherHomeScreen({
    super.key,
    this.onNavigate,
    required this.teacherData,
    required this.pendingCount,
    required this.verifiedCount,
  });

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add these state variables
  int _pendingCount = 0;
  int _verifiedCount = 0;

  // Filters
  String _selectedSection = 'All';
  String _selectedBatch = 'All';
  String _certificateType = 'All';

  // Statistics
  Map<String, int> _sectionStats = {};
  Map<String, int> _batchStats = {};
  Map<String, int> _typeStats = {};

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _setupPeriodicRefresh();
  }

  void _initializeData() async {
    try {
      await Future.wait([
        _loadDetailedStats(),
           _loadCertificateCounts(),
      ]);
    } catch (e) {
      setState(() {
        _error = 'Failed to load dashboard data';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setupPeriodicRefresh() {
    Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) {
        _loadDetailedStats();
         _loadCertificateCounts(); 
      }
    });
  }

  Future<void> _loadDetailedStats() async {
    try {
      final certificatesQuery = await _firestore
          .collection(AppConstants.certificatesCollection)
          .where('studentDetails.department',
              isEqualTo: widget.teacherData['department'])
          .get();

      if (!mounted) return;

      final certificates = certificatesQuery.docs;

      Map<String, int> sectionStats = {};
      Map<String, int> batchStats = {};
      Map<String, int> typeStats = {};

      for (var cert in certificates) {
        final data = cert.data();
        final studentDetails = data['studentDetails'] as Map<String, dynamic>;
        final certificateDetails =
            data['certificateDetails'] as Map<String, dynamic>;

        final section = studentDetails['section'] ?? 'Unknown';
        final batch = studentDetails['batch'] ?? 'Unknown';
        final type = certificateDetails['type'] ?? 'Unknown';

        sectionStats[section] = (sectionStats[section] ?? 0) + 1;
        batchStats[batch] = (batchStats[batch] ?? 0) + 1;
        typeStats[type] = (typeStats[type] ?? 0) + 1;
      }

      setState(() {
        _sectionStats = sectionStats;
        _batchStats = batchStats;
        _typeStats = typeStats;
      });
    } catch (e) {
      debugPrint('Error loading detailed stats: $e');
    }
  }


  Future<void> _loadCertificateCounts() async {
    try {
      // Get pending certificates count
      final pendingQuery = await _firestore
          .collection('certificates')
          .where('verificationStatus',
              isEqualTo: 'pending') // Changed from status to verificationStatus
          .where('studentDetails.department',
              isEqualTo: widget.teacherData['department'])
          .count()
          .get();

      // Get verified certificates count
      final verifiedQuery = await _firestore
          .collection('certificates')
          .where('verificationStatus', isEqualTo: 'verified')
          .where('studentDetails.department',
              isEqualTo: widget.teacherData['department'])
          .count()
          .get();

      setState(() {
        _pendingCount = pendingQuery.count ?? 0;
        _verifiedCount = verifiedQuery.count ?? 0;
      });
    } catch (e) {
      debugPrint('Error loading certificate counts: $e');
    }
  }

  void _updateFilters(String? value, String filterType) {
    setState(() {
      switch (filterType) {
        case 'section':
          _selectedSection = value ?? 'All';
          break;
        case 'batch':
          _selectedBatch = value ?? 'All';
          break;
        case 'type':
          _certificateType = value ?? 'All';
          break;
      }
    });
    _loadDetailedStats();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: LoadingIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            ElevatedButton(
              onPressed: _initializeData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

     return RefreshIndicator(
    onRefresh: () async {
      _initializeData();  // Use existing method instead of _refreshData
    },
    child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 25),
          _buildDepartmentInfo(),
          const SizedBox(height: 25),
          _buildFilters(),
          const SizedBox(height: 25),
          _buildStatisticsCards(),
          const SizedBox(height: 25),
          _buildDetailedStats(),
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
                      'Welcome, ${widget.teacherData['name'] ?? 'Teacher'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.teacherData['designation'] ?? 'Teacher',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
                  Icons.pending_actions,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.pendingCount} certificates pending verification',
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 30, color: color),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: color.withOpacity(0.8),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentInfo() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.business,
            color: AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Department: ${widget.teacherData['department'] ?? 'Not Specified'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sections: ${(widget.teacherData['sections'] as List?)?.join(", ") ?? "All"}',
                  style: TextStyle(
                    color: Colors.grey[600],
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

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Filters",
          style: AppTextStyles.heading2,
        ),
        const SizedBox(height: 15),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterDropdown(
                "Section",
                _selectedSection,
                ['All', ..._sectionStats.keys],
                (value) => _updateFilters(value, 'section'),
              ),
              const SizedBox(width: 10),
              _buildFilterDropdown(
                "Batch",
                _selectedBatch,
                ['All', ..._batchStats.keys],
                (value) => _updateFilters(value, 'batch'),
              ),
              const SizedBox(width: 10),
              _buildFilterDropdown(
                "Certificate Type",
                _certificateType,
                ['All', ..._typeStats.keys],
                (value) => _updateFilters(value, 'type'),
              ),
            ],
          ),
        ),
      ],
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
                "Certificate Overview",
                style: AppTextStyles.heading2,
              ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showStatisticsInfo(context),
                tooltip: 'Statistics Information',
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 15) / 2;

              return Row(
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildStatCard(
                      "Total Pending",
                      widget.pendingCount.toString(),
                      Icons.pending_actions,
                      AppColors.warning,
                      "Awaiting Verification",
                    ),
                  ),
                  const SizedBox(width: 15),
                  SizedBox(
                    width: cardWidth,
                    child: _buildStatCard(
                      "Verified",
                      widget.verifiedCount.toString(),
                      Icons.verified,
                      AppColors.success,
                      "Successfully Verified",
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> items,
    void Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<String>(
        value: value,
        items: items.map((String item) {
          return DropdownMenuItem(
            value: item,
            child: Text(
              item,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 14,
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        underline: const SizedBox(),
        hint: Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        icon: const Icon(
          Icons.arrow_drop_down,
          color: AppColors.primary,
        ),
        isDense: true,
        isExpanded: false,
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(10),
        style: TextStyle(
          color: Colors.grey[800],
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildDetailedStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Detailed Statistics",
              style: AppTextStyles.heading2,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadDetailedStats,
              tooltip: 'Refresh Statistics',
            ),
          ],
        ),
        const SizedBox(height: 15),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildStatisticsBox(
                "Section-wise",
                _sectionStats,
                Icons.group,
                AppColors.primary,
              ),
              const SizedBox(width: 15),
              _buildStatisticsBox(
                "Batch-wise",
                _batchStats,
                Icons.school,
                AppColors.secondary,
              ),
              const SizedBox(width: 15),
              _buildStatisticsBox(
                "Type-wise",
                _typeStats,
                Icons.category,
                AppColors.accent,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Actions",
          style: AppTextStyles.heading2,
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: "Pending Verification",
                subtitle: "${widget.pendingCount} certificates waiting",
                icon: Icons.pending_actions,
                color: AppColors.warning,
                onTap: () => widget.onNavigate?.call(1),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildActionCard(
                title: "Verified Certificates",
                subtitle: "View verified certificates",
                icon: Icons.verified,
                color: AppColors.success,
                onTap: () => widget.onNavigate?.call(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: "Department Reports",
                subtitle: "View detailed reports",
                icon: Icons.analytics,
                color: AppColors.info,
                onTap: () => _showDepartmentReports(),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildActionCard(
                title: "Student Search",
                subtitle: "Search by roll number",
                icon: Icons.search,
                color: AppColors.secondary,
                onTap: () => _showStudentSearch(),
              ),
            ),
          ],
        ),
      ],
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
            TextButton.icon(
              onPressed: () => widget.onNavigate?.call(1),
              icon: const Icon(Icons.visibility),
              label: const Text("View All"),
            ),
          ],
        ),
        const SizedBox(height: 15),
        StreamBuilder<QuerySnapshot>(
          // Direct query here instead of separate method
          stream: _firestore
              .collection('certificates')
              .where('studentDetails.department', 
                    isEqualTo: widget.teacherData['department'])
              .orderBy('uploadedAt', descending: true)
              .limit(5)
              .snapshots(),
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

  // Helper Methods
  void _showDepartmentReports() {
    // TODO: Implement department reports dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Department Reports'),
        content: const Text('Department reports feature coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showStudentSearch() {
    // TODO: Implement student search dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Student Search'),
        content: const Text('Student search feature coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showStatisticsInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Statistics Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatInfo(
              'Pending Certificates',
              'Certificates waiting for verification',
              Icons.pending_actions,
              AppColors.warning,
            ),
            const SizedBox(height: 10),
            _buildStatInfo(
              'Verified Certificates',
              'Successfully verified certificates',
              Icons.verified,
              AppColors.success,
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

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
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
            'No Certificates Found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'No certificates match the selected filters',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

 

Widget _buildActivityCard(DocumentSnapshot doc) {
  try {
    final data = doc.data() as Map<String, dynamic>;
    final studentDetails = data['studentDetails'] as Map<String, dynamic>;
    final status = data['verificationStatus'] as String;
    final uploadDate = (data['uploadedAt'] as Timestamp).toDate();

    // Get color and icon based on status
    final Color statusColor = status == 'verified' 
        ? AppColors.success 
        : status == 'pending' 
            ? AppColors.warning 
            : AppColors.error;
            
    final IconData statusIcon = status == 'verified'
        ? Icons.verified
        : status == 'pending'
            ? Icons.pending_actions
            : Icons.cancel;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(
            statusIcon,
            color: statusColor,
          ),
        ),
        title: Text(
          data['name'] ?? 'Unnamed Certificate',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student: ${studentDetails['name']}'),
            Text('Roll No: ${studentDetails['rollNumber']}'),
            Text('Uploaded: ${Helpers.getTimeAgo(uploadDate)}'),
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.grey[400],
        ),
        onTap: () => _showCertificateDetails(doc),
      ),
    );
  } catch (e) {
    debugPrint('Error building activity card: $e');
    return const SizedBox.shrink();
  }
}



  void _showCertificateDetails(DocumentSnapshot doc) {
    // TODO: Implement certificate details dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Certificate Details'),
        content: const Text('Certificate details feature coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
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
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsBox(
    String title,
    Map<String, int> stats,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 200,
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
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ...stats.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        entry.value.toString(),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          if (stats.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'No data available',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
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
}


