import 'package:certify_secure_app/CertifySecure/Screen/company/verify_certificates_screen.dart';
import 'package:certify_secure_app/CertifySecure/Screen/utils/constants.dart';
import 'package:certify_secure_app/CertifySecure/Screen/utils/helpers.dart';
import 'package:certify_secure_app/CertifySecure/Widgets/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class VerificationAnalytics {
  final int totalVerifications;
  final int successfulVerifications;
  final int failedVerifications;
  final double successRate;

  VerificationAnalytics({
    required this.totalVerifications,
    required this.successfulVerifications,
    required this.failedVerifications,
    required this.successRate,
  });
}

class CompanyHomeScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const CompanyHomeScreen({
    super.key,
    required this.companyData,
  });

  @override
  State<CompanyHomeScreen> createState() => _CompanyHomeScreenState();
}

class _CompanyHomeScreenState extends State<CompanyHomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
   bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isExporting = false;
  bool _isSearching = false;
  String _searchQuery = '';
  String _selectedFilter = 'all';
  VerificationAnalytics? _analytics;
  Map<String, dynamic>? _stats;
  // Add these to your state variables
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isRefreshing = true);
      await Future.wait([
        _fetchStats(),
        _fetchAnalytics(),
      ]);
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _refreshData() async {
    await _loadInitialData();
  }

  Future<void> _fetchStats() async {
    try {
      final stats = await _getVerificationStats();
      setState(() => _stats = stats);
    } catch (e) {
      print('Error fetching stats: $e');
    }
  }

  Future<void> _fetchAnalytics() async {
    try {
      final analytics = await _getAnalytics();
      setState(() => _analytics = analytics);
    } catch (e) {
      print('Error fetching analytics: $e');
    }
  }

  Future<Map<String, dynamic>> _getVerificationStats() async {
    try {
      final QuerySnapshot verifications = await _firestore
          .collection('verifications')
          .where('companyId', isEqualTo: _auth.currentUser?.uid)
          .get();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final thisMonth = DateTime(now.year, now.month, 1);

      int todayCount = 0;
      int monthCount = 0;
      int totalCount = verifications.size;

      for (var doc in verifications.docs) {
        final verificationDate = (doc['verifiedAt'] as Timestamp).toDate();
        if (verificationDate.isAfter(today)) {
          todayCount++;
        }
        if (verificationDate.isAfter(thisMonth)) {
          monthCount++;
        }
      }

      return {
        'total': totalCount,
        'today': todayCount,
        'month': monthCount,
      };
    } catch (e) {
      print('Error getting verification stats: $e');
      return {
        'total': 0,
        'today': 0,
        'month': 0,
      };
    }
  }

  Future<VerificationAnalytics> _getAnalytics() async {
    try {
      final verifications = await _firestore
          .collection('verifications')
          .where('companyId', isEqualTo: _auth.currentUser?.uid)
          .get();

      final successful =
          verifications.docs.where((doc) => doc['status'] == 'verified').length;
      final failed =
          verifications.docs.where((doc) => doc['status'] == 'failed').length;
      final total = verifications.size;

      return VerificationAnalytics(
        totalVerifications: total,
        successfulVerifications: successful,
        failedVerifications: failed,
        successRate: total > 0 ? (successful / total) * 100 : 0,
      );
    } catch (e) {
      print('Error getting analytics: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeCard(),
                    const SizedBox(height: 20),
                    _buildSearchAndFilter(),
                    const SizedBox(height: 20),
                    _buildQuickActions(),
                    const SizedBox(height: 25),
                    _buildStatisticsSection(),
                    const SizedBox(height: 25),
                    _buildRecentActivity(),
                  ],
                ),
              ),
            ),
            if (_isRefreshing)
              Container(
                color: Colors.black.withOpacity(0.1),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const VerifyCertificatesScreen (),
              ),
            );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.verified_user),
        label: const Text('Verify New'),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
                      widget.companyData['name'] ?? 'Company',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.companyData['email'] ?? '',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
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
                  Icons.business,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_user,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Verified Company',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (_stats != null) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickStat(
                  'Today',
                  _stats!['today'].toString(),
                  Icons.today,
                ),
                _buildQuickStat(
                  'This Month',
                  _stats!['month'].toString(),
                  Icons.calendar_today,
                ),
                _buildQuickStat(
                  'Total',
                  _stats!['total'].toString(),
                  Icons.assessment,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.9),
          size: 20,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search verifications...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(Icons.filter_list),
            ),
            onSelected: (value) {
              setState(() => _selectedFilter = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('All Time'),
              ),
              const PopupMenuItem(
                value: 'today',
                child: Text('Today'),
              ),
              const PopupMenuItem(
                value: 'week',
                child: Text('This Week'),
              ),
              const PopupMenuItem(
                value: 'month',
                child: Text('This Month'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Verification Statistics",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        if (_analytics != null) ...[
          _buildAnalyticsCards(),
          const SizedBox(height: 20),
          _buildAnalyticsChart(),
        ] else
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildAnalyticsCards() {
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
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Total Verifications",
                  _analytics!.totalVerifications.toString(),
                  Icons.fact_check,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildStatCard(
                  "Successful",
                  _analytics!.successfulVerifications.toString(),
                  Icons.check_circle,
                  AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Failed",
                  _analytics!.failedVerifications.toString(),
                  Icons.error,
                  AppColors.error,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildStatCard(
                  "Success Rate",
                  "${_analytics!.successRate.toStringAsFixed(1)}%",
                  Icons.trending_up,
                  AppColors.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsChart() {
    return Container(
      height: 200,
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
          const Text(
            "Verification Trend",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _buildTrendChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart() {
    // Here you would implement your chart using a charting library
    // For example, using fl_chart or charts_flutter
    return Center(
      child: Text(
        'Chart will be implemented here',
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickActionButton(
            icon: Icons.verified,
            label: 'Verify New',
            onTap: () {
              Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const VerifyCertificatesScreen(),
            ),
          );
            },
          ),
          _buildQuickActionButton(
            icon: Icons.history,
            label: 'History',
            onTap: () {
              Navigator.pushNamed(context, '/verification-history');
            },
          ),
          _buildQuickActionButton(
            icon: Icons.analytics,
            label: 'Analytics',
            onTap: () {
              _showAnalyticsDialog();
            },
          ),
          _buildQuickActionButton(
            icon: Icons.download,
            label: 'Export',
            onTap: _isExporting ? null : _exportVerifications,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Recent Verifications",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                 Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const VerifyCertificatesScreen(),
              ),
            );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 15),
        _buildVerificationsList(),
      ],
    );
  }

  Widget _buildVerificationsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getFilteredVerificationsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorCard('Error loading verifications');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator();
        }

        final verifications = snapshot.data?.docs ?? [];
        if (verifications.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: verifications.length,
          itemBuilder: (context, index) {
            return _buildVerificationCard(verifications[index]);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getFilteredVerificationsStream() {
    Query query = _firestore
        .collection('verifications')
        .where('companyId', isEqualTo: _auth.currentUser?.uid)
        .orderBy('verifiedAt', descending: true)
        .limit(5);

    // Apply date filter
    if (_selectedFilter != 'all') {
      final DateTime now = DateTime.now();
      DateTime filterDate;

      switch (_selectedFilter) {
        case 'today':
          filterDate = DateTime(now.year, now.month, now.day);
          break;
        case 'week':
          filterDate = now.subtract(const Duration(days: 7));
          break;
        case 'month':
          filterDate = DateTime(now.year, now.month, 1);
          break;
        default:
          filterDate = now;
      }

      query = query.where('verifiedAt', isGreaterThanOrEqualTo: filterDate);
    }

    return query.snapshots();
  }

  Widget _buildVerificationCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final verificationDate = (data['verifiedAt'] as Timestamp).toDate();
    final certificateDetails =
        data['certificateDetails'] as Map<String, dynamic>?;

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () => _showVerificationDetails(doc),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              _buildVerificationStatus(data['status']),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      certificateDetails?['name'] ?? 'Certificate',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      certificateDetails?['studentName'] ?? 'Student',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      Helpers.getTimeAgo(verificationDate),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationStatus(String status) {
    IconData icon;
    Color color;

    switch (status.toLowerCase()) {
      case 'verified':
        icon = Icons.check_circle;
        color = AppColors.success;
        break;
      case 'failed':
        icon = Icons.error;
        color = AppColors.error;
        break;
      default:
        icon = Icons.pending;
        color = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }

  void _showVerificationDetails(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVerificationDetailHeader(data),
                  const Divider(height: 30),
                  _buildVerificationDetailContent(data),
                  const SizedBox(height: 20),
                  _buildVerificationActions(doc.id),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVerificationDetailHeader(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Verification Details',
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
        const SizedBox(height: 15),
        Row(
          children: [
            _buildVerificationStatus(data['status']),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['status'].toString().toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  Helpers.formatDateTime(
                    (data['verifiedAt'] as Timestamp).toDate(),
                  ),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVerificationDetailContent(Map<String, dynamic> data) {
    final certificateDetails =
        data['certificateDetails'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailSection(
          'Certificate Information',
          [
            _buildDetailItem('Name', certificateDetails?['name'] ?? 'N/A'),
            _buildDetailItem('Type', certificateDetails?['type'] ?? 'N/A'),
            _buildDetailItem('Issue Date',
                Helpers.formatDate(certificateDetails?['issueDate'].toDate())),
          ],
        ),
        const SizedBox(height: 20),
        _buildDetailSection(
          'Student Information',
          [
            _buildDetailItem(
                'Name', certificateDetails?['studentName'] ?? 'N/A'),
            _buildDetailItem('ID', data['studentId'] ?? 'N/A'),
            _buildDetailItem(
                'Department', certificateDetails?['department'] ?? 'N/A'),
          ],
        ),
        const SizedBox(height: 20),
        _buildDetailSection(
          'Verification Information',
          [
            _buildDetailItem('Verified By', data['verifierName'] ?? 'N/A'),
            _buildDetailItem(
                'Verification Date',
                Helpers.formatDateTime(
                    (data['verifiedAt'] as Timestamp).toDate())),
            _buildDetailItem('Status', data['status'] ?? 'N/A'),
          ],
        ),
        if (data['notes'] != null) ...[
          const SizedBox(height: 20),
          _buildDetailSection(
            'Notes',
            [
              _buildDetailItem('Comments', data['notes']),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationActions(String verificationId) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _shareVerification(verificationId),
            icon: const Icon(Icons.share),
            label: const Text('Share'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _downloadCertificate(verificationId),
            icon: const Icon(Icons.download),
            label: const Text('Download'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _shareVerification(String verificationId) async {
    // Implement sharing functionality
    try {
      // Generate sharing link or content
      // ignore: unused_local_variable
      final sharingContent = 'Verification ID: $verificationId\n'
          'Verified by: ${widget.companyData['name']}\n'
          'View details at: your-app-url/verification/$verificationId';

      // Share content
      // You would typically use a sharing package here
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Sharing functionality to be implemented')),
      );
    } catch (e) {
      print('Error sharing verification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error sharing verification')),
      );
    }
  }

  Future<void> _downloadCertificate(String verificationId) async {
    try {
      setState(() => _isLoading = true);
      // Implement certificate download logic
      // This would typically involve generating a PDF or downloading from storage

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Download functionality to be implemented')),
      );
    } catch (e) {
      print('Error downloading certificate: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error downloading certificate')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAnalyticsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verification Analytics'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_analytics != null) ...[
                _buildAnalyticsDialogCard(
                  'Total Verifications',
                  _analytics!.totalVerifications.toString(),
                  Icons.fact_check,
                  AppColors.primary,
                ),
                const SizedBox(height: 15),
                _buildAnalyticsDialogCard(
                  'Successful Verifications',
                  _analytics!.successfulVerifications.toString(),
                  Icons.check_circle,
                  AppColors.success,
                ),
                const SizedBox(height: 15),
                _buildAnalyticsDialogCard(
                  'Failed Verifications',
                  _analytics!.failedVerifications.toString(),
                  Icons.error,
                  AppColors.error,
                ),
                const SizedBox(height: 15),
                _buildAnalyticsDialogCard(
                  'Success Rate',
                  '${_analytics!.successRate.toStringAsFixed(1)}%',
                  Icons.trending_up,
                  AppColors.secondary,
                ),
                const SizedBox(height: 20),
                _buildAnalyticsChart(),
              ] else
                const CircularProgressIndicator(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: _exportAnalytics,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Export Analytics'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsDialogCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAnalytics() async {
    try {
      if (_analytics == null) return;

      // ignore: unused_local_variable
      final analyticsData = {
        'total_verifications': _analytics!.totalVerifications,
        'successful_verifications': _analytics!.successfulVerifications,
        'failed_verifications': _analytics!.failedVerifications,
        'success_rate': _analytics!.successRate,
        'export_date': DateTime.now().toIso8601String(),
        'company_name': widget.companyData['name'],
        'company_id': _auth.currentUser?.uid,
      };

      // Here you would implement the actual export functionality
      // For example, generating a PDF or CSV report

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Analytics exported successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print('Error exporting analytics: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error exporting analytics'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Search functionality
  // ignore: unused_element
  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults.clear();
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final QuerySnapshot result = await _firestore
          .collection('verifications')
          .where('companyId', isEqualTo: _auth.currentUser?.uid)
          .get();

      final List<DocumentSnapshot> filteredResults = result.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final certificateDetails =
            data['certificateDetails'] as Map<String, dynamic>?;

        final searchableText = [
          certificateDetails?['name']?.toLowerCase() ?? '',
          certificateDetails?['studentName']?.toLowerCase() ?? '',
          data['studentId']?.toLowerCase() ?? '',
          certificateDetails?['department']?.toLowerCase() ?? '',
        ].join(' ');

        return searchableText.contains(query.toLowerCase());
      }).toList();

      setState(() {
        _searchResults = filteredResults;
        _isSearching = false;
      });
    } catch (e) {
      print('Error performing search: $e');
      setState(() => _isSearching = false);
    }
  }

  // Enhanced Filter functionality
  // ignore: unused_element
  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('All', 'all'),
          _buildFilterChip('Today', 'today'),
          _buildFilterChip('This Week', 'week'),
          _buildFilterChip('This Month', 'month'),
          _buildFilterChip('Verified', 'verified'),
          _buildFilterChip('Failed', 'failed'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (bool selected) {
          setState(() => _selectedFilter = selected ? value : 'all');
        },
        backgroundColor: Colors.grey[100],
        selectedColor: AppColors.primary.withOpacity(0.2),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : Colors.grey[800],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        checkmarkColor: AppColors.primary,
      ),
    );
  }

  // Export functionality
  Future<void> _exportVerifications() async {
    try {
      setState(() => _isExporting = true);

      // Fetch verifications
      final QuerySnapshot verifications = await _firestore
          .collection('verifications')
          .where('companyId', isEqualTo: _auth.currentUser?.uid)
          .get();

      // Prepare export data
      final List<Map<String, dynamic>> exportData = [];

      for (var doc in verifications.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final certificateDetails =
            data['certificateDetails'] as Map<String, dynamic>?;

        exportData.add({
          'verification_id': doc.id,
          'certificate_name': certificateDetails?['name'] ?? 'N/A',
          'certificate_type': certificateDetails?['type'] ?? 'N/A',
          'student_name': certificateDetails?['studentName'] ?? 'N/A',
          'student_id': data['studentId'] ?? 'N/A',
          'department': certificateDetails?['department'] ?? 'N/A',
          'verification_date': Helpers.formatDateTime(
            (data['verifiedAt'] as Timestamp).toDate(),
          ),
          'status': data['status'] ?? 'N/A',
          'verified_by': data['verifierName'] ?? 'N/A',
        });
      }

      // Show export options dialog
      await _showExportOptionsDialog(exportData);
    } catch (e) {
      print('Error exporting verifications: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error exporting verifications')),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _showExportOptionsDialog(List<Map<String, dynamic>> data) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildExportOption(
              icon: Icons.table_chart,
              title: 'Export as CSV',
              onTap: () => _exportAsCSV(data),
            ),
            _buildExportOption(
              icon: Icons.picture_as_pdf,
              title: 'Export as PDF',
              onTap: () => _exportAsPDF(data),
            ),
            _buildExportOption(
              icon: Icons.file_download,
              title: 'Export as Excel',
              onTap: () => _exportAsExcel(data),
            ),
          ],
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

  Widget _buildExportOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Future<void> _exportAsCSV(List<Map<String, dynamic>> data) async {
    try {
      // Implement CSV export
      // You would typically use a CSV package here
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV export to be implemented')),
      );
    } catch (e) {
      print('Error exporting as CSV: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error exporting as CSV')),
      );
    }
  }

  Future<void> _exportAsPDF(List<Map<String, dynamic>> data) async {
    try {
      // Implement PDF export
      // You would typically use a PDF package here
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF export to be implemented')),
      );
    } catch (e) {
      print('Error exporting as PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error exporting as PDF')),
      );
    }
  }

  Future<void> _exportAsExcel(List<Map<String, dynamic>> data) async {
    try {
      // Implement Excel export
      // You would typically use an Excel package here
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel export to be implemented')),
      );
    } catch (e) {
      print('Error exporting as Excel: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error exporting as Excel')),
      );
    }
  }

  // Error and Empty States
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
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 60,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            'No verifications found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
