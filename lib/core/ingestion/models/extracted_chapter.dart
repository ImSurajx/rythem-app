import 'extracted_beat.dart';

class ExtractedChapter {
  final String title;
  final int sortOrder;
  final List<ExtractedBeat> beats;

  const ExtractedChapter({
    required this.title,
    required this.sortOrder,
    required this.beats,
  });

  double get totalEffort =>
      beats.fold(0.0, (sum, beat) => sum + beat.effortWeight);

  int get beatCount => beats.length;

  ExtractedChapter copyWith({
    String? title,
    int? sortOrder,
    List<ExtractedBeat>? beats,
  }) {
    return ExtractedChapter(
      title: title ?? this.title,
      sortOrder: sortOrder ?? this.sortOrder,
      beats: beats ?? this.beats,
    );
  }

  @override
  String toString() =>
      'ExtractedChapter(title: $title, order: $sortOrder, beats: ${beats.length})';
}
