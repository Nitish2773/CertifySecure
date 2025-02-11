// lib/screens/common/pdf_viewer_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class PdfViewerWidget extends StatefulWidget {
  final String path;
  final String title;
  final Map<String, dynamic> metadata;

  const PdfViewerWidget({
    super.key,
    required this.path,
    required this.title,
    required this.metadata,
  });

  @override
  _PdfViewerWidgetState createState() => _PdfViewerWidgetState();
}

class _PdfViewerWidgetState extends State<PdfViewerWidget> {
  int? _totalPages;
  int _currentPage = 0;
  bool _isLoading = true;
  PDFViewController? _pdfViewController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade800,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          PDFView(
            filePath: widget.path,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: true,
            pageFling: true,
            pageSnap: true,
            defaultPage: _currentPage,
            onRender: (pages) {
              setState(() {
                _totalPages = pages;
                _isLoading = false;
              });
            },
            onError: (error) {
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $error'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            onPageError: (page, error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error on page $page: $error'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            onViewCreated: (PDFViewController pdfViewController) {
              _pdfViewController = pdfViewController;
            },
            onPageChanged: (int? page, int? total) {
              if (page != null) {
                setState(() => _currentPage = page);
              }
            },
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    if (_totalPages == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            'Page ${_currentPage + 1} of $_totalPages',
            style: const TextStyle(fontSize: 16),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_left),
                onPressed: _currentPage <= 0
                    ? null
                    : () {
                        _pdfViewController?.setPage(_currentPage - 1);
                      },
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_right),
                onPressed: _totalPages == null || _currentPage >= (_totalPages! - 1)
                    ? null
                    : () {
                        _pdfViewController?.setPage(_currentPage + 1);
                      },
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  // Implement share functionality
                },
              ),
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () {
                  // Implement download functionality
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pdfViewController = null;
    super.dispose();
  }
}