import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../models/extracted_resource.dart';
import '../parsers/timestamp_parser.dart';

abstract class IYoutubeClient {
  Future<ExtractedResource> extractPlaylist(String playlistUrl);
  Future<ExtractedResource> extractVideo(String videoUrl);
  void close();
}

class YoutubeExtractorService implements IYoutubeClient {
  final yt.YoutubeExplode _yt;

  YoutubeExtractorService({yt.YoutubeExplode? client})
      : _yt = client ?? yt.YoutubeExplode();

  @override
  void close() {
    _yt.close();
  }

  /// Extracts structured curriculum data from either a playlist or video URL.
  Future<ExtractedResource> extractResource(String url) async {
    final cleanUrl = url.trim();

    if (_isPlaylistUrl(cleanUrl)) {
      return await extractPlaylist(cleanUrl);
    } else {
      return await extractVideo(cleanUrl);
    }
  }

  bool _isPlaylistUrl(String url) {
    return url.contains('list=') || url.contains('/playlist');
  }

  @override
  Future<ExtractedResource> extractPlaylist(String playlistUrl) async {
    try {
      final playlist = await _yt.playlists.get(playlistUrl);
      final rawItems = <RawResourceItem>[];

      int index = 0;
      await for (final video in _yt.playlists.getVideos(playlist.id)) {
        final durationSec = video.duration?.inSeconds ?? 600; // 10 min default fallback
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

      return ExtractedResource(
        title: playlist.title,
        description: playlist.description,
        author: playlist.author,
        sourceUrl: playlistUrl,
        resourceType: ExtractedResourceType.playlist,
        items: rawItems,
      );
    } catch (e) {
      debugPrint('Error extracting YouTube playlist: $e');
      rethrow;
    }
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
