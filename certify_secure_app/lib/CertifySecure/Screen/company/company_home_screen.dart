// lib/screens/company/company_home_screen.dart

import 'package:certify_secure_app/CertifySecure/Screen/utils/constants.dart';
import 'package:certify_secure_app/CertifySecure/Screen/utils/helpers.dart';
import 'package:certify_secure_app/CertifySecure/Widgets/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
        'total': verifications.size,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Dashboard'),
        backgroundColor: AppColors.primary,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeCard(),
                const SizedBox(height: 25),
                _buildStatisticsSection(),
                const SizedBox(height: 25),
                _buildRecentActivity(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
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
                      'Welcome, ${widget.companyData['name'] ?? 'Company'}',
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
                padding: const EdgeInsets.all(10),
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
        ],
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getVerificationStats(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorCard('Error loading statistics');
        }

        if (!snapshot.hasData) {
          return const LoadingIndicator();
        }

        final stats = snapshot.data!;

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
              const Text(
                "Verification Statistics",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      "Total",
                      stats['total'].toString(),
                      Icons.fact_check,
                      AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      "Today",
                      stats['today'].toString(),
                      Icons.today,
                      AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      "This Month",
                      stats['month'].toString(),
                      Icons.calendar_month,
                      AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(
            count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
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
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to verification history screen
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 15),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('verifications')
              .where('companyId', isEqualTo: _auth.currentUser?.uid)
              .orderBy('verifiedAt', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorCard('Error loading recent activity');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingIndicator();
            }

            final verifications = snapshot.data?.docs ?? [];
            if (verifications.isEmpty) {
              return _buildEmptyState();
            }

            return Column(
              children: verifications.map((doc) => _buildActivityCard(doc)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActivityCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final verificationDate = (data['verifiedAt'] as Timestamp).toDate();
    final certificateDetails = data['certificateDetails'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified,
              color: AppColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (certificateDetails != null) ...[
                  Text(
                    certificateDetails['name'] ?? 'Unknown Certificate',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Student: ${certificateDetails['studentName'] ?? 'Unknown'}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ] else ...[
                  Text(
                    'Certificate ID: ${data['certificateId']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Student ID: ${data['studentId']}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
                Text(
                  Helpers.getTimeAgo(verificationDate),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
            onPressed: () {
              // Navigate to verification details
            },
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
          Text(
            message,
            style: const TextStyle(color: AppColors.error),
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
        children: [
          Icon(
            Icons.fact_check,
            size: 50,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 15),
          Text(
            'No verifications yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Start verifying certificates to see your activity',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}