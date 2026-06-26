import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '/services/yt_dlp_extractor.dart';
import '/ui/utils/toast_notification.dart';
import '/ui/widgets/options_dialog.dart';
import '/ui/widgets/options_switch.dart';
import '/utils/global_vars.dart';

class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key});

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  String? _ytDlpVersion;
  bool _ytDlpUpdating = false;
  bool _hasCookies = false;

  @override
  void initState() {
    super.initState();
    _loadYtDlpVersion();
  }

  Future<void> _loadYtDlpVersion() async {
    final ytDlp = YtDlpExtractorService.instance;
    if (ytDlp.isSupported && !ytDlp.isReady) {
      await ytDlp.initialize();
    }
    final version = await ytDlp.getYtDlpVersion();
    final dir = await getApplicationDocumentsDirectory();
    final cookieFile = File('${dir.path}/yt_dlp_cookies.txt');
    final hasCookies = await cookieFile.exists();
    if (mounted) {
      setState(() {
        _ytDlpVersion = version;
        _hasCookies = hasCookies;
      });
    }
  }

  Future<void> _updateYtDlp() async {
    setState(() => _ytDlpUpdating = true);
    final success = await YtDlpExtractorService.instance.updateYtDlp();
    await _loadYtDlpVersion();
    if (mounted) {
      setState(() => _ytDlpUpdating = false);
      if (success) {
        showToast("yt-dlp updated successfully", context);
      } else {
        showToast("Failed to update yt-dlp", context);
      }
    }
  }

  Future<void> _importCookies() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (result != null && result.files.single.path != null) {
      final source = File(result.files.single.path!);
      final dir = await getApplicationDocumentsDirectory();
      final dest = File('${dir.path}/yt_dlp_cookies.txt');
      await source.copy(dest.path);
      setState(() {
        _hasCookies = true;
      });
      if (mounted) showToast("Cookies imported successfully", context);
    }
  }

  Future<void> _clearCookies() async {
    final dir = await getApplicationDocumentsDirectory();
    final dest = File('${dir.path}/yt_dlp_cookies.txt');
    if (await dest.exists()) {
      await dest.delete();
    }
    setState(() {
      _hasCookies = false;
    });
    if (mounted) showToast("Cookies cleared", context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.primary),
          title: const Text("Media"),
        ),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: <Widget>[
                    FutureBuilder<int?>(
                        future: sharedStorage
                            .getInt("media_preferred_video_quality"),
                        builder: (context, snapshot) {
                          return OptionsTile(
                              title: "Default resolution",
                              subtitle: snapshot.data == null
                                  ? ""
                                  : "${snapshot.data}p",
                              options: const [
                                "144p",
                                "240p",
                                "360p",
                                "480p",
                                "720p",
                                "1080p",
                                "1440p",
                                "2160p"
                              ],
                              selectedOption: snapshot.data == null
                                  ? ""
                                  : "${snapshot.data}p",
                              onSelected: (value) async {
                                await sharedStorage.setInt(
                                    "media_preferred_video_quality",
                                    int.parse(
                                        value.substring(0, value.length - 1)));
                                setState(() {});
                              });
                        }),
                    FutureBuilder<int?>(
                        future: sharedStorage.getInt("media_seek_duration"),
                        builder: (context, snapshot) {
                          return OptionsTile(
                              title: "Double-tap seek duration",
                              subtitle: snapshot.data == null
                                  ? ""
                                  : "${snapshot.data} seconds",
                              options: const [
                                "5 seconds",
                                "10 seconds",
                                "15 seconds",
                                "20 seconds",
                                "25 seconds",
                                "30 seconds",
                                "60 seconds",
                                "120 seconds"
                              ],
                              selectedOption: snapshot.data == null
                                  ? ""
                                  : "${snapshot.data} seconds",
                              onSelected: (value) async {
                                await sharedStorage.setInt(
                                    "media_seek_duration",
                                    int.parse(
                                        value.substring(0, value.length - 8)));
                                setState(() {});
                              });
                        }),
                    FutureBuilder<bool?>(
                        future:
                            sharedStorage.getBool("media_start_in_fullscreen"),
                        builder: (context, snapshot) {
                          return OptionsSwitch(
                              title: "Start in fullscreen",
                              subTitle: "Always start videos in fullscreen",
                              switchState: snapshot.data ?? false,
                              onToggled: (value) => sharedStorage.setBool(
                                  "media_start_in_fullscreen", value));
                        }),
                    FutureBuilder<bool?>(
                        future: sharedStorage.getBool("media_auto_play"),
                        builder: (context, snapshot) {
                          return OptionsSwitch(
                              title: "Autoplay",
                              subTitle:
                                  "Start playback of video as soon as it loads",
                              switchState: snapshot.data ?? false,
                              onToggled: (value) async => await sharedStorage
                                  .setBool("media_auto_play", value));
                        }),
                    FutureBuilder<bool?>(
                        future: sharedStorage
                            .getBool("media_show_progress_thumbnails"),
                        builder: (context, snapshot) {
                          return OptionsSwitch(
                              title: "Show video progress thumbnails",
                              subTitle:
                                  "Show little progress thumbnails above the timeline",
                              switchState: snapshot.data ?? true,
                              onToggled: (value) async =>
                                  await sharedStorage.setBool(
                                      "media_show_progress_thumbnails", value));
                        }),
                    if (YtDlpExtractorService.instance.isSupported) ...[
                      const SizedBox(height: 16),
                      _buildYtDlpSection(context),
                    ],
                  ],
                ))));
  }

  Widget _buildYtDlpSection(BuildContext context) {
    final ytDlp = YtDlpExtractorService.instance;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Divider(),
      Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text("yt-dlp Engine",
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold))),
      Row(children: [
        Icon(
          ytDlp.isReady
              ? Icons.check_circle
              : ytDlp.isInitializing
                  ? Icons.sync
                  : Icons.error_outline,
          color: ytDlp.isReady
              ? Colors.green
              : ytDlp.isInitializing
                  ? Colors.orange
                  : Colors.grey,
          size: 20,
        ),
        SizedBox(width: 8),
        Text(ytDlp.isReady
            ? "Ready"
            : ytDlp.isInitializing
                ? "Initializing..."
                : "Not initialized"),
        Spacer(),
        if (_ytDlpVersion != null)
          Text("v$_ytDlpVersion",
              style: Theme.of(context).textTheme.bodySmall),
      ]),
      if (_ytDlpUpdating)
        Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(children: [
              SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 8),
              Text("Updating yt-dlp...",
                  style: Theme.of(context).textTheme.bodySmall)
            ])),
      if (ytDlp.isReady && !_ytDlpUpdating) ...[
        Row(
          children: [
            TextButton.icon(
                onPressed: _updateYtDlp,
                icon: const Icon(Icons.update, size: 18),
                label: const Text("Update yt-dlp")),
            const Spacer(),
            if (_hasCookies) ...[
              const Text("Cookies loaded",
                  style: TextStyle(color: Colors.green, fontSize: 12)),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.red),
                onPressed: _clearCookies,
                tooltip: "Clear cookies",
              ),
            ]
          ],
        ),
        TextButton.icon(
            onPressed: _importCookies,
            icon: const Icon(Icons.cookie, size: 18),
            label: Text(
                _hasCookies ? "Replace cookies.txt" : "Import cookies.txt")),
      ],
      SizedBox(height: 4),
      Text(
          "When enabled per plugin, yt-dlp is used to extract video stream URLs "
          "instead of manual HTML parsing. Better for live streams and sites "
          "with complex extraction.",
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);
  }
}
