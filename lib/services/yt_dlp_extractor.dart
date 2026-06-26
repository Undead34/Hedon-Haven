import 'dart:async';
import 'dart:io' show Platform;

import 'package:extractor/extractor.dart';

import '/utils/global_vars.dart';

class YtDlpExtractorService {
  static final YtDlpExtractorService _instance =
      YtDlpExtractorService._internal();
  static YtDlpExtractorService get instance => _instance;
  YtDlpExtractorService._internal();

  final YoutubeDLFlutter _youtubeDL = YoutubeDLFlutter.instance;
  bool _initialized = false;
  bool _initializing = false;
  Completer<bool>? _initCompleter;

  bool get isReady => _initialized;
  bool get isInitializing => _initializing;
  bool get isSupported => _supported;

  bool get _supported => Platform.isAndroid;

  Future<bool> initialize() async {
    if (!_supported) return false;
    if (_initialized) return true;
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initializing = true;
    _initCompleter = Completer<bool>();
    try {
      logger.i("Initializing yt-dlp engine");
      final result = await _youtubeDL.initialize(
        enableFFmpeg: true,
        enableAria2c: false,
      );
      if (result.success) {
        _initialized = true;
        logger.i("yt-dlp engine initialized successfully");
      } else {
        logger.e("Failed to initialize yt-dlp: ${result.errorMessage}");
      }
      _initCompleter!.complete(result.success);
      return result.success;
    } catch (e, st) {
      logger.e("Failed to initialize yt-dlp engine: $e\n$st");
      _initCompleter!.complete(false);
      return false;
    } finally {
      _initializing = false;
      _initCompleter = null;
    }
  }

  Future<Map<int, Uri>?> getStreamUrls(String pageUrl) async {
    if (!_supported) return null;
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return null;
    }
    try {
      logger.i("Extracting streams via yt-dlp for: $pageUrl");
      final info = await _youtubeDL.getVideoInfo(pageUrl);
      if (info.formats == null || info.formats!.isEmpty) {
        logger.w("yt-dlp returned no formats for: $pageUrl");
        return null;
      }

      Map<int, Uri> streamMap = {};
      for (final format in info.formats!) {
        if (format == null) continue;
        if (format.url == null || format.url!.isEmpty) continue;
        if (format.height == null) continue;

        final existing = streamMap[format.height!];
        if (existing == null) {
          streamMap[format.height!] = Uri.parse(format.url!);
        }
      }

      if (streamMap.isEmpty) {
        logger.w("yt-dlp: no formats with height found for: $pageUrl");
      }
      logger.i(
          "yt-dlp extracted ${streamMap.length} quality levels for: $pageUrl");
      return streamMap;
    } catch (e, st) {
      logger.e("yt-dlp extraction failed for $pageUrl: $e\n$st");
      return null;
    }
  }

  Future<String?> getYtDlpVersion() async {
    if (!_supported || !_initialized) return null;
    try {
      final version = await _youtubeDL.getVersion();
      return version.youtubeDlVersion;
    } catch (e, st) {
      logger.e("yt-dlp getVersion failed: $e\n$st");
      return null;
    }
  }

  Future<bool> updateYtDlp(
      {UpdateChannel channel = UpdateChannel.stable}) async {
    if (!_supported || !_initialized) return false;
    try {
      logger.i("Updating yt-dlp...");
      await _youtubeDL.updateYoutubeDL(channel: channel);
      logger.i("yt-dlp updated successfully");
      return true;
    } catch (e, st) {
      logger.e("yt-dlp update failed: $e\n$st");
      return false;
    }
  }

  void dispose() {
    _initialized = false;
  }
}

