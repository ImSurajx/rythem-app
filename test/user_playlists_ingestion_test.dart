import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/ingestion/services/youtube_extractor_service.dart';
import 'package:rythem_app/core/ingestion/parsers/chapter_clusterer.dart';

void main() {
  group('User Playlists Full Verification (Beyond 100 Beats)', () {
    late YoutubeExtractorService extractor;

    setUp(() {
      extractor = YoutubeExtractorService();
    });

    tearDown(() {
      extractor.close();
    });

    test('Playlist 2 (Precalculus 115 videos): All 115 beats extracted and clustered', () async {
      final res = await extractor.extractResource(
        'https://www.youtube.com/watch?v=9OOrhA2iKak&list=PLDesaqWTN6ESsmwELdrzhcGiRhk5DjwLP',
      );

      print('Precalculus extracted: ${res.items.length} items');
      expect(res.items.length, 115);

      final chapters = ChapterClusterer.cluster(res.items, roadmapTitle: res.title);
      print('Precalculus chapters count: ${chapters.length}');
      expect(chapters.length, greaterThan(1));

      final allBeats = chapters.expand((c) => c.beats).toList();
      print('Precalculus total beats across chapters: ${allBeats.length}');
      expect(allBeats.length, 115);

      // Verify every single video is present in order
      for (int i = 0; i < res.items.length; i++) {
        expect(allBeats[i].title, res.items[i].title);
        expect(allBeats[i].sourceUrl, res.items[i].sourceUrl);
      }
    });

    test('Playlist 1 (DSA with Python 200 videos): All 200 beats extracted and clustered', () async {
      final res = await extractor.extractResource(
        'https://www.youtube.com/watch?v=OtYEY2htIjM&list=PLhR2IpV1b2FwWwviBHRrR118YAaSlyhTU',
      );

      print('DSA Python extracted: ${res.items.length} items');
      expect(res.items.length, 200);

      final chapters = ChapterClusterer.cluster(res.items, roadmapTitle: res.title);
      print('DSA Python chapters count: ${chapters.length}');
      expect(chapters.length, greaterThan(1));

      final allBeats = chapters.expand((c) => c.beats).toList();
      print('DSA Python total beats across chapters: ${allBeats.length}');
      expect(allBeats.length, 200);

      // Verify every single video is present in order
      for (int i = 0; i < res.items.length; i++) {
        expect(allBeats[i].title, res.items[i].title);
        expect(allBeats[i].sourceUrl, res.items[i].sourceUrl);
      }
    });
  });
}
