import 'dart:io';
import 'package:certify_secure_app/CertifySecure/Screen/common/pdf_viewer_widget.dart';
import 'package:certify_secure_app/CertifySecure/Screen/utils/constants.dart';
import 'package:certify_secure_app/CertifySecure/Screen/utils/helpers.dart';
import 'package:certify_secure_app/CertifySecure/Services/blockchain_service.dart';
import 'package:certify_secure_app/CertifySecure/Services/storage_utils.dart';
import 'package:certify_secure_app/CertifySecure/Widgets/loading_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class PendingCertificatesScreen extends StatefulWidget {
  final String department;
  final List<String> sections;

  const PendingCertificatesScreen({
    super.key,
    required this.department,
    required this.sections,
  });

  @override
  _PendingCertificatesScreenState createState() => _PendingCertificatesScreenState();
}

class _PendingCertificatesScreenState extends State<PendingCertificatesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final BlockchainService _blockchainService = BlockchainService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // State variables
  bool _isLoading = true;
  String _searchQuery = '';
  List<DocumentSnapshot> _allCertificates = [];
  List<DocumentSnapshot> _filteredCertificates = [];
  
  // Sorting and filtering
  String _selectedSort = 'date';
  bool _isAscending = false;
  String _selectedSection = 'All';
  String _selectedBatch = 'All';
  String _selectedCertificateType = 'All';

  // Statistics
  Map<String, int> _sectionStats = {};
  Map<String, int> _batchStats = {};
  Map<String, int> _typeStats = {};

  // Pagination
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  static const int _pageSize = 20;
  bool _isLoadingMore = false;  @override
  void initState() {
    super.initState();
    _initializeData();
    _setupScrollListener();
  }

  void _initializeData() {
    _selectedSection = widget.sections.isNotEmpty ? widget.sections.first : 'All';
    _fetchPendingCertificates(initial: true);
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent * 0.8) {
        _loadMoreCertificates();
      }
    });
  }

  Future<void> _fetchPendingCertificates({bool initial = false}) async {
    if (initial) {
      setState(() {
        _isLoading = true;
        _lastDocument = null;
        _hasMore = true;
        _allCertificates.clear();
      });
    }

    try {
      Query query = _firestore
          .collection('certificates')
          .where('verificationStatus', isEqualTo: 'pending')
          .where('studentDetails.department', isEqualTo: widget.department);

      if (_selectedSection != 'All') {
        query = query.where('studentDetails.section', isEqualTo: _selectedSection);
      }

      if (_selectedBatch != 'All') {
        query = query.where('studentDetails.batch', isEqualTo: _selectedBatch);
      }

      if (_selectedCertificateType != 'All') {
        query = query.where('certificateType', isEqualTo: _selectedCertificateType);
      }

      // Apply sorting
      query = query.orderBy(_selectedSort == 'date' ? 'uploadedAt' : 'name', 
                          descending: !_isAscending);

      // Apply pagination
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      query = query.limit(_pageSize);

      final QuerySnapshot snapshot = await query.get();
      final docs = snapshot.docs;

      if (initial) {
        _calculateStats(docs);
      }

      setState(() {
        if (initial) {
          _allCertificates = docs;
        } else {
          _allCertificates.addAll(docs);
        }
        
        _hasMore = docs.length == _pageSize;
        if (docs.isNotEmpty) {
          _lastDocument = docs.last;
        }
        _filterAndSortCertificates();
      });
    } catch (e) {
      _handleError('Error loading certificates', e);
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreCertificates() async {
    if (!_hasMore || _isLoadingMore) return;
    
    setState(() => _isLoadingMore = true);
    await _fetchPendingCertificates();
  }

  void _calculateStats(List<DocumentSnapshot> docs) {
    Map<String, int> sectionStats = {};
    Map<String, int> batchStats = {};
    Map<String, int> typeStats = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final studentDetails = data['studentDetails'] as Map<String, dynamic>;
      
      final section = studentDetails['section'] ?? 'Unknown';
      final batch = studentDetails['batch'] ?? 'Unknown';
      final type = data['certificateType'] ?? 'Unknown';

      sectionStats[section] = (sectionStats[section] ?? 0) + 1;
      batchStats[batch] = (batchStats[batch] ?? 0) + 1;
      typeStats[type] = (typeStats[type] ?? 0) + 1;
    }

    setState(() {
      _sectionStats = sectionStats;
      _batchStats = batchStats;
      _typeStats = typeStats;
    });
  }

  void _filterAndSortCertificates() {
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredCertificates = List.from(_allCertificates);
      } else {
        _filteredCertificates = _allCertificates.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final studentDetails = data['studentDetails'] as Map<String, dynamic>;
          final searchLower = _searchQuery.toLowerCase();
          
          return (data['name']?.toString().toLowerCase() ?? '').contains(searchLower) ||
                 (studentDetails['name']?.toString().toLowerCase() ?? '').contains(searchLower) ||
                 (studentDetails['rollNumber']?.toString().toLowerCase() ?? '').contains(searchLower);
        }).toList();
      }

      // Apply sorting if needed
      if (_selectedSort == 'name') {
        _filteredCertificates.sort((a, b) {
          final nameA = (a.data() as Map<String, dynamic>)['name']?.toString() ?? '';
          final nameB = (b.data() as Map<String, dynamic>)['name']?.toString() ?? '';
          return _isAscending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
        });
      }
    });
  }

  void _handleError(String message, dynamic error) {
    print('$message: $error');
    if (mounted) {
      Helpers.showSnackBar(
        context,
        '$message: ${error.toString()}',
        isError: true,
      );
    }
  }

  Future<void> _refreshData() async {
    await _fetchPendingCertificates(initial: true);
  }  
  
  Future<void> _verifyCertificate(DocumentSnapshot doc) async {
  try {
    setState(() => _isLoading = true);

    // 1. Extract data and validate
    final data = doc.data() as Map<String, dynamic>;
    if (data['studentDetails'] == null || data['studentDetails']['uid'] == null) {
      throw Exception('Student details are missing');
    }

    // 2. Get required data
    final studentId = data['studentDetails']['uid'];
    final certificateId = doc.id;
    
    // 3. Generate hash from file
    final String fileName = data['fileName'];
    final Directory tempDir = await getTemporaryDirectory();
    final String localFilePath = '${tempDir.path}/$fileName';

    final Reference fileRef = FirebaseStorage.instance
        .ref()
        .child(StorageUtils.certificatesPath)
        .child(fileName);

    final String downloadURL = await StorageUtils.getDownloadURLWithRetry(fileRef);
    final File downloadedFile = await StorageUtils.downloadFile(
      downloadURL,
      localFilePath,
    );

    final fileHash = await Helpers.generateFileHash(downloadedFile.path);

    // 4. Silently try blockchain storage without alerts
    bool isBlockchainVerified = false;
    try {
      await _blockchainService.storeCertificateHash(
        studentId,
        certificateId,
        fileHash,
      );
      isBlockchainVerified = true;
      print('Hash stored in blockchain successfully');
    } catch (blockchainError) {
      print('Blockchain storage not available: $blockchainError');
    }

    // 5. Store in Firebase
    final currentUser = FirebaseAuth.instance.currentUser;
    await _firestore.collection('certificates').doc(doc.id).update({
      'verificationStatus': 'verified',
      'verificationDetails': {
        'hash': fileHash,
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': currentUser?.uid,
        'verifierName': currentUser?.displayName ?? 'Unknown Verifier',
        'department': widget.department,
        'isBlockchainVerified': isBlockchainVerified,
        'collegeName': 'Your College Name', // Add your college name here
        'verificationStatement': 'This certificate has been verified by ${currentUser?.displayName ?? 'Unknown Verifier'} '
            'from ${widget.department} department. The document has been confirmed as original and unmodified.',
      },
      'lastModified': FieldValue.serverTimestamp(),
    });

    // 6. Clean up
    try {
      await downloadedFile.delete();
    } catch (e) {
      print('Warning: Failed to delete temporary file: $e');
    }

    // 7. Show verification details dialog
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Certificate Verified'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Verified by: ${currentUser?.displayName ?? 'Unknown Verifier'}'),
              Text('Department: ${widget.department}'),
              const Text('College: Your College Name'), // Add your college name
              const SizedBox(height: 10),
              const Text(
                'This certificate has been verified as authentic and unmodified.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (isBlockchainVerified) ...[
                const SizedBox(height: 10),
                const Text(
                  'Additional Security: This certificate is also secured on blockchain.',
                  style: TextStyle(color: Colors.green),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }

    // 8. Refresh data
    await _refreshData();

  } catch (e) {
    print('Verification error: $e');
    if (mounted) {
      Helpers.showSnackBar(
        context, 
        'Verification failed: ${e.toString()}',
        isError: true,
        duration: const Duration(seconds: 5),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

// Also update the notification creation method
// ignore: unused_element
Future<void> _createVerificationNotification(DocumentSnapshot doc) async {
  try {
    final data = doc.data() as Map<String, dynamic>;
    final studentDetails = data['studentDetails'] as Map<String, dynamic>;
    final verificationDetails = data['verificationDetails'] as Map<String, dynamic>;

    await _firestore.collection('notifications').add({
      'userId': studentDetails['uid'], // Changed from id to uid
      'title': 'Certificate Verified',
      'message': 'Your certificate "${data['originalName'] ?? data['name']}" has been verified successfully.',
      'type': 'verification',
      'certificateId': doc.id,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'metadata': {
        'certificateName': data['originalName'] ?? data['name'],
        'verifiedBy': verificationDetails['verifierName'],
        'verifiedAt': verificationDetails['verifiedAt'],
        'department': widget.department,
        'transactionHash': verificationDetails['blockchainTxHash'],
      }
    });

    // Update user's notification count
    final userRef = _firestore.collection('users').doc(studentDetails['uid']); // Changed from id to uid
    await userRef.update({
      'unreadNotifications': FieldValue.increment(1),
      'lastNotification': FieldValue.serverTimestamp(),
    });

    print('Verification notification created successfully');
  } catch (e) {
    print('Error creating verification notification: $e');
    // Don't throw the error as this is a non-critical operation
  }
}




  Future<void> _viewCertificate(DocumentSnapshot doc) async {
    try {
      setState(() => _isLoading = true);

      final data = doc.data() as Map<String, dynamic>;
      final String fileName = data['fileName'];
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/$fileName';
      
      final Reference fileRef = _storage.ref().child('certificates').child(fileName);
      
      try {
        final metadata = await fileRef.getMetadata();
        print('File metadata: ${metadata.toString()}');
        
        final String downloadURL = await StorageUtils.getDownloadURLWithRetry(fileRef);
        final response = await http.get(Uri.parse(downloadURL));
        
        if (response.statusCode != 200) {
          throw Exception('Failed to download file: ${response.statusCode}');
        }
        
        await File(filePath).writeAsBytes(response.bodyBytes);

        if (!mounted) return;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerWidget(
              path: filePath,
              title: data['name'] ?? fileName,
              metadata: data,
            ),
          ),
        );
      } on FirebaseException catch (e) {
        if (e.code == 'object-not-found') {
          throw Exception('Certificate file not found in storage');
        }
        rethrow;
      }
    } catch (e) {
      _handleError('Error viewing certificate', e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectCertificate(DocumentSnapshot doc, String reason) async {
    try {
      setState(() => _isLoading = true);

      final batch = _firestore.batch();
      
      // Update certificate status
      batch.update(doc.reference, {
        'verificationStatus': 'rejected',
        'verificationDetails': {
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectedBy': FirebaseAuth.instance.currentUser?.uid,
          'rejectorName': FirebaseAuth.instance.currentUser?.displayName,
          'reason': reason,
        },
        'lastModified': FieldValue.serverTimestamp(),
      });

      // Create rejection record
      final rejectionRef = _firestore.collection('rejections').doc();
      batch.set(rejectionRef, {
        'certificateId': doc.id,
        'reason': reason,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': FirebaseAuth.instance.currentUser?.uid,
        'rejectorName': FirebaseAuth.instance.currentUser?.displayName,
        'department': widget.department,
        'studentDetails': doc.get('studentDetails'),
      });

      await batch.commit();

      // Create notification
      await _createRejectionNotification(doc, reason);

      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Certificate rejected successfully',
          duration: const Duration(seconds: 3),
        );
      }

      await _refreshData();
    } catch (e) {
      _handleError('Error rejecting certificate', e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createRejectionNotification(DocumentSnapshot doc, String reason) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final studentDetails = data['studentDetails'] as Map<String, dynamic>;

      await _firestore.collection('notifications').add({
        'userId': studentDetails['userId'],
        'title': 'Certificate Rejected',
        'message': 'Your certificate "${data['name']}" was rejected. Reason: $reason',
        'type': 'rejection',
        'certificateId': doc.id,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      print('Error creating rejection notification: $e');
    }
  }  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Column(
          children: [
            _buildSearchAndFilterBar(),
            _buildFilterChips(),
            Expanded(
              child: _isLoading && _allCertificates.isEmpty
                  ? const LoadingIndicator()
                  : _buildCertificatesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _filterAndSortCertificates();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search certificates...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _filterAndSortCertificates();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildSortButton(),
        ],
      ),
    );
  }

  Widget _buildSortButton() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.sort, color: AppColors.primary),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'date',
          child: Text('Sort by Date'),
        ),
        const PopupMenuItem(
          value: 'name',
          child: Text('Sort by Name'),
        ),
        PopupMenuItem(
          value: 'order',
          child: Text(_isAscending ? 'Sort Descending' : 'Sort Ascending'),
        ),
      ],
      onSelected: (value) {
        setState(() {
          if (value == 'order') {
            _isAscending = !_isAscending;
          } else {
            _selectedSort = value;
          }
          _filterAndSortCertificates();
        });
      },
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (widget.sections.length > 1)
              _buildFilterChip(
                label: 'Section',
                selected: _selectedSection,
                options: ['All', ...widget.sections],
                onSelected: (value) {
                  setState(() {
                    _selectedSection = value;
                    _fetchPendingCertificates(initial: true);
                  });
                },
              ),
            if (_batchStats.isNotEmpty) ...[
              const SizedBox(width: 10),
              _buildFilterChip(
                label: 'Batch',
                selected: _selectedBatch,
                options: ['All', ..._batchStats.keys],
                onSelected: (value) {
                  setState(() {
                    _selectedBatch = value;
                    _fetchPendingCertificates(initial: true);
                  });
                },
              ),
            ],
            if (_typeStats.isNotEmpty) ...[
              const SizedBox(width: 10),
              _buildFilterChip(
                label: 'Type',
                selected: _selectedCertificateType,
                options: ['All', ..._typeStats.keys],
                onSelected: (value) {
                  setState(() {
                    _selectedCertificateType = value;
                    _fetchPendingCertificates(initial: true);
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String selected,
    required List<String> options,
    required Function(String) onSelected,
  }) {
    return PopupMenuButton<String>(
      itemBuilder: (context) => options
          .map(
            (option) => PopupMenuItem(
              value: option,
              child: Row(
                children: [
                  if (option == selected)
                    const Icon(Icons.check, color: AppColors.primary)
                  else
                    const SizedBox(width: 24),
                  const SizedBox(width: 8),
                  Text(option),
                ],
              ),
            ),
          )
          .toList(),
      onSelected: onSelected,
      child: Chip(
        label: Text(
          '$label: $selected',
          style: TextStyle(
            color: selected == 'All' ? Colors.grey[600] : AppColors.primary,
          ),
        ),
        backgroundColor: selected == 'All'
            ? Colors.grey[200]
            : AppColors.primary.withOpacity(0.1),
      ),
    );
  }

  Widget _buildCertificatesList() {
    if (_filteredCertificates.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(15),
      itemCount: _filteredCertificates.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _filteredCertificates.length) {
          return _buildLoadingIndicator();
        }
        return _buildCertificateCard(_filteredCertificates[index]);
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }

  Widget _buildCertificateCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final studentDetails = data['studentDetails'] as Map<String, dynamic>;
    final uploadDate = (data['uploadedAt'] as Timestamp).toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: CircleAvatar(
          backgroundColor: AppColors.warning.withOpacity(0.1),
          child: const Icon(
            Icons.pending_actions,
            color: AppColors.warning,
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
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Text('View Certificate'),
            ),
            const PopupMenuItem(
              value: 'verify',
              child: Text('Verify'),
            ),
            const PopupMenuItem(
              value: 'reject',
              child: Text('Reject'),
            ),
          ],
          onSelected: (value) => _handleCardAction(value, doc),
        ),
        onTap: () => _showCertificateDetails(doc),
      ),
    );
  }

  void _handleCardAction(String action, DocumentSnapshot doc) {
    switch (action) {
      case 'view':
        _viewCertificate(doc);
        break;
      case 'verify':
        _showVerificationDialog(doc);
        break;
      case 'reject':
        _showRejectionDialog(doc);
        break;
    }
  }

  void _showVerificationDialog(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Certificate'),
        content: const Text('Are you sure you want to verify this certificate?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _verifyCertificate(doc);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
                foregroundColor: Colors.white, 
            ),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _showRejectionDialog(DocumentSnapshot doc) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Certificate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Enter reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
              if (reasonController.text.isEmpty) {
                Helpers.showSnackBar(
                  context,
                  'Please provide a reason for rejection',
                  isError: true,
                );
                return;
              }
              Navigator.pop(context);
              _rejectCertificate(doc, reasonController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
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
            Icons.folder_open,
            size: 70,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 15),
          Text(
            _searchQuery.isEmpty
                ? 'No pending certificates'
                : 'No certificates match your search',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
    void _showCertificateDetails(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final studentDetails = data['studentDetails'] as Map<String, dynamic>;
    final uploadDate = (data['uploadedAt'] as Timestamp).toDate();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
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
                    color: AppColors.primary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            
            // Certificate Details
            _buildDetailSection(
              'Certificate Information',
              [
                _buildDetailItem('Name', data['name'] ?? 'Not Available'),
                _buildDetailItem('Type', data['certificateType'] ?? 'Not Available'),
                _buildDetailItem('Issued By', data['issuedBy'] ?? 'Not Available'),
                _buildDetailItem('Upload Date', Helpers.formatDate(uploadDate)),
              ],
            ),
            const SizedBox(height: 15),

            // Student Details
            _buildDetailSection(
              'Student Information',
              [
                _buildDetailItem('Name', studentDetails['name'] ?? 'Not Available'),
                _buildDetailItem('Roll Number', studentDetails['rollNumber'] ?? 'Not Available'),
                _buildDetailItem('Department', studentDetails['department'] ?? 'Not Available'),
                _buildDetailItem('Section', studentDetails['section'] ?? 'Not Available'),
                _buildDetailItem('Batch', studentDetails['batch'] ?? 'Not Available'),
              ],
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.remove_red_eye, color: Colors.white),
                    label: const Text(
                      'View Certificate',
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _viewCertificate(doc);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.verified_user, color: Colors.white),
                    label: const Text(
                      'Verify',
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _showVerificationDialog(doc);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.cancel, color: Colors.white),
                label: const Text(
                  'Reject Certificate',
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _showRejectionDialog(doc);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> items) {
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
        ...items,
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

