import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../models/extracted_resource.dart';
import '../parsers/timestamp_parser.dart';

abstract class IYoutubeClient {
  Future<ExtractedResource> extractResource(String url);
  Future<ExtractedResource> extractPlaylist(String playlistUrl);
  Future<ExtractedResource> extractVideo(String videoUrl);
  void close();
}

class YoutubeExtractorService implements IYoutubeClient {
  final yt.YoutubeExplode _yt;
  final http.Client _httpClient;

  YoutubeExtractorService({
    yt.YoutubeExplode? client,
    http.Client? httpClient,
  })  : _yt = client ?? yt.YoutubeExplode(),
        _httpClient = httpClient ?? http.Client();

  @override
  void close() {
    _yt.close();
    _httpClient.close();
  }

  /// Helper to extract clean YouTube playlist ID from any URL or raw ID string.
  static String? parsePlaylistId(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return null;

    final uri = Uri.tryParse(clean);
    if (uri != null && uri.queryParameters.containsKey('list')) {
      final listParam = uri.queryParameters['list'];
      if (listParam != null && listParam.isNotEmpty) {
        return listParam;
      }
    }

    final listRegex = RegExp(r'[?&]list=([a-zA-Z0-9_-]+)');
    final match = listRegex.firstMatch(clean);
    if (match != null) {
      return match.group(1);
    }

    if (RegExp(r'^(PL|UU|FL|RD|OLAK5uy_)[a-zA-Z0-9_-]+$').hasMatch(clean)) {
      return clean;
    }

    return null;
  }

  /// Helper to extract clean video ID from any YouTube URL or raw ID string.
  static String? parseVideoId(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return null;

    final uri = Uri.tryParse(clean);
    if (uri != null && uri.queryParameters.containsKey('v')) {
      final vParam = uri.queryParameters['v'];
      if (vParam != null && vParam.isNotEmpty) {
        return vParam;
      }
    }

    try {
      return yt.VideoId(clean).value;
    } catch (_) {
      final match = RegExp(r'(?:v=|\/|be\/)([a-zA-Z0-9_-]{11})').firstMatch(clean);
      return match?.group(1);
    }
  }

  /// Extracts structured curriculum data from either a playlist or video URL.
  @override
  Future<ExtractedResource> extractResource(String url) async {
    final cleanUrl = url.trim();

    if (parsePlaylistId(cleanUrl) != null) {
      return await extractPlaylist(cleanUrl);
    } else {
      return await extractVideo(cleanUrl);
    }
  }

  @override
  Future<ExtractedResource> extractPlaylist(String playlistUrl) async {
    final playlistId = parsePlaylistId(playlistUrl) ?? playlistUrl.trim();

    String playlistTitle = 'Curriculum Playlist';
    String playlistAuthor = 'YouTube Creator';
    String playlistDescription = 'Ingested YouTube playlist';

    try {
      final plMeta = await _yt.playlists.get(playlistId);
      if (plMeta.title.isNotEmpty) playlistTitle = plMeta.title;
      if (plMeta.author.isNotEmpty) playlistAuthor = plMeta.author;
      if (plMeta.description.isNotEmpty) playlistDescription = plMeta.description;
    } catch (e) {
      debugPrint('Notice: standard playlist metadata fetch fell back: $e');
    }

    // Extract all videos via Innertube browse API (handles modern lockupViewModel & legacy)
    var rawItems = await _fetchPlaylistVideosViaInnertube(playlistId);

    // If Innertube returned empty, fallback to youtube_explode_dart streaming
    if (rawItems.isEmpty) {
      try {
        int index = 0;
        await for (final video in _yt.playlists.getVideos(playlistId)) {
          final durationSec = video.duration?.inSeconds ?? 600;
          rawItems.add(RawResourceItem(
            title: video.title,
            sourceUrl: video.url,
            durationSeconds: durationSec,
            index: index,
            description: video.description,
            thumbnailUrl: video.thumbnails.highResUrl,
          ));
          index++;
        }
      } catch (e) {
        debugPrint('Fallback getVideos error: $e');
      }
    }

    if (rawItems.isEmpty) {
      throw Exception(
        'Could not extract videos from playlist "$playlistId". Please verify the URL and ensure the playlist is public.',
      );
    }

    return ExtractedResource(
      title: playlistTitle,
      description: playlistDescription,
      author: playlistAuthor,
      sourceUrl: playlistUrl,
      resourceType: ExtractedResourceType.playlist,
      items: rawItems,
    );
  }

  /// Direct Innertube Browse API extractor.
  /// Seamlessly parses both modern YouTube web lockupViewModel and legacy playlistVideoRenderer.
  Future<List<RawResourceItem>> _fetchPlaylistVideosViaInnertube(String playlistId) async {
    final cleanId = playlistId.startsWith('VL') ? playlistId : 'VL$playlistId';
    final items = <RawResourceItem>[];
    String? continuationToken;
    int index = 0;

    try {
      do {
        final http.Response resp;
        if (continuationToken == null) {
          resp = await _httpClient.post(
            Uri.parse('https://www.youtube.com/youtubei/v1/browse?prettyPrint=false'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'X-YouTube-Client-Name': '1',
              'X-YouTube-Client-Version': '2.20231201.00.00',
            },
            body: jsonEncode({
              'context': {
                'client': {
                  'clientName': 'WEB',
                  'clientVersion': '2.20231201.00.00',
                  'hl': 'en',
                  'gl': 'US',
                },
              },
              'browseId': cleanId,
            }),
          );
        } else {
          resp = await _httpClient.post(
            Uri.parse('https://www.youtube.com/youtubei/v1/browse?prettyPrint=false'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'X-YouTube-Client-Name': '1',
              'X-YouTube-Client-Version': '2.20231201.00.00',
            },
            body: jsonEncode({
              'context': {
                'client': {
                  'clientName': 'WEB',
                  'clientVersion': '2.20231201.00.00',
                  'hl': 'en',
                  'gl': 'US',
                },
              },
              'continuation': continuationToken,
            }),
          );
        }

        if (resp.statusCode != 200) {
          debugPrint('Innertube browse request exited with status: ${resp.statusCode}');
          break;
        }

        final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
        continuationToken = null;

        void parseNodes(dynamic node) {
          if (node is Map<String, dynamic>) {
            // Modern YouTube Lockup View Model
            if (node.containsKey('lockupViewModel')) {
              final lvm = node['lockupViewModel'] as Map<String, dynamic>;
              final videoId = lvm['contentId']?.toString() ?? '';
              final title = lvm['metadata']?['lockupMetadataViewModel']?['title']?['content']?.toString() ?? '';

              int seconds = 0;
              String thumbnailUrl = '';

              final sources = lvm['contentImage']?['thumbnailViewModel']?['image']?['sources'] as List?;
              if (sources != null && sources.isNotEmpty) {
                thumbnailUrl = sources.last['url']?.toString() ?? '';
              }

              final overlays = lvm['contentImage']?['thumbnailViewModel']?['overlays'] as List?;
              if (overlays != null) {
                for (final o in overlays) {
                  final badge = o['thumbnailBottomOverlayViewModel']?['badges']?[0]?['thumbnailBadgeViewModel'];
                  if (badge != null && badge['text'] != null) {
                    final durationStr = badge['text'].toString();
                    final parts = durationStr.split(':').map(int.tryParse).toList();
                    if (parts.length == 2 && parts[0] != null && parts[1] != null) {
                      seconds = (parts[0]! * 60) + parts[1]!;
                    } else if (parts.length == 3 && parts[0] != null && parts[1] != null && parts[2] != null) {
                      seconds = (parts[0]! * 3600) + (parts[1]! * 60) + parts[2]!;
                    }
                  }
                }
              }

              if (videoId.isNotEmpty && title.isNotEmpty) {
                items.add(RawResourceItem(
                  title: title,
                  sourceUrl: 'https://www.youtube.com/watch?v=$videoId',
                  durationSeconds: seconds > 0 ? seconds : 600,
                  index: index++,
                  thumbnailUrl: thumbnailUrl,
                ));
              }
            } else if (node.containsKey('playlistVideoRenderer')) {
              // Legacy Playlist Video Renderer
              final pvr = node['playlistVideoRenderer'] as Map<String, dynamic>;
              final videoId = pvr['videoId']?.toString() ?? '';
              final titleRuns = pvr['title']?['runs'] as List?;
              final title = titleRuns?.map((r) => r['text']).join('') ?? pvr['title']?['simpleText']?.toString() ?? '';
              final lengthSec = int.tryParse(pvr['lengthSeconds']?.toString() ?? '') ?? 600;

              if (videoId.isNotEmpty && title.isNotEmpty) {
                items.add(RawResourceItem(
                  title: title,
                  sourceUrl: 'https://www.youtube.com/watch?v=$videoId',
                  durationSeconds: lengthSec,
                  index: index++,
                  thumbnailUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
                ));
              }
            } else if (node.containsKey('continuationItemRenderer')) {
              final cir = node['continuationItemRenderer'] as Map<String, dynamic>;
              final token = cir['continuationEndpoint']?['continuationCommand']?['token']?.toString();
              if (token != null && token.isNotEmpty) {
                continuationToken = token;
              }
            }

            for (final val in node.values) {
              parseNodes(val);
            }
          } else if (node is List) {
            for (final item in node) {
              parseNodes(item);
            }
          }
        }

        parseNodes(jsonMap);
      } while (continuationToken != null && continuationToken!.isNotEmpty && items.length < 500);
    } catch (e) {
      debugPrint('Error parsing Innertube playlist: $e');
    }

    return items;
  }

  @override
  Future<ExtractedResource> extractVideo(String videoUrl) async {
    try {
      final video = await _yt.videos.get(videoUrl);
      final totalDurationSec = video.duration?.inSeconds ?? 900;
      final description = video.description;

      // Condition 3: Parse chapter timestamps if present in the video description
      final timestampSegments = TimestampParser.parseDescription(
        description,
        totalVideoDurationSeconds: totalDurationSec,
      );

      final rawItems = <RawResourceItem>[];

      if (timestampSegments.isNotEmpty) {
        // Deep-linked timestamp beats
        for (int i = 0; i < timestampSegments.length; i++) {
          final seg = timestampSegments[i];
          final deepLink = '${video.url}&t=${seg.startSeconds}s';
          rawItems.add(RawResourceItem(
            title: seg.title,
            sourceUrl: deepLink,
            timestampSeconds: seg.startSeconds,
            durationSeconds: seg.durationSeconds,
            index: i,
            thumbnailUrl: video.thumbnails.highResUrl,
          ));
        }

        return ExtractedResource(
          title: video.title,
          description: video.description,
          author: video.author,
          sourceUrl: videoUrl,
          resourceType: ExtractedResourceType.singleVideoWithTimestamps,
          items: rawItems,
        );
      } else {
        // Single video monolithic beat
        rawItems.add(RawResourceItem(
          title: video.title,
          sourceUrl: video.url,
          timestampSeconds: 0,
          durationSeconds: totalDurationSec,
          index: 0,
          description: video.description,
          thumbnailUrl: video.thumbnails.highResUrl,
        ));

        return ExtractedResource(
          title: video.title,
          description: video.description,
          author: video.author,
          sourceUrl: videoUrl,
          resourceType: ExtractedResourceType.singleVideo,
          items: rawItems,
        );
      }
    } catch (e) {
      debugPrint('Error extracting YouTube video: $e');
      rethrow;
    }
  }
}
