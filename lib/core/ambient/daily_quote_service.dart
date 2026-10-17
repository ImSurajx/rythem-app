import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Representation of a daily inspirational quote.
class DailyQuote {
  final String quote;
  final String author;
  final String date;

  const DailyQuote({
    required this.quote,
    required this.author,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'quote': quote,
        'author': author,
        'date': date,
      };

  factory DailyQuote.fromJson(Map<String, dynamic> json) {
    return DailyQuote(
      quote: json['quote'] as String? ?? 'Mastery is felt, not measured.',
      author: json['author'] as String? ?? 'Rythem',
      date: json['date'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyQuote &&
          runtimeType == other.runtimeType &&
          quote == other.quote &&
          author == other.author &&
          date == other.date;

  @override
  int get hashCode => quote.hashCode ^ author.hashCode ^ date.hashCode;
}

/// Service that retrieves daily quotes and greetings using free, public APIs
/// that require zero signup and zero API keys (ZenQuotes Today & DummyJSON Quotes),
/// with seamless local persistence and an offline diurnal curated quote reserve.
class DailyQuoteService {
  DailyQuoteService._();
  static final DailyQuoteService instance = DailyQuoteService._();

  DailyQuote? _cachedQuote;
  DailyQuote? get cachedQuote =>
      _cachedQuote ??= _getOfflineQuoteForDate(DateTime.now());

  /// Visible for unit tests.
  void setMockQuote(DailyQuote? quote) {
    _cachedQuote = quote;
  }

  /// Formats date as YYYY-MM-DD.
  static String _todayKey([DateTime? dt]) {
    final now = dt ?? DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Retrieves the daily quote for today, querying free public APIs (ZenQuotes/DummyJSON)
  /// without requiring signup or API keys.
  Future<DailyQuote> getDailyQuote({
    bool forceRefresh = false,
    http.Client? client,
  }) async {
    final today = _todayKey();

    // 1. In-memory cache hit
    if (!forceRefresh && _cachedQuote != null && _cachedQuote!.date == today) {
      return _cachedQuote!;
    }

    final httpClient = client ?? http.Client();
    DailyQuote? fetchedQuote;

    // 3. Primary Free API: ZenQuotes Today (no signup, no API key needed)
    try {
      final uri = Uri.parse('https://zenquotes.io/api/today');
      final res = await httpClient
          .get(uri, headers: {'User-Agent': 'RythemApp/1.1'})
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List && data.isNotEmpty) {
          final item = data.first;
          if (item is Map<String, dynamic>) {
            final q = item['q'] as String?;
            final a = item['a'] as String?;
            if (q != null && q.trim().isNotEmpty) {
              fetchedQuote = DailyQuote(
                quote: q.trim(),
                author: (a != null && a.trim().isNotEmpty) ? a.trim() : 'Unknown',
                date: today,
              );
            }
          }
        }
      }
    } catch (_) {}

    // 4. Fallback Free API: DummyJSON Quotes (no signup, no API key needed)
    if (fetchedQuote == null) {
      try {
        final uri = Uri.parse('https://dummyjson.com/quotes/random');
        final res = await httpClient
            .get(uri, headers: {'User-Agent': 'RythemApp/1.1'})
            .timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            final q = data['quote'] as String?;
            final a = data['author'] as String?;
            if (q != null && q.trim().isNotEmpty) {
              fetchedQuote = DailyQuote(
                quote: q.trim(),
                author: (a != null && a.trim().isNotEmpty) ? a.trim() : 'Unknown',
                date: today,
              );
            }
          }
        }
      } catch (_) {}
    }

    if (client == null) {
      httpClient.close();
    }

    // 5. Offline Fallback: Curated Daily Rhythm & Mastery Reserve
    fetchedQuote ??= _getOfflineQuoteForDate(DateTime.now());

    _cachedQuote = fetchedQuote;
    return fetchedQuote;
  }

  /// Curated offline mastery and focus quotes cycled deterministically by day of year.
  static DailyQuote _getOfflineQuoteForDate(DateTime dt) {
    final dayOfYear = dt.difference(DateTime(dt.year, 1, 1)).inDays;
    final index = dayOfYear % _offlineQuotes.length;
    final pair = _offlineQuotes[index];
    return DailyQuote(
      quote: pair[0],
      author: pair[1],
      date: _todayKey(dt),
    );
  }

  static const List<List<String>> _offlineQuotes = [
    [
      "Mastery is felt, not measured. Focus on the rhythm of the next beat.",
      "Rythem Philosophy"
    ],
    [
      "You've got to get up every morning with determination if you're going to go to bed with satisfaction.",
      "George Lorimer"
    ],
    [
      "Small disciplines repeated with consistency every day lead to great achievements gained slowly over time.",
      "John C. Maxwell"
    ],
    [
      "It is not daily increase, but daily decrease. Hack away at the unessential.",
      "Bruce Lee"
    ],
    [
      "We are what we repeatedly do. Excellence, then, is not an act, but a habit.",
      "Will Durant"
    ],
    [
      "Action is the foundational key to all success.",
      "Pablo Picasso"
    ],
    [
      "Deep focus is like a superpower in our increasingly distracted rhythm.",
      "Cal Newport"
    ],
    [
      "Continuous effort—not strength or intelligence—is the key to unlocking our potential.",
      "Winston Churchill"
    ],
    [
      "Do not wait to strike till the iron is hot; but make it hot by striking.",
      "William Butler Yeats"
    ],
    [
      "Rhythm isn't about rushing; it's about staying in flow with clarity.",
      "Rythem Philosophy"
    ],
  ];
}
