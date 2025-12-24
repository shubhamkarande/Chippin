import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// OCR result from receipt scanning.
class OcrResult {
  final String rawText;
  final double? total;
  final DateTime? date;
  final String? merchantName;
  final List<OcrLineItem> items;
  final bool success;
  final String? error;

  OcrResult({
    required this.rawText,
    this.total,
    this.date,
    this.merchantName,
    this.items = const [],
    this.success = true,
    this.error,
  });

  factory OcrResult.error(String message) {
    return OcrResult(
      rawText: '',
      success: false,
      error: message,
    );
  }
}

/// Line item from receipt.
class OcrLineItem {
  final String description;
  final double? price;
  final int? quantity;

  OcrLineItem({
    required this.description,
    this.price,
    this.quantity,
  });
}

/// OCR Service for receipt scanning using Google ML Kit.
class OcrService {
  final TextRecognizer _textRecognizer;
  final ImagePicker _imagePicker;

  OcrService()
      : _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin),
        _imagePicker = ImagePicker();

  /// Scan receipt from camera
  Future<OcrResult> scanFromCamera() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
      );

      if (image == null) {
        return OcrResult.error('No image captured');
      }

      return await _processImage(File(image.path));
    } catch (e) {
      debugPrint('Camera error: $e');
      return OcrResult.error('Failed to capture image: $e');
    }
  }

  /// Scan receipt from gallery
  Future<OcrResult> scanFromGallery() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) {
        return OcrResult.error('No image selected');
      }

      return await _processImage(File(image.path));
    } catch (e) {
      debugPrint('Gallery error: $e');
      return OcrResult.error('Failed to load image: $e');
    }
  }

  /// Process image file and extract text
  Future<OcrResult> _processImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      if (recognizedText.text.isEmpty) {
        return OcrResult.error('No text found in image');
      }

      return _parseReceipt(recognizedText.text);
    } catch (e) {
      debugPrint('OCR processing error: $e');
      return OcrResult.error('Failed to process image: $e');
    }
  }

  /// Parse recognized text to extract receipt information
  OcrResult _parseReceipt(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    // Extract total
    final total = _extractTotal(lines);

    // Extract date
    final date = _extractDate(lines);

    // Extract merchant name (usually first non-empty line)
    final merchantName = _extractMerchantName(lines);

    // Extract line items
    final items = _extractLineItems(lines);

    return OcrResult(
      rawText: text,
      total: total,
      date: date,
      merchantName: merchantName,
      items: items,
    );
  }

  /// Extract total amount from receipt
  double? _extractTotal(List<String> lines) {
    // Common patterns for total
    final totalPatterns = [
      RegExp(r'(?:total|grand\s*total|amount\s*due|net\s*total|subtotal)[\s:]*[₹$€£]?\s*([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(r'[₹$€£]\s*([\d,]+\.?\d*)\s*(?:total|due)?', caseSensitive: false),
      RegExp(r'([\d,]+\.?\d*)\s*[₹$€£]', caseSensitive: false),
    ];

    // Search from bottom up (total usually at end)
    for (final line in lines.reversed) {
      for (final pattern in totalPatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          final amountStr = match.group(1)?.replaceAll(',', '');
          if (amountStr != null) {
            final amount = double.tryParse(amountStr);
            if (amount != null && amount > 0 && amount < 1000000) {
              return amount;
            }
          }
        }
      }
    }

    // Fallback: find largest number that looks like a price
    double? maxAmount;
    final pricePattern = RegExp(r'([\d,]+\.\d{2})');
    for (final line in lines) {
      for (final match in pricePattern.allMatches(line)) {
        final amountStr = match.group(1)?.replaceAll(',', '');
        final amount = double.tryParse(amountStr ?? '');
        if (amount != null && (maxAmount == null || amount > maxAmount)) {
          maxAmount = amount;
        }
      }
    }

    return maxAmount;
  }

  /// Extract date from receipt
  DateTime? _extractDate(List<String> lines) {
    final datePatterns = [
      // DD/MM/YYYY or DD-MM-YYYY
      RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})'),
      // YYYY-MM-DD
      RegExp(r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})'),
      // Month DD, YYYY
      RegExp(r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+(\d{1,2}),?\s*(\d{4})', caseSensitive: false),
    ];

    for (final line in lines) {
      for (final pattern in datePatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          try {
            // Handle different formats
            if (pattern.pattern.contains('Jan|Feb')) {
              final months = {
                'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
                'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
              };
              final month = months[match.group(1)?.toLowerCase().substring(0, 3)] ?? 1;
              final day = int.parse(match.group(2)!);
              final year = int.parse(match.group(3)!);
              return DateTime(year, month, day);
            } else if (match.group(1)!.length == 4) {
              // YYYY-MM-DD format
              return DateTime(
                int.parse(match.group(1)!),
                int.parse(match.group(2)!),
                int.parse(match.group(3)!),
              );
            } else {
              // DD/MM/YYYY format
              var year = int.parse(match.group(3)!);
              if (year < 100) year += 2000;
              return DateTime(
                year,
                int.parse(match.group(2)!),
                int.parse(match.group(1)!),
              );
            }
          } catch (e) {
            continue;
          }
        }
      }
    }

    return null;
  }

  /// Extract merchant name (usually first 1-2 lines)
  String? _extractMerchantName(List<String> lines) {
    if (lines.isEmpty) return null;

    // Skip common header words
    final skipWords = ['receipt', 'invoice', 'bill', 'tax', 'date', 'time'];
    
    for (final line in lines.take(3)) {
      final lower = line.toLowerCase();
      if (!skipWords.any((w) => lower.contains(w)) && 
          line.length > 2 && 
          !RegExp(r'^\d').hasMatch(line)) {
        return line;
      }
    }

    return lines.first;
  }

  /// Extract individual line items
  List<OcrLineItem> _extractLineItems(List<String> lines) {
    final items = <OcrLineItem>[];
    final itemPattern = RegExp(r'^(.+?)\s+([\d,]+\.?\d*)\s*$');

    for (final line in lines) {
      final match = itemPattern.firstMatch(line);
      if (match != null) {
        final description = match.group(1)?.trim() ?? '';
        final priceStr = match.group(2)?.replaceAll(',', '');
        final price = double.tryParse(priceStr ?? '');

        // Skip if it looks like a total line
        if (description.toLowerCase().contains('total') ||
            description.toLowerCase().contains('subtotal')) {
          continue;
        }

        if (description.isNotEmpty && price != null && price > 0) {
          items.add(OcrLineItem(
            description: description,
            price: price,
          ));
        }
      }
    }

    return items;
  }

  /// Dispose recognizer
  void dispose() {
    _textRecognizer.close();
  }
}
