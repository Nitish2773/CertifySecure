// lib/widgets/loading_indicator.dart

import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  final String? message;
  final Color color;

  const LoadingIndicator({
    super.key,
    this.message,
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}