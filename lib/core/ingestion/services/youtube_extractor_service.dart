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

  /// Extracts the URL substring if surrounded by text (e.g. from mobile share sheets).
  static String extractCleanUrl(String input) {
    final clean = input.trim();
    final match = RegExp(r'https?:\/\/[^\s]+').firstMatch(clean);
    if (match != null) {
      return match.group(0)!;
    }
    return clean;
  }

  /// Helper to extract clean YouTube playlist ID from any URL or raw ID string.
  static String? parsePlaylistId(String input) {
    final clean = extractCleanUrl(input).trim();
    if (clean.isEmpty) return null;

    final uri = Uri.tryParse(clean);
    if (uri != null && uri.queryParameters.containsKey('list')) {
      final listParam = uri.queryParameters['list']?.trim();
      if (listParam != null && listParam.isNotEmpty) {
        // Exclude radio mixes, liked videos, watch later which are non-extractable
        if (!listParam.startsWith('RD') &&
            !listParam.startsWith('LL') &&
            !listParam.startsWith('WL') &&
            !listParam.startsWith('UL')) {
          return listParam;
        }
      }
    }

    final listRegex = RegExp(r'[?&]list=([a-zA-Z0-9_-]+)');
    final match = listRegex.firstMatch(clean);
    if (match != null) {
      final listId = match.group(1);
      if (listId != null &&
          !listId.startsWith('RD') &&
          !listId.startsWith('LL') &&
          !listId.startsWith('WL') &&
          !listId.startsWith('UL')) {
        return listId;
      }
    }

    if (RegExp(r'^(PL|UU|FL|OLAK5uy_)[a-zA-Z0-9_-]+$').hasMatch(clean)) {
      return clean;
    }

    return null;
  }

  /// Helper to extract clean video ID from any YouTube URL or raw ID string.
  static String? parseVideoId(String input) {
    final clean = extractCleanUrl(input).trim();
    if (clean.isEmpty) return null;

    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(clean)) {
      return clean;
    }

    final uri = Uri.tryParse(clean);
    if (uri != null) {
      if (uri.queryParameters.containsKey('v')) {
        final vParam = uri.queryParameters['v']?.trim();
        if (vParam != null && vParam.isNotEmpty) {
          final idMatch = RegExp(r'^[a-zA-Z0-9_-]{11}').firstMatch(vParam);
          return idMatch != null ? idMatch.group(0) : vParam;
        }
      }

      final segments = uri.pathSegments;
      if (uri.host.contains('youtu.be') && segments.isNotEmpty) {
        final idMatch = RegExp(r'^[a-zA-Z0-9_-]{11}').firstMatch(segments.first);
        return idMatch != null ? idMatch.group(0) : segments.first;
      }

      for (final prefix in ['shorts', 'embed', 'live', 'v']) {
        final idx = segments.indexWhere((s) => s == prefix);
        if (idx != -1 && idx + 1 < segments.length) {
          final idMatch = RegExp(r'^[a-zA-Z0-9_-]{11}').firstMatch(segments[idx + 1]);
          return idMatch != null ? idMatch.group(0) : segments[idx + 1];
        }
      }
    }

    final match = RegExp(r'(?:v=|\/|be\/|shorts\/|embed\/|live\/)([a-zA-Z0-9_-]{11})').firstMatch(clean);
    return match?.group(1);
  }

  /// Extracts structured curriculum data from either a playlist or video URL.
  @override
  Future<ExtractedResource> extractResource(String url) async {
    final cleanUrl = extractCleanUrl(url).trim();
    if (cleanUrl.isEmpty) {
      throw Exception('Please provide a valid YouTube URL.');
    }

    final playlistId = parsePlaylistId(cleanUrl);
    final videoId = parseVideoId(cleanUrl);

    if (playlistId != null) {
      return await extractPlaylist(cleanUrl);
    }

    if (videoId != null) {
      return await extractVideo(cleanUrl);
    }

    throw Exception('Could not recognize a valid YouTube video or playlist URL: "$url"');
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

    // 1. Primary: Direct Innertube browse API with pagination (handles 100, 200, 500+ videos)
    var rawItems = await _fetchPlaylistVideosViaInnertube(playlistId);

    // 2. Fallback: Direct HTML scrape of playlist page
    if (rawItems.isEmpty) {
      rawItems = await _fetchPlaylistVideosViaHtmlScrape(playlistId);
    }

    // 3. Fallback: youtube_explode_dart streaming
    if (rawItems.isEmpty) {
      final explodeItems = <RawResourceItem>[];
      try {
        int index = 0;
        await for (final video in _yt.playlists.getVideos(playlistId)) {
          final durationSec = video.duration?.inSeconds ?? 600;
          explodeItems.add(RawResourceItem(
            title: video.title,
            sourceUrl: video.url,
            durationSeconds: durationSec,
            index: index++,
            description: video.description,
            thumbnailUrl: video.thumbnails.highResUrl,
          ));
        }
      } catch (e) {
        debugPrint('Notice: youtube_explode_dart getVideos fell back: $e');
      }

      if (explodeItems.length > rawItems.length) {
        rawItems = explodeItems;
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
      sourceUrl: 'https://www.youtube.com/playlist?list=$playlistId',
      resourceType: ExtractedResourceType.playlist,
      items: rawItems,
    );
  }

  /// Direct Innertube Browse API extractor.
  /// Seamlessly parses both modern YouTube web lockupViewModel and legacy playlistVideoRenderer.
  Future<List<RawResourceItem>> _fetchPlaylistVideosViaInnertube(String playlistId) async {
    final cleanId = playlistId.startsWith('VL') ? playlistId : 'VL$playlistId';
    final items = <RawResourceItem>[];
    final seenVideoIds = <String>{};
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
          final uri = Uri.parse('https://www.youtube.com/youtubei/v1/browse?continuation=$continuationToken');
          resp = await _httpClient.post(
            uri,
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

        void parseNodes(dynamic node, String path) {
          if (node is Map<String, dynamic>) {
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

              if (videoId.isNotEmpty && title.isNotEmpty && !seenVideoIds.contains(videoId)) {
                seenVideoIds.add(videoId);
                items.add(RawResourceItem(
                  title: title,
                  sourceUrl: 'https://www.youtube.com/watch?v=$videoId',
                  durationSeconds: seconds > 0 ? seconds : 600,
                  index: index++,
                  thumbnailUrl: thumbnailUrl,
                ));
              }
            } else if (node.containsKey('playlistVideoRenderer')) {
              final pvr = node['playlistVideoRenderer'] as Map<String, dynamic>;
              final videoId = pvr['videoId']?.toString() ?? '';
              final titleRuns = pvr['title']?['runs'] as List?;
              final title = titleRuns?.map((r) => r['text']).join('') ?? pvr['title']?['simpleText']?.toString() ?? '';
              final lengthSec = int.tryParse(pvr['lengthSeconds']?.toString() ?? '') ?? 600;

              if (videoId.isNotEmpty && title.isNotEmpty && !seenVideoIds.contains(videoId)) {
                seenVideoIds.add(videoId);
                items.add(RawResourceItem(
                  title: title,
                  sourceUrl: 'https://www.youtube.com/watch?v=$videoId',
                  durationSeconds: lengthSec,
                  index: index++,
                  thumbnailUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
                ));
              }
            } else if (node.containsKey('gridVideoRenderer') || node.containsKey('videoRenderer')) {
              final vr = (node['gridVideoRenderer'] ?? node['videoRenderer']) as Map<String, dynamic>;
              final videoId = vr['videoId']?.toString() ?? '';
              final titleRuns = vr['title']?['runs'] as List?;
              final title = titleRuns?.map((r) => r['text']).join('') ?? vr['title']?['simpleText']?.toString() ?? '';
              final lengthSec = int.tryParse(vr['lengthSeconds']?.toString() ?? '') ?? 600;

              if (videoId.isNotEmpty && title.isNotEmpty && !seenVideoIds.contains(videoId)) {
                seenVideoIds.add(videoId);
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
              final token = cir['continuationEndpoint']?['continuationCommand']?['token']?.toString() ??
                  cir['button']?['buttonRenderer']?['command']?['continuationCommand']?['token']?.toString();
              // Only pick continuation tokens that belong to the video section/list, not the page/sectionList
              if (token != null &&
                  token.isNotEmpty &&
                  (path.contains('itemSectionRenderer') ||
                      path.contains('playlistVideoListRenderer') ||
                      path.contains('onResponseReceivedActions') ||
                      path.contains('appendContinuationItemsAction'))) {
                continuationToken = token;
              }
            }

            for (final entry in node.entries) {
              parseNodes(entry.value, '$path.${entry.key}');
            }
          } else if (node is List) {
            for (int i = 0; i < node.length; i++) {
              parseNodes(node[i], '$path[$i]');
            }
          }
        }

        parseNodes(jsonMap, 'root');
      } while (continuationToken != null && continuationToken!.isNotEmpty && items.length < 1000);
    } catch (e) {
      debugPrint('Error parsing Innertube playlist: $e');
    }

    return items;
  }

  /// Scrapes playlist HTML page to extract ytInitialData when browse API is unreachable.
  Future<List<RawResourceItem>> _fetchPlaylistVideosViaHtmlScrape(String playlistId) async {
    final items = <RawResourceItem>[];
    final seenVideoIds = <String>{};
    try {
      final resp = await _httpClient.get(
        Uri.parse('https://www.youtube.com/playlist?list=$playlistId'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      );

      if (resp.statusCode != 200) return items;

      final html = resp.body;
      final match = RegExp(r'var ytInitialData = (\{.+?\});<\/script>', dotAll: true).firstMatch(html) ??
          RegExp(r'ytInitialData = (\{.+?\});', dotAll: true).firstMatch(html);
      if (match == null) return items;

      final jsonMap = jsonDecode(match.group(1)!) as Map<String, dynamic>;
      int index = 0;

      void parseNodes(dynamic node) {
        if (node is Map<String, dynamic>) {
          if (node.containsKey('playlistVideoRenderer')) {
            final pvr = node['playlistVideoRenderer'] as Map<String, dynamic>;
            final videoId = pvr['videoId']?.toString() ?? '';
            final titleRuns = pvr['title']?['runs'] as List?;
            final title = titleRuns?.map((r) => r['text']).join('') ?? pvr['title']?['simpleText']?.toString() ?? '';
            final lengthSec = int.tryParse(pvr['lengthSeconds']?.toString() ?? '') ?? 600;

            if (videoId.isNotEmpty && title.isNotEmpty && !seenVideoIds.contains(videoId)) {
              seenVideoIds.add(videoId);
              items.add(RawResourceItem(
                title: title,
                sourceUrl: 'https://www.youtube.com/watch?v=$videoId',
                durationSeconds: lengthSec,
                index: index++,
                thumbnailUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
              ));
            }
          } else if (node.containsKey('lockupViewModel')) {
            final lvm = node['lockupViewModel'] as Map<String, dynamic>;
            final videoId = lvm['contentId']?.toString() ?? '';
            final title = lvm['metadata']?['lockupMetadataViewModel']?['title']?['content']?.toString() ?? '';
            if (videoId.isNotEmpty && title.isNotEmpty && !seenVideoIds.contains(videoId)) {
              seenVideoIds.add(videoId);
              items.add(RawResourceItem(
                title: title,
                sourceUrl: 'https://www.youtube.com/watch?v=$videoId',
                durationSeconds: 600,
                index: index++,
                thumbnailUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
              ));
            }
          }

          for (final val in node.values) {
            parseNodes(val);
          }
        } else if (node is List) {
          for (final val in node) {
            parseNodes(val);
          }
        }
      }

      parseNodes(jsonMap);
    } catch (e) {
      debugPrint('HTML scrape playlist fallback error: $e');
    }
    return items;
  }

  /// Extracts single video using Innertube Player API (direct JSON, no scraping, resilient on mobile).
  Future<ExtractedResource?> _extractVideoViaInnertubePlayer(String videoId) async {
    try {
      final resp = await _httpClient.post(
        Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false'),
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
          'videoId': videoId,
        }),
      );

      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final vd = data['videoDetails'] as Map<String, dynamic>?;
      if (vd == null) return null;

      final title = vd['title']?.toString() ?? '';
      if (title.isEmpty) return null;

      final author = vd['author']?.toString() ?? 'YouTube Creator';
      final description = vd['shortDescription']?.toString() ?? '';
      final lengthSec = int.tryParse(vd['lengthSeconds']?.toString() ?? '') ?? 900;
      final videoUrl = 'https://www.youtube.com/watch?v=$videoId';

      String thumbnailUrl = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
      final thumbs = vd['thumbnail']?['thumbnails'] as List?;
      if (thumbs != null && thumbs.isNotEmpty) {
        thumbnailUrl = thumbs.last['url']?.toString() ?? thumbnailUrl;
      }

      final timestampSegments = TimestampParser.parseDescription(
        description,
        totalVideoDurationSeconds: lengthSec,
      );

      final rawItems = <RawResourceItem>[];

      if (timestampSegments.isNotEmpty) {
        for (int i = 0; i < timestampSegments.length; i++) {
          final seg = timestampSegments[i];
          final deepLink = '$videoUrl&t=${seg.startSeconds}s';
          rawItems.add(RawResourceItem(
            title: seg.title,
            sourceUrl: deepLink,
            timestampSeconds: seg.startSeconds,
            durationSeconds: seg.durationSeconds,
            index: i,
            thumbnailUrl: thumbnailUrl,
          ));
        }

        return ExtractedResource(
          title: title,
          description: description,
          author: author,
          sourceUrl: videoUrl,
          resourceType: ExtractedResourceType.singleVideoWithTimestamps,
          items: rawItems,
        );
      } else {
        rawItems.add(RawResourceItem(
          title: title,
          sourceUrl: videoUrl,
          timestampSeconds: 0,
          durationSeconds: lengthSec,
          index: 0,
          description: description,
          thumbnailUrl: thumbnailUrl,
        ));

        return ExtractedResource(
          title: title,
          description: description,
          author: author,
          sourceUrl: videoUrl,
          resourceType: ExtractedResourceType.singleVideo,
          items: rawItems,
        );
      }
    } catch (e) {
      debugPrint('Innertube player video extraction failed: $e');
      return null;
    }
  }

  /// Direct HTML metadata extraction fallback for single video.
  Future<ExtractedResource?> _extractVideoViaHtml(String videoId) async {
    try {
      final resp = await _httpClient.get(
        Uri.parse('https://www.youtube.com/watch?v=$videoId'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      );
      if (resp.statusCode != 200) return null;

      final html = resp.body;
      final titleMatch = RegExp(r'<meta property="og:title" content="([^"]+)"').firstMatch(html) ??
          RegExp(r'<title>([^<]+)<\/title>').firstMatch(html);
      final title = titleMatch?.group(1)?.replaceAll(' - YouTube', '').trim() ?? 'YouTube Video';

      final descMatch = RegExp(r'<meta property="og:description" content="([^"]+)"').firstMatch(html);
      final description = descMatch?.group(1) ?? '';

      final videoUrl = 'https://www.youtube.com/watch?v=$videoId';
      final thumbnailUrl = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

      return ExtractedResource(
        title: title,
        description: description,
        author: 'YouTube Creator',
        sourceUrl: videoUrl,
        resourceType: ExtractedResourceType.singleVideo,
        items: [
          RawResourceItem(
            title: title,
            sourceUrl: videoUrl,
            timestampSeconds: 0,
            durationSeconds: 900,
            index: 0,
            description: description,
            thumbnailUrl: thumbnailUrl,
          ),
        ],
      );
    } catch (e) {
      debugPrint('HTML video extraction fallback failed: $e');
      return null;
    }
  }

  @override
  Future<ExtractedResource> extractVideo(String videoUrl) async {
    final videoId = parseVideoId(videoUrl);
    if (videoId == null) {
      throw Exception('Invalid YouTube video link: "$videoUrl"');
    }

    // 1. Primary: Direct Innertube Player API (fast, robust on Android/iOS, never fails on ?si=)
    final innertubeResource = await _extractVideoViaInnertubePlayer(videoId);
    if (innertubeResource != null && innertubeResource.items.isNotEmpty) {
      return innertubeResource;
    }

    // 2. Secondary: youtube_explode_dart using clean video ID
    try {
      final video = await _yt.videos.get(videoId);
      final totalDurationSec = video.duration?.inSeconds ?? 900;
      final description = video.description;

      final timestampSegments = TimestampParser.parseDescription(
        description,
        totalVideoDurationSeconds: totalDurationSec,
      );

      final rawItems = <RawResourceItem>[];

      if (timestampSegments.isNotEmpty) {
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
          sourceUrl: video.url,
          resourceType: ExtractedResourceType.singleVideoWithTimestamps,
          items: rawItems,
        );
      } else {
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
          sourceUrl: video.url,
          resourceType: ExtractedResourceType.singleVideo,
          items: rawItems,
        );
      }
    } catch (e) {
      debugPrint('Secondary video extraction via youtube_explode failed: $e');
    }

    // 3. Fallback: Direct HTML metadata extraction
    try {
      final htmlResource = await _extractVideoViaHtml(videoId);
      if (htmlResource != null) {
        return htmlResource;
      }
    } catch (e) {
      debugPrint('HTML video extraction fallback failed: $e');
    }

    throw Exception(
      'Could not extract video details for "$videoId". Please verify the URL and ensure the video is public.',
    );
  }
}
