import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // For MediaType
import 'package:image_picker/image_picker.dart'; // For XFile
import 'package:mime/mime.dart'; // For MIME type lookup

// Define a custom exception for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? responseBody;

  ApiException(this.message, {this.statusCode, this.responseBody});

  @override
  String toString() {
    return 'ApiException: $message (Status Code: ${statusCode ?? 'N/A'})';
  }
}

class ApiService {
  // TODO: Move this URL to a constants file
  static const String _apiUrl =
      "https://flask-api-87033406861.us-central1.run.app/api/extract-data";

  Future<Map<String, dynamic>> uploadAndProcessImage(XFile imageXFile) async {
    File imageFile = File(imageXFile.path);

    // Determine content type
    MediaType? contentType;
    String? mimeTypeString = imageXFile.mimeType ?? lookupMimeType(imageXFile.path);

    if (mimeTypeString != null) {
      try {
        contentType = MediaType.parse(mimeTypeString);
      } catch (e) {
        debugPrint("Error parsing MIME type: $mimeTypeString. Error: $e");
        // Proceed without explicit content type if parsing fails
      }
    } else {
      debugPrint("Could not determine MIME type for ${imageXFile.path}.");
    }

    try {
      var request = http.MultipartRequest('POST', Uri.parse(_apiUrl));
      request.files.add(
        await http.MultipartFile.fromPath(
          'file', // Key expected by the backend
          imageFile.path,
          contentType: contentType,
        ),
      );

      debugPrint(
        "Sending request to API with content type: ${contentType?.toString() ?? 'Not specified'}",
      );
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint("API Response Status: ${response.statusCode}");
      debugPrint("API Response Body: ${response.body}");

      if (response.statusCode == 200) {
        try {
          final decodedBody = jsonDecode(response.body);
          if (decodedBody != null && decodedBody['data'] is Map) {
            // Return the 'data' map directly
            return decodedBody['data'] as Map<String, dynamic>;
          } else {
            debugPrint(
              "API Error: Unexpected response format. Expected 'data' as Map. Body: ${response.body}",
            );
            throw ApiException(
              'Received unexpected data format from server.',
              statusCode: response.statusCode,
              responseBody: response.body,
            );
          }
        } catch (e) {
          debugPrint(
            "Error processing successful API response (status 200): $e. Body: ${response.body}",
          );
          throw ApiException(
            'Error processing server response: ${e.toString().split('\n').first}',
            statusCode: response.statusCode,
            responseBody: response.body,
          );
        }
      } else {
        // Handle API errors (non-200 status)
        debugPrint("API Error: ${response.statusCode} - ${response.body}");
        String errorDetail = response.body.isNotEmpty
            ? response.body
            : response.reasonPhrase ?? 'Unknown error';
        throw ApiException(
          'Error processing image: $errorDetail',
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }
    } on SocketException catch (e) {
       debugPrint("Network error during API request: $e");
       throw ApiException('Network error. Please check your connection.');
    } on http.ClientException catch (e) {
       debugPrint("Client error during API request: $e");
       throw ApiException('Could not connect to the server. Please try again later.');
    } catch (e) {
      // Catch any other unexpected errors during the request/upload phase
      debugPrint("Unexpected error during image upload/API request: $e");
      throw ApiException('An unexpected error occurred. Please try again.');
    }
    // Note: We don't delete the temp file here as the caller might still need it.
  }
}
