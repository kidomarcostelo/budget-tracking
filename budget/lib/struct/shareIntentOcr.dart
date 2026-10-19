import 'dart:async';
import 'package:flutter/services.dart';

/// Structured result from native ML Kit OCR text recognition.
class OcrResult {
  final String text;
  final List<OcrBlock> blocks;

  const OcrResult({
    required this.text,
    required this.blocks,
  });

  factory OcrResult.fromMap(Map<dynamic, dynamic> map) {
    final text = map['text'] as String? ?? '';
    final rawBlocks = map['blocks'] as List<dynamic>? ?? [];
    final blocks = rawBlocks
        .map((b) => OcrBlock.fromMap(b as Map<dynamic, dynamic>))
        .toList();
    return OcrResult(text: text, blocks: blocks);
  }
}

/// A block of text containing multiple lines.
class OcrBlock {
  final String text;
  final List<OcrLine> lines;

  const OcrBlock({
    required this.text,
    required this.lines,
  });

  factory OcrBlock.fromMap(Map<dynamic, dynamic> map) {
    final text = map['text'] as String? ?? '';
    final rawLines = map['lines'] as List<dynamic>? ?? [];
    final lines = rawLines
        .map((l) => OcrLine.fromMap(l as Map<dynamic, dynamic>))
        .toList();
    return OcrBlock(text: text, lines: lines);
  }
}

/// A line of text containing elements.
class OcrLine {
  final String text;
  final List<String> elements;

  const OcrLine({
    required this.text,
    required this.elements,
  });

  factory OcrLine.fromMap(Map<dynamic, dynamic> map) {
    final text = map['text'] as String? ?? '';
    final rawElements = map['elements'] as List<dynamic>? ?? [];
    final elements = rawElements.map((e) => e.toString()).toList();
    return OcrLine(text: text, elements: elements);
  }
}

/// Payload received from an Android share intent (image or text).
class SharedPayload {
  final String type; // 'image' or 'text'
  final String? filePath;
  final String? uri;
  final String? text;

  const SharedPayload({
    required this.type,
    this.filePath,
    this.uri,
    this.text,
  });

  factory SharedPayload.fromMap(Map<dynamic, dynamic> map) {
    return SharedPayload(
      type: map['type'] as String? ?? 'unknown',
      filePath: map['filePath'] as String?,
      uri: map['uri'] as String?,
      text: map['text'] as String?,
    );
  }

  bool get isImage => type == 'image' && filePath != null;
  bool get isText => type == 'text' && text != null;
}

/// Dart interface for native Android share sheet reception and ML Kit OCR.
class ShareIntentOcrService {
  static const MethodChannel _channel =
      MethodChannel('com.budget.tracker_app/ocr');

  static final StreamController<SharedPayload> _sharedDataStreamController =
      StreamController<SharedPayload>.broadcast();

  static Stream<SharedPayload> get sharedDataStream =>
      _sharedDataStreamController.stream;

  static bool _initialized = false;

  /// Initialize listener for shared payloads received while app is running.
  static void initialize({Function(SharedPayload payload)? onPayload}) {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedDataReceived') {
        if (call.arguments is Map) {
          final payload =
              SharedPayload.fromMap(call.arguments as Map<dynamic, dynamic>);
          _sharedDataStreamController.add(payload);
          onPayload?.call(payload);
        }
      }
    });
  }

  /// Check if the app was launched via a share intent (cold start).
  static Future<SharedPayload?> getInitialSharedData() async {
    try {
      final data = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getInitialSharedData');
      if (data != null) {
        return SharedPayload.fromMap(data);
      }
    } on PlatformException catch (_) {
      // Platform channel not available or failed
    }
    return null;
  }

  /// Run on-device ML Kit OCR on the local image file at [filePath].
  static Future<OcrResult?> recognizeText(String filePath) async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'recognizeText',
        {'filePath': filePath},
      );
      if (res != null) {
        return OcrResult.fromMap(res);
      }
    } on PlatformException catch (_) {
      // OCR processing failed
    }
    return null;
  }

  /// Delete the temporary cached shared file once OCR or ingestion is complete.
  static Future<bool> deleteTempFile(String filePath) async {
    try {
      final deleted = await _channel.invokeMethod<bool>(
        'deleteTempFile',
        {'filePath': filePath},
      );
      return deleted ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
