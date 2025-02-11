import 'dart:io';
import 'package:certify_secure_app/CertifySecure/Screen/common/pdf_viewer_widget.dart';
import 'package:certify_secure_app/CertifySecure/Screen/utils/constants.dart';
import 'package:certify_secure_app/CertifySecure/Screen/utils/helpers.dart';
import 'package:certify_secure_app/CertifySecure/Services/blockchain_service.dart';
import 'package:certify_secure_app/CertifySecure/Widgets/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class VerifiedCertificatesScreen extends StatefulWidget {
  final String department;
  final List<String> sections;

  const VerifiedCertificatesScreen({
    super.key,
    required this.department,
    required this.sections,
  });

  @override
  _VerifiedCertificatesScreenState createState() =>
      _VerifiedCertificatesScreenState();
}

class _VerifiedCertificatesScreenState
    extends State<VerifiedCertificatesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final BlockchainService _blockchainService = BlockchainService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // State variables
  bool _isLoading = true;
  bool _isLoadingMore = false;
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
  @override
  void initState() {
    super.initState();
    _initializeData();
    _setupScrollListener();
  }

  void _initializeData() {
    _selectedSection =
        widget.sections.isNotEmpty ? widget.sections.first : 'All';
    _fetchVerifiedCertificates(initial: true);
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.8) {
        _loadMoreCertificates();
      }
    });
  }

  Future<void> _fetchVerifiedCertificates({bool initial = false}) async {
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
        .where('verificationStatus', isEqualTo: 'verified')
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

    // First, add the primary ordering
    if (_selectedSort == 'date') {
      query = query.orderBy('verificationDetails.verifiedAt', descending: !_isAscending);
    } else {
      query = query.orderBy('name', descending: !_isAscending);
    }

    // Always add a secondary ordering by document ID to ensure consistent pagination
    query = query.orderBy(FieldPath.documentId);

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
    await _fetchVerifiedCertificates();
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

          return (data['name']?.toString().toLowerCase() ?? '')
                  .contains(searchLower) ||
              (studentDetails['name']?.toString().toLowerCase() ?? '')
                  .contains(searchLower) ||
              (studentDetails['rollNumber']?.toString().toLowerCase() ?? '')
                  .contains(searchLower);
        }).toList();
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
    await _fetchVerifiedCertificates(initial: true);
  }


  Future<void> _viewCertificate(DocumentSnapshot doc) async {
    try {
      setState(() => _isLoading = true);

      final data = doc.data() as Map<String, dynamic>;
      final String fileName = data['fileName'];
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/$fileName';

      final Reference fileRef =
          _storage.ref().child('certificates').child(fileName);

      try {
        final metadata = await fileRef.getMetadata();
        print('File metadata: ${metadata.toString()}');

        final String downloadURL = await fileRef.getDownloadURL();
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
void _showCertificateDetails(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  final studentDetails = data['studentDetails'] as Map<String, dynamic>;
  final verificationDetails = data['verificationDetails'] as Map<String, dynamic>;

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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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

            // Verification Status
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.verified_user, color: AppColors.success),
                      SizedBox(width: 10),
                      Text(
                        'Verified Certificate',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Verified by ${verificationDetails['verifierName']} from ${verificationDetails['department']}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),

            // Certificate Information
            _buildDetailSection(
              'Certificate Information',
              [
                _buildDetailItem('Name', data['name'] ?? 'Not Available'),
                _buildDetailItem('Type', data['certificateType'] ?? 'Not Available'),
                _buildDetailItem('Issued By', data['issuedBy'] ?? 'Not Available'),
                _buildDetailItem(
                  'Issue Date',
                  Helpers.formatDate((data['issueDate'] as Timestamp).toDate()),
                ),
              ],
            ),

            // Student Information
            _buildDetailSection(
              'Student Information',
              [
                _buildDetailItem('Name', studentDetails['name'] ?? 'Not Available'),
                _buildDetailItem('Roll Number', studentDetails['rollNumber'] ?? 'Not Available'),
                _buildDetailItem('Section', studentDetails['section'] ?? 'Not Available'),
                _buildDetailItem('Batch', studentDetails['batch'] ?? 'Not Available'),
              ],
            ),

            // Verification Information
            _buildDetailSection(
              'Verification Information',
              [
                _buildDetailItem(
                  'Verified On',
                  Helpers.formatDateTime((verificationDetails['verifiedAt'] as Timestamp).toDate()),
                ),
                _buildDetailItem('Verified By', verificationDetails['verifierName'] ?? 'Not Available'),
                _buildDetailItem('Department', verificationDetails['department'] ?? 'Not Available'),
                _buildDetailItem('Hash', verificationDetails['hash'] ?? 'Not Available'),
              ],
            ),

            // Action Buttons
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.remove_red_eye, color: Colors.white),
                    label: const Text('View Certificate'),
                    onPressed: () {
                      Navigator.pop(context);
                      _viewCertificate(doc);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.copy, color: Colors.white),
                    label: const Text('Copy Hash'),
                    onPressed: () {
                      final hash = verificationDetails['hash'] ?? '';
                      if (hash.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: hash));
                        Navigator.pop(context);
                        Helpers.showSnackBar(context, 'Hash copied to clipboard');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Verified Certificates - ${widget.department}'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Column(
          children: [
            _buildSearchBar(),
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

  Widget _buildSearchBar() {
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
          child: Text('Sort by Verification Date'),
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
                    _fetchVerifiedCertificates(initial: true);
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
                    _fetchVerifiedCertificates(initial: true);
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
                    _fetchVerifiedCertificates(initial: true);
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
  final verificationDetails = data['verificationDetails'] as Map<String, dynamic>;
  final verifiedDate = (verificationDetails['verifiedAt'] as Timestamp).toDate();

  return Card(
    margin: const EdgeInsets.only(bottom: 10),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
    ),
    elevation: 2,
    child: ListTile(
      contentPadding: const EdgeInsets.all(15),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.verified_user,
          color: AppColors.success,
        ),
      ),
      title: Text(
        data['name'] ?? 'Unknown Certificate',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Student: ${studentDetails['name']}'),
          Text('Roll No: ${studentDetails['rollNumber']}'),
          Text('Verified by: ${verificationDetails['verifierName']}'),
          Text('Verified: ${Helpers.getTimeAgo(verifiedDate)}'),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => _showCertificateDetails(doc),
      ),
      onTap: () => _showCertificateDetails(doc),
    ),
  );
}

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.verified,
            size: 70,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 15),
          Text(
            _searchQuery.isEmpty
                ? 'No verified certificates'
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

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
