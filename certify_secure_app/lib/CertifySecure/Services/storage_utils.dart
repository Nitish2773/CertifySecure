import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

class StorageUtils {
  static const String certificatesPath = 'certificates';
  static const String projectId = 'certify-36ea0';
  static const String storageBucket = 'certify-36ea0.appspot.com';

  static Future<String> getDownloadURLWithRetry(Reference ref, {int maxAttempts = 3}) async {
    int attempts = 0;
    Exception? lastError;

    while (attempts < maxAttempts) {
      try {
        // Get the download URL
        String downloadURL = await ref.getDownloadURL();
        
        // Ensure the URL contains the project ID
        if (!downloadURL.contains(projectId)) {
          Uri.parse(downloadURL);
          final String modifiedUrl = 'https://firebasestorage.googleapis.com/v0/b/$storageBucket/o/${Uri.encodeComponent(ref.fullPath)}?alt=media';
          downloadURL = modifiedUrl;
        }
        
        print('Download URL: $downloadURL'); // Debug print
        return downloadURL;
      } catch (e) {
        lastError = Exception('Attempt ${attempts + 1} failed: $e');
        print(lastError);
        attempts++;
        if (attempts < maxAttempts) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
    throw lastError ?? Exception('Failed to get download URL after $maxAttempts attempts');
  }

  static Future<bool> verifyStoragePath(Reference ref) async {
    try {
      await ref.getMetadata();
      return true;
    } catch (e) {
      print('Storage path verification failed: $e');
      return false;
    }
  }

  static Future<File> downloadFile(String downloadURL, String localPath) async {
    try {
      // Ensure the URL is properly formatted
      if (!downloadURL.contains('alt=media')) {
        downloadURL = '$downloadURL?alt=media';
      }

      final response = await http.get(Uri.parse(downloadURL));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to download file: ${response.statusCode}');
      }

      final File file = File(localPath);
      await file.writeAsBytes(response.bodyBytes);
      
      print('File downloaded successfully to: $localPath');
      return file;
    } catch (e) {
      print('File download failed: $e');
      throw Exception('Failed to download file: $e');
    }
  }

  static String getStorageUrl(String path) {
    final encodedPath = Uri.encodeComponent(path);
    return 'https://firebasestorage.googleapis.com/v0/b/$storageBucket/o/$encodedPath';
  }

  static Reference getStorageReference(String fileName) {
    return FirebaseStorage.instance
        .ref()
        .child(certificatesPath)
        .child(fileName);
  }
}